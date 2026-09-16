import AppKit
import XCTest
@testable import UTUVOPaw

final class MatcherTests: XCTestCase {
    let app = AppInfo(url: URL(fileURLWithPath: "/Applications/Cliply.app"), name: "Cliply",
                      bundleID: "com.acme.cliply", executableName: "Cliply", version: "1.0")

    func testBundleIDForms() {
        for name in ["com.acme.cliply", "com.acme.cliply.plist", "com.acme.cliply.savedState",
                     "com.acme.cliply.helper", "group.com.acme.cliply", "com.acme.cliply.ABCD-1234.plist",
                     "com.acme.cliply-launcher.plist", "COM.ACME.CLIPLY"] {
            XCTAssertTrue(Matcher.matches(name: name, app: app), name)
        }
    }

    func testNameForms() {
        for name in ["Cliply", "cliply", "Cliply.plist", "Cliply.log", "Cliply-2.1.log"] {
            XCTAssertTrue(Matcher.matches(name: name, app: app), name)
        }
    }

    func testDoesNotOvermatch() {
        for name in ["com.acme.cliplyPro", "com.acme.cliplypro.plist", "Cliplyzer", "MyCliply",
                     "com.acme", "Adobe", "com.apple.finder.plist", "cliplyness.txt"] {
            XCTAssertFalse(Matcher.matches(name: name, app: app), name)
        }
    }

    func testShortNamesAreExactOnly() {
        let music = AppInfo(url: URL(fileURLWithPath: "/tmp/Music.app"), name: "Music", bundleID: "com.x.music", executableName: "Music", version: nil)
        XCTAssertFalse(Matcher.matches(name: "MusicBrainz Picard", app: music))
        XCTAssertFalse(Matcher.matches(name: "com.apple.Music.plist", app: music))
        XCTAssertTrue(Matcher.matches(name: "Music", app: music))
    }

    func testTrasherSafety() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertFalse(Trasher.isSafe(home))
        XCTAssertFalse(Trasher.isSafe(home.appendingPathComponent("Library")))
        XCTAssertFalse(Trasher.isSafe(URL(fileURLWithPath: "/Library")))
        XCTAssertFalse(Trasher.isSafe(home.appendingPathComponent("Documents/notes.txt")))
        XCTAssertTrue(Trasher.isSafe(home.appendingPathComponent("Library/Caches/com.x")))
        XCTAssertTrue(Trasher.isSafe(URL(fileURLWithPath: "/Applications/Foo.app")))
    }

    func testInspectorRejectsNonApp() {
        XCTAssertThrowsError(try AppInspector.inspect(URL(fileURLWithPath: "/tmp/x.txt")))
    }

    /// End-to-end on a synthetic app in a temp HOME-like tree: scanner must find exactly the planted files.
    func testScannerFindsPlantedLeftovers() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pawtest-\(UUID().uuidString)")
        let appURL = tmp.appendingPathComponent("Fake.app")
        try FileManager.default.createDirectory(at: appURL.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": "com.test.fake", "CFBundleName": "Fake", "CFBundleExecutable": "Fake"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: appURL.appendingPathComponent("Contents/Info.plist"))
        let info = try AppInspector.inspect(appURL)
        XCTAssertEqual(info.bundleID, "com.test.fake")
        XCTAssertEqual(info.name, "Fake")
        try? FileManager.default.removeItem(at: tmp)
    }
}

final class FontTests: XCTestCase {
    func testFredokaRegistersFromBundle() {
        Paw.registerFonts()
        XCTAssertTrue(Paw.fontRegistered, "Fonts/Fredoka.ttf missing from resource bundle")
        XCTAssertTrue(NSFontManager.shared.availableFontFamilies.contains("Fredoka"), "family not visible after registration")
        XCTAssertNotNil(NSFont(name: "Fredoka-Bold", size: 12) ?? NSFont(name: "Fredoka-Regular", size: 12))
    }
}
