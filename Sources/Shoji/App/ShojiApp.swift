import OSLog
import SwiftUI

@main
struct ShojiApp: App {
    @State private var store: ThreadStore
    @State private var sessions: TerminalSessions
    private let hookServer: HookServer?

    /// Unit tests and previews host the app binary; they must not spawn shells or take the socket.
    private static let isHeadless = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    /// Debug builds get their own folder, so a dev build never touches the installed app's threads or socket.
    private static let supportFolder: URL = {
        #if DEBUG
        let name = "Shoji-Debug"
        #else
        let name = "Shoji"
        #endif
        let folder = URL.applicationSupportDirectory.appending(path: name, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    init() {
        let store: ThreadStore
        if Self.isHeadless {
            store = ThreadStore(threads: [])
        } else {
            let fileURL = Self.supportFolder.appending(path: "threads.json")
            let saved = ThreadFile.load(from: fileURL)
            store = ThreadStore(threads: saved?.threads ?? [], layout: saved?.layout ?? PaneLayout(), fileURL: fileURL)
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { store.saveNow() }
            }
        }
        let socketPath = Self.isHeadless ? "" : Self.supportFolder.appending(path: "hook.sock").path(percentEncoded: false)
        hookServer = Self.isHeadless ? nil : Self.startHookServer(at: socketPath, feeding: store)
        _store = State(initialValue: store)
        let context = LaunchContext.current(socketPath: socketPath, supportFolder: Self.isHeadless ? FileManager.default.temporaryDirectory : Self.supportFolder)
        _sessions = State(initialValue: TerminalSessions(store: store, context: context))
    }

    var body: some Scene {
        Window("Shoji", id: "main") {
            MainView()
                .environment(store)
                .environment(sessions)
                .onChange(of: store.threads.map(\.id), initial: true) { sessions.sync() }
        }
        .defaultSize(width: 1360, height: 860)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands { ShojiCommands(store: store) }
    }

    private static func startHookServer(at path: String, feeding store: ThreadStore) -> HookServer? {
        do {
            return try HookServer(path: path) { message in
                guard let event = StatusEvent(hookMessage: message) else { return }
                Task { @MainActor in store.apply(event) }
            }
        } catch {
            Logger(subsystem: "fi.yan.shoji", category: "status").error("Hook socket unavailable at \(path, privacy: .public): \(error)")
            return nil
        }
    }
}
