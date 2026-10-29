import AppKit
import Observation
import UserNotifications

/// Reaches you while Shoji is in the background. The Dock badge counts the threads that want you
/// (`ThreadStore.wantingYou`), and each thread that starts wanting you posts a macOS notification
/// (Threads › Notify Me When Shoji Is Away). Clicking one opens its thread; it goes once the thread is seen.
@MainActor @Observable
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private static let storageKey = "notifyWhenAway"

    private(set) var isOn: Bool
    /// Turned off in System Settings: the menu offers the way there instead of the toggle.
    private(set) var isDenied = false

    @ObservationIgnored private let store: ThreadStore
    /// The threads that wanted you last time, so only newcomers are announced.
    @ObservationIgnored private var known: Set<UUID>

    init(store: ThreadStore) {
        self.store = store
        isOn = UserDefaults.standard.object(forKey: Self.storageKey) as? Bool ?? true
        known = Set(store.wantingYou.map(\.id))
        super.init()
        UNUserNotificationCenter.current().delegate = self
        if isOn { requestPermission() }
        // Created in `ShojiApp.init`, before NSApp exists; the Dock badge has to wait for launch.
        NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.observe() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }
    }

    func setOn(_ isOn: Bool) {
        self.isOn = isOn
        UserDefaults.standard.set(isOn, forKey: Self.storageKey)
        if isOn { requestPermission() }
    }

    private func observe() {
        let waiting = withObservationTracking {
            store.wantingYou
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
        update(waiting)
    }

    private func update(_ waiting: [ShojiThread]) {
        NSApp.dockTile.badgeLabel = waiting.isEmpty ? nil : "\(waiting.count)"
        let ids = Set(waiting.map(\.id))
        let seen = known.subtracting(ids)
        if !seen.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: seen.map(\.uuidString))
        }
        if isOn, !NSApp.isActive {
            for thread in waiting where !known.contains(thread.id) { post(thread) }
        }
        known = ids
    }

    /// One per thread: a newer one replaces it.
    private func post(_ thread: ShojiThread) {
        let activity = store.activity(for: thread.id)
        let content = UNMutableNotificationContent()
        content.title = store.name(of: thread)
        content.body = activity.status == .needsYou ? activity.detail ?? activity.status.label : activity.status.label
        // A finished turn stays as quiet as its tick.
        content.sound = activity.status == .needsYou ? .default : nil
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: thread.id.uuidString, content: content, trigger: nil))
    }

    private func requestPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            refreshPermission()
        }
    }

    private func refreshPermission() {
        Task {
            isDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = UUID(uuidString: response.notification.request.identifier) else { return }
        await open(id)
    }

    /// In front, Hachi already shows it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    private func open(_ id: UUID) {
        NSApp.activate()
        store.open(id)
    }
}
