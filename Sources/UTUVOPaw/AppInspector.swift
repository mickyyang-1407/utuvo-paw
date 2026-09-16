import Foundation

enum AppInspectorError: LocalizedError {
    case notAnApp(URL)
    var errorDescription: String? {
        switch self {
        case .notAnApp(let u): return "\(u.lastPathComponent) is not an application bundle."
        }
    }
}

enum AppInspector {
    /// Reads Info.plist of an .app bundle. Never throws for a missing plist; only for a non-.app path.
    static func inspect(_ url: URL) throws -> AppInfo {
        guard url.pathExtension.lowercased() == "app" else { throw AppInspectorError.notAnApp(url) }
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = (try? Data(contentsOf: plistURL)).flatMap {
            try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil) as? [String: Any]
        } ?? [:]

        let fileName = url.deletingPathExtension().lastPathComponent
        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? fileName
        return AppInfo(
            url: url,
            name: name,
            bundleID: plist["CFBundleIdentifier"] as? String,
            executableName: plist["CFBundleExecutable"] as? String,
            version: (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String)
        )
    }
}
