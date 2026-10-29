import CoreGraphics
import Foundation
import Observation
import OSLog

@MainActor @Observable
final class ThreadStore {
    private(set) var threads: [ShojiThread] {
        didSet { scheduleSave() }
    }
    private(set) var activities: [UUID: ThreadActivity]
    private(set) var fullLayout: PaneLayout {
        didSet { scheduleSave() }
    }
    /// One column of at most two rows.
    private(set) var compactLayout: PaneLayout {
        didSet { scheduleSave() }
    }
    /// The narrow form (Split View beside an editor), which keeps its own panes.
    var isCompact = false {
        didSet {
            guard isCompact != oldValue else { return }
            if layout.root == nil, let id = focusedThreadId ?? (recentThreadIds + shelfOrder.map(\.id)).first {
                layout.show(id, replacing: nil)
            }
            let visible = layout.visibleThreadIds
            focusRequest = focusedThreadId.flatMap { visible.contains($0) ? $0 : nil } ?? visible.first
        }
    }
    /// The panes of the form on screen.
    var layout: PaneLayout {
        get { isCompact ? compactLayout : fullLayout }
        set { if isCompact { compactLayout = newValue } else { fullLayout = newValue } }
    }
    private(set) var focusedThreadId: UUID?
    /// Most recently focused first.
    private(set) var recentThreadIds: [UUID] = []
    /// A pane that should take keyboard focus once its terminal is on screen.
    private(set) var focusRequest: UUID?
    /// The last go-to that landed on a pane already on screen; that pane glows.
    private(set) var paneGlow: PaneGlow?
    /// A busy thread the user asked to close; the window confirms before `close` runs.
    var closeRequest: UUID?
    /// ⌃Tab in progress (⌃ still held).
    private(set) var recentSwitch: RecentSwitch?
    /// ⌘ held on its own: the first nine cards show their ⌘1–9 number.
    var showsCardNumbers = false
    /// Threads › Show Hachi When an Agent Finishes: an unseen finished turn wants you too, not just its quiet tick.
    var hachiOnFinish = true
    /// False while another app is in front, when even the focused pane is out of sight.
    var isAppActive = true {
        didSet {
            if isAppActive, !oldValue, let focusedThreadId { focus(focusedThreadId) }
        }
    }

    /// Kept current by `PaneGrid` so splits stay usable; zero (tests) allows any split.
    @ObservationIgnored var paneAreaSize = CGSize.zero
    static let minimumPaneSize = CGSize(width: 320, height: 160)

