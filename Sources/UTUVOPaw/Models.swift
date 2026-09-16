import Foundation

/// A leftover a cat should knock off the desk.
struct Leftover: Identifiable, Hashable {
    enum Category: String, CaseIterable, Comparable {
        case application = "Application"
        case support = "Application Support"
        case caches = "Caches"
        case preferences = "Preferences"
        case containers = "Containers"
        case savedState = "Saved State"
        case logs = "Logs"
        case launch = "Launch Items"
        case web = "Web Storage"
        case other = "Other"

        static func < (a: Category, b: Category) -> Bool {
            allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
        }
    }

    let id: URL
    let url: URL
    let category: Category
    let isDirectory: Bool
    /// True when the item lives under /Library and will need admin rights to trash.
    let needsAdmin: Bool
    var size: Int64?
    var selected: Bool

    init(url: URL, category: Category, isDirectory: Bool, needsAdmin: Bool, size: Int64? = nil) {
        self.id = url
        self.url = url
        self.category = category
        self.isDirectory = isDirectory
        self.needsAdmin = needsAdmin
        self.size = size
        self.selected = !needsAdmin
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let p = url.path
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }
}

/// What we know about the dropped app.
struct AppInfo: Hashable {
    let url: URL
    let name: String
    let bundleID: String?
    let executableName: String?
    let version: String?

    /// Names that identify this app in filenames, most specific first.
    var identifiers: [String] {
        var out: [String] = []
        if let bundleID { out.append(bundleID) }
        out.append(name)
        if let executableName, executableName.caseInsensitiveCompare(name) != .orderedSame {
            out.append(executableName)
        }
        return out
    }
}

struct BopResult {
    var trashed: [Leftover] = []
    /// Where each trashed item ended up (same order as `trashed`).
    var trashedTo: [URL] = []
    var failed: [(Leftover, Error)] = []
    var bytesFreed: Int64 { trashed.reduce(0) { $0 + ($1.size ?? 0) } }
}

enum ByteFormat {
    static func string(_ bytes: Int64?) -> String {
        guard let bytes else { return "…" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f.string(fromByteCount: bytes)
    }
}
