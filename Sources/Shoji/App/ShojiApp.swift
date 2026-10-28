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

    init() {
        let store = ThreadStore(threads: Self.isHeadless ? [] : Self.spikeThreads)
        store.layout.openThreadIds = store.threads.map(\.id)
        let socketPath = HookServer.defaultPath
        hookServer = Self.isHeadless ? nil : Self.startHookServer(at: socketPath, feeding: store)
        _store = State(initialValue: store)
        _sessions = State(initialValue: TerminalSessions(store: store, context: .current(socketPath: socketPath)))
    }

    var body: some Scene {
        Window("Shoji", id: "main") {
            MainView()
                .environment(store)
                .environment(sessions)
                .task { sessions.startAll() }
        }
        .defaultSize(width: 1360, height: 860)
        .windowToolbarStyle(.unified)
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

    // Until M2 brings the new-thread sheet and threads.json.
    private static let spikeThreads = [
        ShojiThread(group: .agent, kind: .claude, title: "shoji", folder: "~/lab/shoji", command: ["claude"]),
        ShojiThread(group: .task, kind: .command, title: "shell", folder: "~/lab/shoji", command: []),
    ]
}