    /// Where `threads.json` lives; nil keeps everything in memory (tests, previews).
    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(threads: [ShojiThread], layout: PaneLayout = PaneLayout(), compactLayout: PaneLayout = PaneLayout(), now: Date = .now, fileURL: URL? = nil) {
        let ids = Set(threads.map(\.id))
        var (layout, compactLayout) = (layout, compactLayout)
        for id in layout.panes where !ids.contains(id) { layout.removePane(id) }
        for id in compactLayout.panes where !ids.contains(id) { compactLayout.removePane(id) }
        self.threads = threads
        fullLayout = layout
        self.compactLayout = compactLayout
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
            if threads[index].folder != folder { threads[index].folder = folder }
        case .commandStarted(let line):
            activity.isIntegrated = true
            threads[index].command = line
            activity.agent = Agent(commandLine: line)
            activity.detail = nil
            // An earlier agent's topic mustn't stick.
            activity.terminalTitle = nil
            // An agent waits at its own prompt until a hook says otherwise; anything else is running.
            activity.transition(to: activity.agent == nil ? .running : .idle, at: now)
        case .commandFinished(let code):
            // Whatever ran has ended, an agent included, so there is nothing left to resume.
            if threads[index].command != nil { threads[index].command = nil }
            if threads[index].resumeId != nil {
                threads[index].resumeId = nil
                threads[index].resumeAgent = nil
            }
            activity.agent = nil
            activity.detail = nil
            activity.attention = 0
            // 130 is Ctrl-C: stopping a dev server on purpose isn't an error.
            activity.transition(to: code == 0 || code == 130 ? .idle : .exited(code: code), at: now)
        case .working(let sessionId):
            activity.agent = activity.agent ?? .claude
            // Prompt and tool hooks only come from a session with content, so its id is safe to resume.
            if let sessionId, threads[index].resumeId != sessionId || threads[index].resumeAgent != activity.agent {
                threads[index].resumeId = sessionId
                threads[index].resumeAgent = activity.agent
            }
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
            activity.isUnseen = !(isAppActive && focusedThreadId == event.threadId)
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

    /// Waiting on an answer, or (with `hachiOnFinish`) done while you weren't looking: Hachi, orange card, ⌘J.
    func wantsYou(_ id: UUID) -> Bool {
        let activity = activity(for: id)
        return activity.status == .needsYou || (hachiOnFinish && activity.isUnseen)
    }

    /// What quitting would stop. An agent idle at its prompt resumes on relaunch, so it doesn't count.
    var busyThreads: [ShojiThread] {
        shelfOrder.filter { [.working, .needsYou, .running].contains(activity(for: $0.id).status) }
    }

    /// Shelf order, needs-you first: Hachi's count, the Dock badge and notifications.
    var wantingYou: [ShojiThread] {
        let waiting = shelfOrder.filter { wantsYou($0.id) }
        let asking = waiting.filter { activity(for: $0.id).status == .needsYou }
        return asking + waiting.filter { activity(for: $0.id).status != .needsYou }
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

    /// Opens a fresh shell right after the focused card, in that thread's folder (home when nothing is focused);
    /// with `target`, after that card and in its pane.
    @discardableResult
    func newThread(inPaneOf target: UUID? = nil, at now: Date = .now) -> UUID {
        let id = addThread(after: target ?? focusedThreadId, at: now)
        if let target { show(id, inPaneOf: target) } else { open(id) }
        return id
    }

    /// A fresh shell right after `neighbour`'s card, in its folder (home without one).
    private func addThread(after neighbour: UUID?, at now: Date = .now) -> UUID {
        let thread = ShojiThread(folder: neighbour.flatMap(thread)?.folder ?? "~")
        insert(thread, after: neighbour, at: now)
        return thread.id
    }

    /// A quick terminal closed while running something joins the shelf after the focused card, without a pane.
    func adopt(_ thread: ShojiThread, running command: String, at now: Date = .now) {
        insert(thread, after: focusedThreadId, at: now)
        apply(StatusEvent(threadId: thread.id, signal: .directory(thread.folder)), at: now)
        apply(StatusEvent(threadId: thread.id, signal: .commandStarted(command)), at: now)
    }

    private func insert(_ thread: ShojiThread, after neighbour: UUID?, at now: Date) {
        var groups = shelfIds
        if let neighbour, let place = position(of: neighbour, in: groups) {
            groups[place.group].insert(thread.id, at: place.index + 1)
        } else if groups.isEmpty {
            groups = [[thread.id]]
        } else {
            groups[groups.count - 1].append(thread.id)
        }
        activities[thread.id] = ThreadActivity(launchedAt: now)
        threads.append(thread)
        arrange(groups)
    }

    /// Your rename, else the agent's topic, else the folder's name. Same-named folders are numbered oldest first, so a `cd` and back changes nothing.
    func name(of thread: ShojiThread) -> String {
        if let title = thread.title { return title }
        if let topic = activities[thread.id]?.topic { return topic }
        let twins = threads.filter { $0.title == nil && activities[$0.id]?.topic == nil && $0.folderName == thread.folderName }
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

    /// `TerminalSessions.sync` then stops its process. The last pane shows your most recent other thread.
    func close(_ id: UUID) {
        if closeRequest == id { closeRequest = nil }
        let taker = layout.root?.sibling(of: id)?.panes.first
        fullLayout.removePane(id)
        compactLayout.removePane(id)
        recentThreadIds.removeAll { $0 == id }
        threads.removeAll { $0.id == id }
        activities[id] = nil
        if layout.root == nil, let next = (recentThreadIds + shelfOrder.map(\.id)).first {
            layout.show(next, replacing: nil)
        }
        if focusedThreadId == id {
            focusedThreadId = nil
            focusRequest = taker ?? layout.visibleThreadIds.first
        }
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

    /// In your pane, else the least recently used one not waiting for you. On screen: focus only; gone: ignored.
    func open(_ id: UUID) {
        guard thread(id) != nil else { return }
        if layout.panes.contains(id), id != focusedThreadId {
            paneGlow = PaneGlow(threadId: id, serial: (paneGlow?.serial ?? 0) + 1)
        }
        let panes = layout.panes
        let notWaiting = panes.filter { !wantsYou($0) }
        let replaced = panes.first { $0 == focusedThreadId }
            ?? (notWaiting.isEmpty ? panes : notWaiting).reversed().max { recency($0) < recency($1) }
        layout.show(id, replacing: replaced)
        focusRequest = id
    }

    /// ⌥-click on a card, or Show in This Pane: the thread comes to the pane you're in, trading places when
    /// it's on screen elsewhere. A plain click uses `open` and goes to the thread where it is.
    func bringHere(_ id: UUID) {
        guard let focusedThreadId, focusedThreadId != id, layout.panes.contains(focusedThreadId) else { return open(id) }
        show(id, inPaneOf: focusedThreadId)
    }

    /// Drag and drop onto a pane: the thread takes that pane.
    func show(_ id: UUID, inPaneOf target: UUID) {
        layout.put(id, inPaneOf: target)
        focusRequest = id
    }

    /// Position in `recentThreadIds`; threads never focused count as oldest.
    private func recency(_ id: UUID) -> Int {
        recentThreadIds.firstIndex(of: id) ?? .max
    }

    /// Keeps your pane on screen and fills new panes from recent threads, then the shelf.
    func arrange(_ preset: PaneLayout.Preset) {
        guard !isCompact || preset == .single else { return }
        var ids = layout.panes
        if let focused = focusedThreadId, let index = ids.firstIndex(of: focused), index >= preset.capacity {
            ids.swapAt(index, preset.capacity - 1)
        }
        ids = Array(ids.prefix(preset.capacity))
        for id in recentThreadIds + shelfOrder.map(\.id) where ids.count < preset.capacity && !ids.contains(id) {
            ids.append(id)
        }
        layout.root = preset.tree(ids)
        layout.maximizedThreadId = nil
    }

    /// The new pane shows your most recent hidden thread, else a new shell. False when the pane is gone or too small.
    @discardableResult
    func split(_ target: UUID? = nil, side: PaneLayout.Side) -> Bool {
        guard let target = target ?? focusedThreadId, canSplit(target, side: side) else { return false }
        let id = (recentThreadIds + shelfOrder.map(\.id)).first { !layout.panes.contains($0) }
            ?? addThread(after: target)
        layout.split(target, side: side, with: id)
        focusRequest = id
        return true
    }

    /// A card dropped on a pane's edge.
    @discardableResult
    func split(_ target: UUID, side: PaneLayout.Side, showing id: UUID) -> Bool {
        guard id != target, canSplit(target, side: side) else { return false }
        layout.split(target, side: side, with: id)
        focusRequest = id
        return true
    }

    /// The thread keeps running on the shelf; the last pane stays.
    func closePane(_ id: UUID) {
        guard layout.panes.count > 1, let taker = layout.root?.sibling(of: id)?.panes.first else { return }
        layout.removePane(id)
        if focusedThreadId == id {
            focusedThreadId = nil
            focusRequest = taker
        }
    }

    private func canSplit(_ target: UUID, side: PaneLayout.Side) -> Bool {
        guard layout.panes.contains(target) else { return false }
        if isCompact, side == .left || side == .right || layout.panes.count > 1 { return false }
        guard paneAreaSize != .zero else { return true }
        guard let rect = PaneTiles(layout.root, in: CGRect(origin: .zero, size: paneAreaSize)).panes[target] else { return false }
        let minimum = Self.minimumPaneSize
        return side == .left || side == .right
            ? (rect.width - PaneTiles.gap) / 2 >= minimum.width
            : (rect.height - PaneTiles.gap) / 2 >= minimum.height
    }

    /// Only while a level is left that way, so steps never pile up; `by: nil` puts it back.
    func stepTextSize(of id: UUID, by step: Int?, global: Double) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
        let current = threads[index].textSteps ?? 0
        guard let step else { return threads[index].textSteps = nil }
        guard TextZoom.level(global, steps: current + step) != TextZoom.level(global, steps: current) else { return }
        threads[index].textSteps = current + step == 0 ? nil : current + step
    }

    func toggleMaximize(_ id: UUID) {
        layout.toggleMaximize(id)
        focusRequest = id
    }

    // MARK: Keyboard navigation

    func openThread(at index: Int) {
        let order = shelfOrder
        guard order.indices.contains(index) else { return }
        open(order[index].id)
    }

    /// Opens the next thread in shelf order that wants the user, wrapping around. False when none does.
    @discardableResult
    func openNextNeedingYou() -> Bool {
        let order = shelfOrder
        let start = order.firstIndex { $0.id == focusedThreadId }.map { $0 + 1 } ?? 0
        let rotated = order[start...] + order[..<start]
        guard let next = rotated.first(where: { wantsYou($0.id) }) else { return false }
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

    /// `serial` changes on every go-to, so the same pane can glow twice in a row.
    struct PaneGlow: Equatable {
        let threadId: UUID
        let serial: Int
    }

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
            try ThreadFile(threads: threads, layout: fullLayout, compactLayout: compactLayout.root == nil ? nil : compactLayout).write(to: fileURL)
        } catch {
            Logger(subsystem: "fi.yan.shoji", category: "threads").error("Couldn't save \(fileURL.path, privacy: .public): \(error)")
        }
    }
}
