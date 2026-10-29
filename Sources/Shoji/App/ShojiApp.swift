import OSLog
import SwiftUI

@main
struct ShojiApp: App {
    @State private var store: ThreadStore
    @State private var sessions: TerminalSessions
    @State private var notifier: Notifier?
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let hookServer: HookServer?

    /// Unit tests and previews host the app binary; they must not spawn shells or take the socket.
    private static let isHeadless = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    private static let hachiOnFinishKey = "hachiOnFinish"

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
            store.hachiOnFinish = UserDefaults.standard.object(forKey: Self.hachiOnFinishKey) as? Bool ?? true
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { store.saveNow() }
            }
        }
        let socketPath = Self.isHeadless ? "" : Self.supportFolder.appending(path: "hook.sock").path(percentEncoded: false)
        hookServer = Self.isHeadless ? nil : Self.startHookServer(at: socketPath, feeding: store)
        _store = State(initialValue: store)
        _notifier = State(initialValue: Self.isHeadless ? nil : Notifier(store: store))
        let context = LaunchContext.current(socketPath: socketPath, supportFolder: Self.isHeadless ? FileManager.default.temporaryDirectory : Self.supportFolder)
        let sessions = TerminalSessions(store: store, context: context)
        _sessions = State(initialValue: sessions)
        if !Self.isHeadless {
            AppDelegate.store = store
            AppDelegate.sessions = sessions
        }
    }

    var body: some Scene {
        Window("Shoji", id: "main") {
            MainView()
                .environment(store)
                .environment(sessions)
                .onChange(of: store.threads.map(\.id), initial: true) { sessions.sync() }
                .onChange(of: store.hachiOnFinish) { _, isOn in
                    if !Self.isHeadless { UserDefaults.standard.set(isOn, forKey: Self.hachiOnFinishKey) }
                }
        }
        .defaultSize(width: 1360, height: 860)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands { ShojiCommands(store: store, sessions: sessions, notifier: notifier) }

        // macOS 26 lets the user hide it in System Settings › Menu Bar, so there's no setting of our own.
        MenuBarExtra(isInserted: .constant(!Self.isHeadless)) {
            HachiMenuBarMenu()
                .environment(store)
        } label: {
            HachiMenuBarLabel(count: store.wantingYou.count)
        }
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

/// Asks before ⌘Q stops work in progress, naming it; quits at once otherwise.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var store: ThreadStore?
    static var sessions: TerminalSessions?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store = Self.store else { return .terminateNow }
        var busy = store.busyThreads.map { thread in
            let activity = store.activity(for: thread.id)
            return "\(store.name(of: thread)) — \(activity.status == .running ? thread.command ?? activity.status.label : activity.status.label)"
        }
        if let running = Self.sessions?.popup?.running { busy.append("Quick terminal — \(running)") }
        guard !busy.isEmpty else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Quit Shoji?"
        alert.informativeText = "This stops:\n" + busy.map { "• \($0)" }.joined(separator: "\n")
        alert.addButton(withTitle: "Quit").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
