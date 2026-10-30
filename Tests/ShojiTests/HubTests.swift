import Foundation
import Testing
@testable import Shoji

/// The Hub: who has the keyboard around it, what its cards read, and where they read it from.
@MainActor
struct HubTests {
    @Test func theHubTakesTheKeyboardAndAnyGoToLeavesIt() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        store.focus(ids[1])
        store.showsHub = true
        #expect(store.focusRequest == nil)

        store.showsHub = false
        #expect(store.focusRequest == ids[1])

        store.focus(ids[1])
        store.showsHub = true
        store.open(ids[2])
        #expect(!store.showsHub)
        #expect(store.focusRequest == ids[2])

        store.showsHub = true
        store.isCompact = true
        #expect(!store.showsHub)
    }

    @Test func closingFromTheHubStaysThere() {
        let (threads, ids) = numberedThreads(3)
        let store = ThreadStore(threads: threads, layout: PaneLayout(.twoColumns, [ids[0], ids[1]]))
        store.focus(ids[1])
        store.showsHub = true
        store.close(ids[1])
        #expect(store.showsHub)
        store.showsHub = false
        #expect(store.focusRequest == store.layout.visibleThreadIds.first)
    }

    @Test func aToolStepShowsWhileWorkingOnly() {
        let (threads, ids) = numberedThreads(1)
        let store = ThreadStore(threads: threads)
        store.send(.working(sessionId: nil, step: "Edit Header.tsx"), to: ids[0])
        #expect(store.activity(for: ids[0]).detail == "Edit Header.tsx")
        store.send(.working(sessionId: nil), to: ids[0])
        #expect(store.activity(for: ids[0]).detail == nil)
        store.send(.working(sessionId: nil, step: "Bash ls"), to: ids[0])
        store.send(.finished, to: ids[0])
        #expect(store.activity(for: ids[0]).detail == nil)
    }

    @Test func excerptSkipsAnAgentsInputBoxAndBlankRows() {
        let claude = ["● Update App.tsx", "", "● Bash pnpm test", "✻ Working… (12s)", "", "╭──────────╮", "│ > fix it │", "╰──────────╯", "  ? for shortcuts", "", ""]
        #expect(Excerpt.lines(claude, count: 4) == ["● Update App.tsx", "● Bash pnpm test", "✻ Working… (12s)"])
        let shell = ["yan@box ~ % ls", "a  b  c", "yan@box ~ % ", "", "", ""]
        #expect(Excerpt.lines(shell, count: 2) == ["a  b  c", "yan@box ~ % "])
        #expect(Excerpt.lines([], count: 4).isEmpty)
    }

    @Test func gitBranchComesFromHEADUpTheTree() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "shoji-git-\(UUID().uuidString)").path(percentEncoded: false)
        defer { try? FileManager.default.removeItem(atPath: root) }
        let repo = root + "/repo"
        try FileManager.default.createDirectory(atPath: repo + "/.git", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: repo + "/src/deep", withIntermediateDirectories: true)
        try "ref: refs/heads/feat/token-store\n".write(toFile: repo + "/.git/HEAD", atomically: true, encoding: .utf8)
        #expect(GitBranch.of(repo) == "feat/token-store")
        #expect(GitBranch.of(repo + "/src/deep") == "feat/token-store")

        try "4f2a9c1e0b7d\n".write(toFile: repo + "/.git/HEAD", atomically: true, encoding: .utf8)
        #expect(GitBranch.of(repo) == "4f2a9c1")

        let worktree = root + "/worktree"
        try FileManager.default.createDirectory(atPath: repo + "/.git/worktrees/wt", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: worktree, withIntermediateDirectories: true)
        try "ref: refs/heads/hub\n".write(toFile: repo + "/.git/worktrees/wt/HEAD", atomically: true, encoding: .utf8)
        try "gitdir: ../repo/.git/worktrees/wt\n".write(toFile: worktree + "/.git", atomically: true, encoding: .utf8)
        #expect(GitBranch.of(worktree) == "hub")

        #expect(GitBranch.of(root) == nil)
    }
}
