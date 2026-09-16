import AppKit
import SwiftUI

@main
struct PawApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = PawModel()

    var body: some Scene {
        Window("UTUVO Paw", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear { delegate.model = model }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 620, height: 560)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose App…") { model.chooseApp() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .help) {
                Button("UTUVO Paw on GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/mickyyang-1407/utuvo-paw")!)
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: PawModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Dropping an app on the Dock icon or opening with "Open With…".
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "app" }) else { return }
        DispatchQueue.main.async { self.model?.load(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
