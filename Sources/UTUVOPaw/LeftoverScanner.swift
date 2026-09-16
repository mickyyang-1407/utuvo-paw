import Foundation

/// Finds the files an app leaves behind. Pure matching lives in `Matcher` so it can be tested
/// without touching the disk.
enum Matcher {
    /// Decides whether a file or folder name belongs to the app.
    ///
    /// Rules (case-insensitive):
    /// - bundle id: name == id, or id followed by `.`, `-`, `_`, ` `, or name == "group." + id …
    ///   i.e. the id must appear as a whole dotted token, not as a substring of a longer id.
    /// - app / executable name: exact match, or name + ".plist" / ".savedState" / " Support"-style
    ///   suffixes. Never a plain substring, so "Music" does not eat "MusicBrainz".
    static func matches(name: String, app: AppInfo) -> Bool {
        let n = name.lowercased()
        if let id = app.bundleID?.lowercased(), !id.isEmpty {
            if tokenMatch(n, id) { return true }
        }
        for plain in [app.name, app.executableName].compactMap({ $0?.lowercased() }) where !plain.isEmpty {
            if n == plain { return true }
            if n.hasPrefix(plain + ".") || n.hasPrefix(plain + "-") || n.hasPrefix(plain + "_") {
                // "app.plist", "app.savedState", "app-1.2.log"
                return true
            }
        }
        return false
    }

    /// `id` must appear bounded by start/end or by one of . - _ space, and it must not be
    /// followed by more dotted reverse-DNS segments that make it a *different* id
    /// (e.g. com.foo.bar must not match com.foo.barbaz but may match com.foo.bar.helper).
    static func tokenMatch(_ name: String, _ id: String) -> Bool {
        var search = name.startIndex
        while let r = name.range(of: id, range: search..<name.endIndex) {
            let beforeOK = r.lowerBound == name.startIndex || ".-_ ".contains(name[name.index(before: r.lowerBound)])
            let afterOK = r.upperBound == name.endIndex || ".-_ ".contains(name[r.upperBound])
            if beforeOK && afterOK { return true }
            search = r.upperBound
        }
        return false
    }
}

final class LeftoverScanner {
    struct Root {
        let url: URL
        let category: Leftover.Category
        let depth: Int          // 1 = direct children only; 2 = also grandchildren (ByHost, Containers/…)
        let needsAdmin: Bool
    }

    let fm = FileManager.default
    let home = FileManager.default.homeDirectoryForCurrentUser

    var roots: [Root] {
        func u(_ p: String, _ c: Leftover.Category, depth: Int = 1) -> Root {
            Root(url: home.appendingPathComponent("Library/" + p), category: c, depth: depth, needsAdmin: false)
        }
        func s(_ p: String, _ c: Leftover.Category) -> Root {
            Root(url: URL(fileURLWithPath: "/Library/" + p), category: c, depth: 1, needsAdmin: true)
        }
        return [
            u("Application Support", .support),
            u("Caches", .caches),
            u("Preferences", .preferences),
            u("Preferences/ByHost", .preferences),
            u("Saved Application State", .savedState),
            u("Containers", .containers),
            u("Group Containers", .containers),
            u("Application Scripts", .containers),
            u("Logs", .logs),
            u("HTTPStorages", .web),
            u("WebKit", .web),
            u("Cookies", .web),
            u("LaunchAgents", .launch),
            u("Autosave Information", .other),
            s("Application Support", .support),
            s("Preferences", .preferences),
            s("Caches", .caches),
            s("LaunchAgents", .launch),
            s("LaunchDaemons", .launch),
            s("PrivilegedHelperTools", .launch),
            s("Logs", .logs),
        ]
    }

    /// Synchronous scan; call off the main thread. Sizes are filled by `measure`.
    func scan(app: AppInfo) -> [Leftover] {
        var found: [Leftover] = []
        for root in roots {
            guard let children = try? fm.contentsOfDirectory(at: root.url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for child in children {
                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if Matcher.matches(name: child.lastPathComponent, app: app) {
                    found.append(Leftover(url: child, category: root.category, isDirectory: isDir, needsAdmin: root.needsAdmin))
                } else if root.depth > 1, isDir,
                          let grand = try? fm.contentsOfDirectory(at: child, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                    for g in grand where Matcher.matches(name: g.lastPathComponent, app: app) {
                        let gDir = (try? g.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        found.append(Leftover(url: g, category: root.category, isDirectory: gDir, needsAdmin: root.needsAdmin))
                    }
                }
            }
        }
        // The app itself goes first.
        let appItem = Leftover(url: app.url, category: .application, isDirectory: true, needsAdmin: false)
        var unique: [URL: Leftover] = [:]
        for l in found { unique[l.url.standardizedFileURL] = l }
        return [appItem] + unique.values.sorted { ($0.category, $0.url.path) < ($1.category, $1.url.path) }
    }

    /// Recursive on-disk size. Cheap enough for Library folders; skipped for symlinks.
    func measure(_ url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        if let v = try? url.resourceValues(forKeys: keys) {
            if v.isSymbolicLink == true { return 0 }
            if v.isRegularFile == true { return Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0) }
        }
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let f as URL in e {
            guard let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }
}

/// Moves things to the Trash. Never deletes permanently.
enum Trasher {
    static func bop(_ items: [Leftover]) -> BopResult {
        var result = BopResult()
        let fm = FileManager.default
        for item in items {
            // Belt and braces: refuse anything that is not inside ~/Library, /Library, or an .app path.
            guard isSafe(item.url) else {
                result.failed.append((item, NSError(domain: "UTUVOPaw", code: 1, userInfo: [NSLocalizedDescriptionKey: "Refused: path outside allowed roots"])))
                continue
            }
            do {
                var dest: NSURL?
                try fm.trashItem(at: item.url, resultingItemURL: &dest)
                result.trashed.append(item)
                if let dest { result.trashedTo.append(dest as URL) }
            } catch {
                result.failed.append((item, error))
            }
        }
        return result
    }

    static func isSafe(_ url: URL) -> Bool {
        let p = url.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if p == home || p == home + "/Library" || p == "/Library" || p == "/" { return false }
        if p.hasPrefix(home + "/Library/") || p.hasPrefix("/Library/") { return true }
        return url.pathExtension.lowercased() == "app"
    }
}
