import AppKit
import SwiftUI

@MainActor
final class PawModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case results
        case done
    }

    @Published var phase: Phase = .idle
    @Published var app: AppInfo?
    @Published var appIcon: NSImage?
    @Published var items: [Leftover] = []
    @Published var result: BopResult?
    @Published var errorText: String?
    @Published var isDropTargeted = false

    private let scanner = LeftoverScanner()

    var selectedItems: [Leftover] { items.filter(\.selected) }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + ($1.size ?? 0) } }
    var totalBytes: Int64 { items.reduce(0) { $0 + ($1.size ?? 0) } }

    func load(_ url: URL) {
        errorText = nil
        do {
            let info = try AppInspector.inspect(url)
            app = info
            appIcon = NSWorkspace.shared.icon(forFile: url.path)
            phase = .scanning
            items = []
            Task.detached(priority: .userInitiated) { [scanner] in
                let found = scanner.scan(app: info)
                await MainActor.run { self.items = found; self.phase = .results }
                for item in found {
                    let url = item.url
                    let size = scanner.measure(url)
                    await MainActor.run {
                        if let idx = self.items.firstIndex(where: { $0.url == url }) { self.items[idx].size = size }
                    }
                }
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func toggle(_ item: Leftover) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].selected.toggle()
    }

    func selectAll(_ on: Bool) {
        for i in items.indices where !items[i].needsAdmin { items[i].selected = on }
    }

    /// Trash one thing (after the shuriken lands). `done` runs on the main actor when it is gone.
    func bop(url: URL, done: @escaping () -> Void) {
        guard let item = items.first(where: { $0.url == url }) else { return }
        Task.detached(priority: .userInitiated) {
            let r = Trasher.bop([item])
            try? await Task.sleep(for: .milliseconds(450)) // let the shards fly
            await MainActor.run {
                var acc = self.result ?? BopResult()
                acc.trashed += r.trashed; acc.trashedTo += r.trashedTo; acc.failed += r.failed
                self.result = acc
                if r.failed.isEmpty { self.items.removeAll { $0.url == url } }
                done()
                if self.items.allSatisfy(\.needsAdmin) && !self.items.isEmpty || self.items.isEmpty {
                    self.phase = .done
                }
            }
        }
    }

    func reset() {
        phase = .idle
        app = nil
        appIcon = nil
        items = []
        result = nil
        errorText = nil
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Pick an app for the cat"
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }
}
