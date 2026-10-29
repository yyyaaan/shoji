import AppKit

/// Threads › Open Folders In: where Open in Zed (or VS Code) opens a thread's folder.
enum Editor: String, CaseIterable, Identifiable {
    case zed, vsCode

    static let storageKey = "editor"
    /// Looked up once; an editor installed while Shoji runs shows up after a relaunch.
    static let installed = allCases.filter { $0.appURL != nil }

    var id: Self { self }

    var name: String {
        switch self {
        case .zed: "Zed"
        case .vsCode: "VS Code"
        }
    }

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: self == .zed ? "dev.zed.Zed" : "com.microsoft.VSCode")
    }

    /// The chosen editor, else the first one installed; nil when there's none.
    static func resolved(_ choice: String) -> Editor? {
        installed.first { $0.rawValue == choice } ?? installed.first
    }

    func open(_ folder: String) {
        guard let appURL else { return }
        let url = URL(filePath: (folder as NSString).expandingTildeInPath, directoryHint: .isDirectory)
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
