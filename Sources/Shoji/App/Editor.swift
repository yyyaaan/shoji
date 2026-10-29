import AppKit

/// Editors a thread's folder opens in, in menu order.
enum Editor: CaseIterable, Identifiable {
    case vsCode, zed

    /// Looked up once; an editor installed later shows up after a relaunch.
    static let installed = allCases.filter { $0.appURL != nil }

    var id: Self { self }

    var name: String {
        switch self {
        case .vsCode: "VS Code"
        case .zed: "Zed"
        }
    }

    private var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: self == .zed ? "dev.zed.Zed" : "com.microsoft.VSCode")
    }

    func open(_ folder: String) {
        guard let appURL else { return }
        let url = URL(filePath: (folder as NSString).expandingTildeInPath, directoryHint: .isDirectory)
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
