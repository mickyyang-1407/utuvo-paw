import XCTest
@testable import UTUVOPaw

/// Real-disk round trip: plant leftovers under ~/Library for a synthetic bundle id,
/// scan, bop, and check they landed in the Trash. Uses only its own `com.utuvo.pawtest-xctest` id.
final class IntegrationTests: XCTestCase {
    let id = "com.utuvo.pawtest-xctest"
    let fm = FileManager.default
    var lib: URL { fm.homeDirectoryForCurrentUser.appendingPathComponent("Library") }
    var planted: [URL] { [
        lib.appendingPathComponent("Application Support/\(id)"),
        lib.appendingPathComponent("Caches/\(id)"),
        lib.appendingPathComponent("Preferences/\(id).plist"),
        lib.appendingPathComponent("Saved Application State/\(id).savedState"),
        lib.appendingPathComponent("Logs/PawXCTest"),
    ] }
    var decoy: URL { lib.appendingPathComponent("Application Support/PawXCTestNotMine") }
    var appURL: URL { fm.temporaryDirectory.appendingPathComponent("PawXCTest.app") }

    override func setUpWithError() throws {
        try fm.createDirectory(at: appURL.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": "PawXCTest", "CFBundleExecutable": "PawXCTest"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: appURL.appendingPathComponent("Contents/Info.plist"))
        for u in planted {
            if u.pathExtension == "plist" { try Data("x".utf8).write(to: u) }
            else {
                try fm.createDirectory(at: u, withIntermediateDirectories: true)
                try Data(repeating: 0, count: 100_000).write(to: u.appendingPathComponent("blob"))
            }
        }
        try fm.createDirectory(at: decoy, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for u in planted + [decoy, appURL] { try? fm.removeItem(at: u) }
    }

    func testScanThenBop() throws {
        let info = try AppInspector.inspect(appURL)
        let scanner = LeftoverScanner()
        let found = scanner.scan(app: info)
        let paths = Set(found.map { $0.url.standardizedFileURL.path })
        for u in planted { XCTAssertTrue(paths.contains(u.standardizedFileURL.path), "missing \(u.lastPathComponent)") }
        XCTAssertFalse(paths.contains(decoy.standardizedFileURL.path), "decoy must not match")
        XCTAssertEqual(found.first?.category, .application)
        XCTAssertTrue(found.allSatisfy { $0.url.path.hasPrefix(lib.path) || $0.url == appURL || $0.url.path.hasPrefix("/Library") })

        let support = found.first { $0.url.lastPathComponent == id && $0.category == .support }!
        XCTAssertGreaterThanOrEqual(scanner.measure(support.url), 100_000)

        // Bop only our planted ones (skip the temp .app: trashItem on /tmp works too, but keep it tidy).
        let targets = found.filter { planted.map(\.standardizedFileURL.path).contains($0.url.standardizedFileURL.path) }
        XCTAssertEqual(targets.count, planted.count)
        let r = Trasher.bop(targets)
        XCTAssertTrue(r.failed.isEmpty, r.failed.map { "\($0.0.url.lastPathComponent): \($0.1)" }.joined(separator: "; "))
        XCTAssertEqual(r.trashed.count, planted.count)
        for u in planted { XCTAssertFalse(fm.fileExists(atPath: u.path), "\(u.lastPathComponent) still there") }
        XCTAssertEqual(r.trashedTo.count, planted.count, "trashItem must report destinations")
        for d in r.trashedTo {
            XCTAssertTrue(d.path.contains("/.Trash/"), d.path)
            XCTAssertTrue(fm.fileExists(atPath: d.path), "not in Trash: \(d.lastPathComponent)")
            try? fm.removeItem(at: d)   // clean our own Trash entries
        }
    }
}

final class OrphanTests: XCTestCase {
    func testBundleIDParsing() {
        XCTAssertEqual(Orphans.bundleID(fromName: "com.acme.cliply.plist"), "com.acme.cliply")
        XCTAssertEqual(Orphans.bundleID(fromName: "group.com.acme.cliply"), "com.acme.cliply")
        XCTAssertEqual(Orphans.bundleID(fromName: "com.acme.cliply.savedState"), "com.acme.cliply")
        XCTAssertEqual(Orphans.bundleID(fromName: "com.acme.cliply.A46A35B6-8034-45C9-9862-60E375058B86.plist"), "com.acme.cliply")
        XCTAssertEqual(Orphans.bundleID(fromName: "com.acme.cliply.helper"), "com.acme.cliply.helper")
        XCTAssertNil(Orphans.bundleID(fromName: "Fake Cat Toy"))
        XCTAssertNil(Orphans.bundleID(fromName: "Adobe"))
        XCTAssertNil(Orphans.bundleID(fromName: "com.acme"))
        XCTAssertNil(Orphans.bundleID(fromName: "1.2.3"))
        XCTAssertTrue(Orphans.isProtected("com.apple.finder"))
    }

    /// Plant a leftover for an id no app owns → it must be found; the Finder's own prefs must not.
    func testRealOrphanScan() throws {
        let fm = FileManager.default
        let lib = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let id = "com.utuvo.orphan-xctest"
        let planted = lib.appendingPathComponent("Caches/\(id)")
        try fm.createDirectory(at: planted, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: planted) }
        let found = LeftoverScanner().scanOrphans()
        let paths = found.map { $0.url.standardizedFileURL.path }
        XCTAssertTrue(paths.contains(planted.standardizedFileURL.path), "planted orphan not found")
        XCTAssertFalse(found.contains { $0.url.lastPathComponent.lowercased().hasPrefix("com.apple.") }, "Apple files must never be orphans")
        XCTAssertFalse(found.contains { $0.category == .launch }, "launch agents must never be guessed")
        XCTAssertFalse(found.contains { $0.url.path.contains("/Group Containers/") }, "shared group containers must never be guessed")
        let installed = LeftoverScanner().installedBundleIDs()
        XCTAssertTrue(installed.contains("com.apple.finder") || installed.contains("com.apple.safari"), "installed id set is empty")
        var c2: [String: Bool] = [:]
        XCTAssertTrue(LeftoverScanner().isInstalled("com.apple.safari.web-extension", cache: &c2, installed: ["com.apple.safari"]))
        // an id LaunchServices knows (this very app's build, or any installed app) is never an orphan
        var cache: [String: Bool] = [:]
        XCTAssertTrue(LeftoverScanner().isInstalled("com.apple.finder", cache: &cache))
        XCTAssertTrue(LeftoverScanner().isInstalled("com.apple.finder.helper.deep", cache: &cache))
        XCTAssertFalse(LeftoverScanner().isInstalled(id, cache: &cache))
    }
}
