import Foundation
import Observation
import OSLog

@MainActor @Observable
final class ThreadStore {
    private(set) var threads: [ShojiThread] {
        didSet { scheduleSave() }
    }
    private(set) var activities: [UUID: ThreadActivity]
    var layout: PaneLayout {
        didSet { scheduleSave() }
    }
    private(set) var focusedThreadId: UUID?
    /// Most recently focused first.
    private(set) var recentThreadIds: [UUID] = []
    /// A pane that should take keyboard focus once its terminal is on screen.
    private(set) var focusRequest: UUID?
    /// A busy thread the user asked to close; the window confirms before `close` runs.
    var closeRequest: UUID?
    /// ⌃Tab in progress (⌃ still held).
    private(set) var recentSwitch: RecentSwitch?

    /// Where `threads.json` lives; nil keeps everything in memory (tests, previews).
    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(threads: [ShojiThread], layout: PaneLayout = PaneLayout(), now: Date = .now, fileURL: URL? = nil) {
        let ids = Set(threads.map(\.id))
        var layout = layout
        layout.openThreadIds.removeAll { !ids.contains($0) }
        layout.pinnedThreadIds.removeAll { !ids.contains($0) }
        if let maximized = layout.maximizedThreadId, !ids.contains(maximized) { layout.maximizedThreadId = nil }
        self.threads = threads
        self.layout = layout
        self.fileURL = fileURL
        activities = Dictionary(uniqueKeysWithValues: threads.map { ($0.id, ThreadActivity(launchedAt: now)) })
    }

    func thread(_ id: UUID) -> ShojiThread? {
        threads.first { $0.id == id }
    }

    func activity(for id: UUID) -> ThreadActivity {
        activities[id] ?? ThreadActivity(launchedAt: .now)
    }

