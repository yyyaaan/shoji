import Foundation

/// Preview data matching the design mockups.
enum Mock {
    static let threads: [ShojiThread] = [
        ShojiThread(group: .agent, kind: .claude, title: "auth-refactor", folder: "~/code/gosta", command: ["claude"], order: 0),
        ShojiThread(group: .agent, kind: .claude, title: "extension popup", folder: "~/code/gosta-browser-extension", command: ["claude"], order: 1),
        ShojiThread(group: .agent, kind: .codex, title: "helm cleanup", folder: "~/home-lab/k3s", command: ["codex"], order: 2),
        ShojiThread(group: .agent, kind: .claude, title: "shoji spike", folder: "~/lab/shoji", command: ["claude"], order: 3),
        ShojiThread(group: .task, kind: .command, title: "api stack", folder: "~/code/gosta", command: ["docker", "compose", "up"], order: 0),
        ShojiThread(group: .task, kind: .command, title: "web dev", folder: "~/code/gosta", command: ["pnpm", "dev"], order: 1),
        ShojiThread(group: .task, kind: .command, title: "extension watch", folder: "~/code/gosta-browser-extension", command: ["pnpm", "build", "--watch"], order: 2),
    ]

    @MainActor
    static func store() -> ThreadStore {
        let now = Date.now
        let store = ThreadStore(
            threads: threads,
            layout: PaneLayout(mode: .twoColumns, openThreadIds: [threads[1].id, threads[4].id]),
            now: now
        )
        store.apply(StatusEvent(threadId: threads[0].id, signal: .needsYou(message: "Allow Bash: uv run pytest…")), at: now)
        store.apply(StatusEvent(threadId: threads[1].id, signal: .working(sessionId: nil)), at: now.addingTimeInterval(-6 * 60))
        store.apply(StatusEvent(threadId: threads[2].id, signal: .finished), at: now.addingTimeInterval(-14 * 60))
        store.apply(StatusEvent(threadId: threads[6].id, signal: .exited(code: 1)), at: now)
        store.focus(threads[1].id)
        return store
    }
}
