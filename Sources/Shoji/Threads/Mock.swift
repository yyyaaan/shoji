import Foundation

/// Preview data matching the design mockups.
enum Mock {
    static let threads: [ShojiThread] = [
        ShojiThread(title: "auth-refactor", folder: "~/code/gosta", group: 0, order: 0, command: "claude"),
        ShojiThread(title: "extension popup", folder: "~/code/gosta-browser-extension", group: 0, order: 1, command: "claude"),
        ShojiThread(title: "helm cleanup", folder: "~/home-lab/k3s", group: 0, order: 2, command: "codex"),
        ShojiThread(folder: "~/lab/shoji", group: 0, order: 3),
        ShojiThread(title: "api stack", folder: "~/code/gosta", group: 1, order: 0, command: "docker compose up"),
        ShojiThread(title: "web dev", folder: "~/code/gosta", group: 1, order: 1, command: "pnpm dev"),
        ShojiThread(title: "extension watch", folder: "~/code/gosta-browser-extension", group: 1, order: 2),
    ]

    @MainActor
    static func store() -> ThreadStore {
        let now = Date.now
        let store = ThreadStore(
            threads: threads,
            layout: PaneLayout(.twoColumns, [threads[1].id, threads[4].id]),
            now: now
        )
        for thread in threads {
            if let command = thread.command {
                store.apply(StatusEvent(threadId: thread.id, signal: .commandStarted(command)), at: now.addingTimeInterval(-25 * 60))
            }
        }
        store.apply(StatusEvent(threadId: threads[0].id, signal: .needsYou(message: "Allow Bash: uv run pytest…")), at: now)
        store.apply(StatusEvent(threadId: threads[1].id, signal: .working(sessionId: nil)), at: now.addingTimeInterval(-6 * 60))
        store.apply(StatusEvent(threadId: threads[2].id, signal: .finished), at: now.addingTimeInterval(-2 * 60))
        store.apply(StatusEvent(threadId: threads[3].id, signal: .directory("~/lab/shoji")), at: now)
        store.apply(StatusEvent(threadId: threads[6].id, signal: .commandStarted("pnpm build --watch")), at: now)
        store.apply(StatusEvent(threadId: threads[6].id, signal: .commandFinished(code: 1)), at: now)
        store.focus(threads[1].id)
        return store
    }
}
