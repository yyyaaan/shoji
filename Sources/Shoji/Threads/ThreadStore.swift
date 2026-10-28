import Foundation
import Observation

@MainActor @Observable
final class ThreadStore {
    private(set) var threads: [ShojiThread]
    private(set) var activities: [UUID: ThreadActivity]
    var layout: PaneLayout
    private(set) var focusedThreadId: UUID?
    /// A pane that should take keyboard focus once its terminal is on screen.
    private(set) var focusRequest: UUID?

    init(threads: [ShojiThread], layout: PaneLayout = PaneLayout(), now: Date = .now) {
        self.threads = threads
        self.layout = layout
        activities = Dictionary(uniqueKeysWithValues: threads.map {
            ($0.id, ThreadActivity(status: $0.group == .agent ? .idle : .running, since: now))
        })
    }

    func thread(_ id: UUID) -> ShojiThread? {
        threads.first { $0.id == id }
    }

    func threads(in group: ShojiThread.Group) -> [ShojiThread] {
        threads.filter { $0.group == group }.sorted { $0.order < $1.order }
    }

    func activity(for id: UUID) -> ThreadActivity {
        activities[id] ?? ThreadActivity(status: .idle, since: .now)
    }

    func apply(_ event: StatusEvent, at now: Date = .now) {
        guard let index = threads.firstIndex(where: { $0.id == event.threadId }),
              let current = activities[event.threadId]
        else { return }
        let isAgent = threads[index].group == .agent
        var activity = current

        switch event.signal {
        case .launched:
            activity.transition(to: isAgent ? .idle : .running, at: now)
        case .working(let sessionId):
            // Prompt and tool hooks only come from a session with content, so its id is safe to resume.
            if let sessionId, threads[index].resumeId != sessionId {
                threads[index].resumeId = sessionId
            }
            activity.transition(to: .working, at: now)
            activity.detail = nil
        case .needsYou(let message):
            activity.transition(to: .needsYou, at: now)
            activity.detail = message
            activity.attention += 1
        case .finished:
            activity.transition(to: .done, at: now)
            activity.detail = nil
        case .userInput where activity.status == .needsYou:
            // Typing into a waiting agent answers it; no hook fires until the approved tool finishes.
            activity.transition(to: .working, at: now)
            activity.detail = nil
        case .bell where isAgent && activity.status == .working:
            activity.transition(to: .needsYou, at: now)
            activity.attention += 1
        case .title(let title):
            // Agents prefix titles with spinner glyphs; keep the words so cards don't redraw per frame.
            activity.terminalTitle = String(title.drop { !$0.isLetter && !$0.isNumber })
        case .exited(let code):
            activity.transition(to: .exited(code: code), at: now)
        case .userInput, .bell:
            break
        }

        if activity != current {
            activities[event.threadId] = activity
        }
    }

    /// Called when a thread's terminal takes keyboard focus.
    func focus(_ id: UUID, at now: Date = .now) {
        if focusedThreadId != id { focusedThreadId = id }
        if focusRequest == id { focusRequest = nil }
        guard var activity = activities[id] else { return }
        let current = activity
        activity.attention = 0
        if activity.status == .done { activity.transition(to: .idle, at: now) }
        if activity != current { activities[id] = activity }
    }

    func open(_ id: UUID) {
        layout.open(id, keeping: focusedThreadId)
        focusRequest = id
    }

    func minimize(_ id: UUID) {
        layout.close(id)
        guard focusedThreadId == id else { return }
        focusedThreadId = nil
        focusRequest = layout.visibleThreadIds.first
    }

    func toggleMaximize(_ id: UUID) {
        layout.toggleMaximize(id)
        focusRequest = id
    }

    // MARK: Keyboard navigation

    /// Agents then tasks, as the shelf shows them; ⌘1–9 index into this.
    var shelfOrder: [ShojiThread] {
        threads(in: .agent) + threads(in: .task)
    }

    func openThread(at index: Int) {
        guard shelfOrder.indices.contains(index) else { return }
        open(shelfOrder[index].id)
    }

    /// Opens the next thread in shelf order that needs the user, wrapping around. False when none does.
    @discardableResult
    func openNextNeedingYou() -> Bool {
        let order = shelfOrder
        let start = order.firstIndex { $0.id == focusedThreadId }.map { $0 + 1 } ?? 0
        let rotated = order[start...] + order[..<start]
        guard let next = rotated.first(where: { activity(for: $0.id).status == .needsYou }) else { return false }
        open(next.id)
        return true
    }

    func focusPane(offset: Int) {
        let visible = layout.visibleThreadIds
        guard !visible.isEmpty else { return }
        let current = visible.firstIndex { $0 == focusedThreadId } ?? (offset > 0 ? -1 : 0)
        focusRequest = visible[(current + offset + visible.count) % visible.count]
    }
}
