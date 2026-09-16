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
