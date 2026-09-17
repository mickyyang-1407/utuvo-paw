import AppKit
import SwiftUI
import XCTest
@testable import UTUVOPaw

/// Renders the real UI in a real window owned by this process and grabs it with
/// CGWindowListCreateImage (no screen-recording permission needed for your own windows).
/// Run: PAW_SNAP=/some/dir swift test --filter Snapshots
@MainActor
final class Snapshots: XCTestCase {
    func testRender() async throws {
        guard let out = ProcessInfo.processInfo.environment["PAW_SNAP"] else { return }
        try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
        Paw.registerFonts()
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let model = PawModel()
        let win = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 920, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        win.title = "UTUVO Paw"
        win.contentView = NSHostingView(rootView: ContentView().environmentObject(model))
        win.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)

        func snap(_ name: String) async throws {
            try await Task.sleep(for: .milliseconds(900))
            let id = CGWindowID(win.windowNumber)
            guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else { XCTFail("no image \(name)"); return }
            let rep = NSBitmapImageRep(cgImage: cg)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out).appendingPathComponent(name + ".png"))
        }

        try await snap("idle")
        let fake = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Fake Cat Toy.app")
        model.load(fake)
        try await Task.sleep(for: .milliseconds(1500))
        try await snap("desk")
        // done screen with a plausible result
        var r = BopResult()
        r.trashed = Array(model.items.prefix(12)); r.trashedTo = r.trashed.map { $0.url }
        model.result = r; model.phase = .done
        try await snap("done")
        win.orderOut(nil)   // closing tears down the hosting view mid-teardown and crashes xctest
    }
}