    func apply(_ event: StatusEvent, at now: Date = .now) {
        guard let index = threads.firstIndex(where: { $0.id == event.threadId }),
              let current = activities[event.threadId]
        else { return }
        var activity = current

        switch event.signal {
        case .launched:
            activity = ThreadActivity(launchedAt: now)
            // The launch already carried it to the prompt; nothing runs until the user presses Return.
            if threads[index].command != nil { threads[index].command = nil }
        case .directory(let path):
            activity.isIntegrated = true
            let folder = (path as NSString).abbreviatingWithTildeInPath
            if threads[index].folder != folder {
                // Last in line: of two threads in one folder, the one that arrived later carries the number.
                var thread = threads.remove(at: index)
                thread.folder = folder
                threads.append(thread)
            }
        case .commandStarted(let line):
            activity.isIntegrated = true
            threads[index].command = line
            activity.agent = Agent(commandLine: line)
            activity.detail = nil
            // An agent waits at its own prompt until a hook says otherwise; anything else is running.
            activity.transition(to: activity.agent == nil ? .running : .idle, at: now)
        case .commandFinished(let code):
            // Whatever ran has ended, an agent included, so there is nothing left to resume.
            if threads[index].command != nil { threads[index].command = nil }
            if threads[index].resumeId != nil { threads[index].resumeId = nil }
            activity.agent = nil
            activity.detail = nil
            activity.attention = 0
            // 130 is Ctrl-C: stopping a dev server on purpose isn't an error.
            activity.transition(to: code == 0 || code == 130 ? .idle : .exited(code: code), at: now)
        case .working(let sessionId):
            // Prompt and tool hooks only come from a session with content, so its id is safe to resume.
            if let sessionId, threads[index].resumeId != sessionId {
                threads[index].resumeId = sessionId
            }
            activity.agent = activity.agent ?? .claude
            activity.transition(to: .working, at: now)
            activity.detail = nil
        case .needsYou(let message):
            activity.agent = activity.agent ?? .claude
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
        case .bell where activity.agent != nil && activity.status == .working:
            activity.transition(to: .needsYou, at: now)
            activity.attention += 1
        case .title(let title):
            // Agents prefix titles with spinner glyphs; keep the words so cards don't redraw per frame.
            activity.terminalTitle = String(title.drop { !$0.isLetter && !$0.isNumber })
        case .exited(let code):
            activity.isAlive = false
            activity.agent = nil
            if threads[index].command != nil { threads[index].command = nil }
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
        if recentThreadIds.first != id { recentThreadIds = [id] + recentThreadIds.filter { $0 != id } }
        guard var activity = activities[id] else { return }
        let current = activity
        activity.attention = 0
        if activity.status == .done { activity.transition(to: .idle, at: now) }
        // A failed command has been seen once its pane is focused; a dead shell stays marked until restarted.
        if case .exited = activity.status, activity.isAlive { activity.transition(to: .idle, at: now) }
        if activity != current { activities[id] = activity }
    }

    // MARK: Adding and removing

    /// Opens a fresh shell right after the focused card, in that thread's folder (home when nothing is focused).
    @discardableResult
    func newThread(at now: Date = .now) -> UUID {
        let focused = focusedThreadId.flatMap(thread)
        let thread = ShojiThread(folder: focused?.folder ?? "~")
        var groups = shelfIds
        if let focused, let place = position(of: focused.id, in: groups) {
            groups[place.group].insert(thread.id, at: place.index + 1)
        } else if groups.isEmpty {
            groups = [[thread.id]]
        } else {
            groups[groups.count - 1].append(thread.id)
        }
        activities[thread.id] = ThreadActivity(launchedAt: now)
        threads.append(thread)
        arrange(groups)
        open(thread.id)
        return thread.id
    }

    /// The user's name for the thread, else its folder's name. Unnamed threads in folders of the same name
    /// are numbered in the order they got there: "shoji", "shoji 2".
    func name(of thread: ShojiThread) -> String {
        if let title = thread.title { return title }
        let twins = threads.filter { $0.title == nil && $0.folderName == thread.folderName }
        let place = twins.firstIndex { $0.id == thread.id } ?? 0
        return place == 0 ? thread.folderName : "\(thread.folderName) \(place + 1)"
    }

    /// An empty name goes back to showing the folder.
    func rename(_ id: UUID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = threads.firstIndex(where: { $0.id == id }), threads[index].title != title else { return }
        threads[index].title = title.isEmpty ? nil : title
    }

    /// Closes at once when nothing would be lost (the shell ended, or sits idle at its prompt);
    /// otherwise asks the window to confirm.
    func requestClose(_ id: UUID) {
        let activity = activity(for: id)
        let atPrompt = activity.isIntegrated && activity.agent == nil && thread(id)?.command == nil
        if !activity.isAlive || atPrompt {
            close(id)
        } else {
            closeRequest = id
        }
    }

    /// Removes the thread; `TerminalSessions.sync` then stops its process.
    func close(_ id: UUID) {
        if closeRequest == id { closeRequest = nil }
        layout.close(id)
        if focusedThreadId == id {
            focusedThreadId = nil
            focusRequest = layout.visibleThreadIds.first
        }
        threads.removeAll { $0.id == id }
        activities[id] = nil
        recentThreadIds.removeAll { $0 == id }
    }

    // MARK: Shelf

    /// Cards in shelf order, grouped; the shelf draws a bar between groups.
    var shelf: [[ShojiThread]] {
        Dictionary(grouping: threads, by: \.group)
            .sorted { $0.key < $1.key }
            .map { $0.value.sorted { $0.order < $1.order } }
    }

    /// ⌘1–9 index into this.
    var shelfOrder: [ShojiThread] {
        shelf.flatMap { $0 }
    }

    private var shelfIds: [[UUID]] {
        shelf.map { $0.map(\.id) }
    }

    func canMove(_ id: UUID, by offset: Int) -> Bool {
        let order = shelfOrder
        guard let index = order.firstIndex(where: { $0.id == id }) else { return false }
        return order.indices.contains(index + offset)
    }

    /// Moves a card one place along the shelf; across a bar it joins the neighbouring group.
    func move(_ id: UUID, by offset: Int) {
        var groups = shelfIds
        guard let place = position(of: id, in: groups) else { return }
        let target = place.index + offset
        if groups[place.group].indices.contains(target) {
            groups[place.group].swapAt(place.index, target)
        } else if groups.indices.contains(place.group + offset) {
            groups[place.group].remove(at: place.index)
            if offset > 0 { groups[place.group + offset].insert(id, at: 0) } else { groups[place.group + offset].append(id) }
            groups.removeAll(where: \.isEmpty)
        } else {
            return
        }
        arrange(groups)
    }

    /// Drag and drop: puts the card just before or after another one, in that card's group.
    func place(_ id: UUID, nextTo target: UUID, after: Bool) {
        guard id != target else { return }
        var groups = shelfIds
        guard let from = position(of: id, in: groups) else { return }
        groups[from.group].remove(at: from.index)
        guard let to = position(of: target, in: groups) else { return }
        groups[to.group].insert(id, at: to.index + (after ? 1 : 0))
        groups.removeAll(where: \.isEmpty)
        arrange(groups)
    }

    /// True when the card starts a group that has another group to its left.
    func hasBarBefore(_ id: UUID) -> Bool {
        guard let place = position(of: id, in: shelfIds) else { return false }
        return place.index == 0 && place.group > 0
    }

    /// Adds a bar before the card, so it and the cards after it form their own group;
    /// or removes that bar, merging its group into the one on the left.
    func toggleBarBefore(_ id: UUID) {
        var groups = shelfIds
        guard let place = position(of: id, in: groups) else { return }
        if place.index > 0 {
            groups.insert(Array(groups[place.group][place.index...]), at: place.group + 1)
            groups[place.group].removeSubrange(place.index...)
        } else if place.group > 0 {
            groups[place.group - 1] += groups[place.group]
            groups.remove(at: place.group)
        } else {
            return
        }
        arrange(groups)
    }

    private func position(of id: UUID, in groups: [[UUID]]) -> (group: Int, index: Int)? {
        for (group, ids) in groups.enumerated() {
            if let index = ids.firstIndex(of: id) { return (group, index) }
        }
        return nil
    }

    /// Writes `group` and `order` from the arrangement, numbering both from zero.
    private func arrange(_ groups: [[UUID]]) {
        var placement: [UUID: (group: Int, order: Int)] = [:]
        for (group, ids) in groups.enumerated() {
            for (order, id) in ids.enumerated() { placement[id] = (group, order) }
        }
        threads = threads.map { thread in
            guard let place = placement[thread.id] else { return thread }
            var thread = thread
            thread.group = place.group
            thread.order = place.order
            return thread
        }
    }

    // MARK: Panes

    /// Shows the thread in a free pane, else in the pane you're in (or, with none, the one used longest ago that
    /// isn't waiting for you), and focuses it. Pinned panes are passed over unless every pane is pinned.
    /// A thread already on screen just takes focus.
    func open(_ id: UUID) {
        let unpinned = layout.panes.filter { !layout.pinnedThreadIds.contains($0) }
        let candidates = unpinned.isEmpty ? layout.panes : unpinned
        let notWaiting = candidates.filter { activity(for: $0).status != .needsYou }
        let replaced = candidates.first { $0 == focusedThreadId }
            ?? (notWaiting.isEmpty ? candidates : notWaiting).reversed().max { recency($0) < recency($1) }
        layout.show(id, replacing: replaced)
        focusRequest = id
    }

    /// A card click (or ⌘1–9): the thread comes to the pane you're in, trading places when it's on screen
    /// elsewhere. ⌃Tab and ⌘J use `open` instead and go to the thread where it is.
    func bringHere(_ id: UUID) {
        guard let focusedThreadId, focusedThreadId != id, layout.panes.contains(focusedThreadId), layout.panes.contains(id) else {
            return open(id)
        }
        show(id, inPaneOf: focusedThreadId)
    }

    /// Drag and drop onto a pane: the thread takes that pane, even a pinned one.
    func show(_ id: UUID, inPaneOf target: UUID) {
        layout.put(id, inPaneOf: target)
        focusRequest = id
    }

    func togglePin(_ id: UUID) {
        layout.togglePin(id)
    }

    /// Position in `recentThreadIds`; threads never focused count as oldest.
    private func recency(_ id: UUID) -> Int {
        recentThreadIds.firstIndex(of: id) ?? .max
    }

    /// Switching layouts keeps the pane you're in and pinned panes on screen, and fills new panes with
    /// the threads shown there before, then your most recent ones, then the shelf's.
    var layoutMode: PaneLayout.Mode {
        get { layout.mode }
        set {
            var layout = self.layout
            layout.mode = newValue
            let keep = (focusedThreadId.map { [$0] } ?? []) + layout.pinnedThreadIds
            for id in keep {
                guard let index = layout.openThreadIds.firstIndex(of: id), index >= newValue.capacity,
                      let slot = layout.openThreadIds.prefix(newValue.capacity).lastIndex(where: { !keep.contains($0) })
                else { continue }
                layout.openThreadIds.swapAt(index, slot)
            }
            for id in recentThreadIds + shelfOrder.map(\.id) where layout.openThreadIds.count < newValue.capacity {
                if !layout.openThreadIds.contains(id) { layout.openThreadIds.append(id) }
            }
            self.layout = layout
        }
    }

    func toggleMaximize(_ id: UUID) {
        layout.toggleMaximize(id)
        focusRequest = id
    }

    // MARK: Keyboard navigation

    func openThread(at index: Int) {
        let order = shelfOrder
        guard order.indices.contains(index) else { return }
        bringHere(order[index].id)
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

    // MARK: Recent threads

    struct RecentSwitch: Equatable {
        /// The thread you're in first, then the others in the order you last used them.
        var threadIds: [UUID]
        var index: Int
        var selected: UUID { threadIds[index] }
    }

    /// ⌃Tab steps through threads in the order you last used them, ⌃⇧Tab the other way, like ⌘Tab for apps.
    /// The first ⌃Tab picks the previous thread; `finishRecentSwitch` opens the pick once ⌃ is released.
    func stepRecent(by offset: Int) {
        if var current = recentSwitch {
            current.index = (current.index + offset + current.threadIds.count) % current.threadIds.count
            recentSwitch = current
            return
        }
        var ids = focusedThreadId.map { [$0] } ?? []
        for id in recentThreadIds + shelfOrder.map(\.id) where !ids.contains(id) { ids.append(id) }
        let start = focusedThreadId == nil ? 0 : 1
        guard ids.count > start else { return }
        recentSwitch = RecentSwitch(threadIds: ids, index: offset > 0 ? start : ids.count - 1)
    }

    func finishRecentSwitch() {
        guard let recentSwitch else { return }
        self.recentSwitch = nil
        if thread(recentSwitch.selected) != nil { open(recentSwitch.selected) }
    }

    func cancelRecentSwitch() {
        if recentSwitch != nil { recentSwitch = nil }
    }

    // MARK: Saving

    /// Coalesces bursts (a split drag changes the layout every frame) into one write.
    private func scheduleSave() {
        guard fileURL != nil else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard (try? await Task.sleep(for: .milliseconds(500))) != nil else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard let fileURL else { return }
        do {
            try ThreadFile(threads: threads, layout: layout).write(to: fileURL)
        } catch {
            Logger(subsystem: "fi.yan.shoji", category: "threads").error("Couldn't save \(fileURL.path, privacy: .public): \(error)")
        }
    }
}
