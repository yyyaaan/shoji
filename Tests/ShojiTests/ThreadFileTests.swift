import Foundation
import Testing
@testable import Shoji

@MainActor
struct ThreadFileTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "shoji-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var url: URL { folder.appending(path: "threads.json") }

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test func storeRoundTripsThreadsAndLayout() throws {
        let store = ThreadStore(threads: [], fileURL: url)
        let id = store.newThread()
        store.split(id, side: .right)
        store.layout.setRatio(0.3, at: [])
        store.stepTextSize(of: id, by: -1, global: 1)
        store.apply(StatusEvent(threadId: id, signal: .directory("/tmp")))
        store.apply(StatusEvent(threadId: id, signal: .commandStarted("claude --model opus")))
        store.apply(StatusEvent(threadId: id, signal: .working(sessionId: "s1")))
        store.saveNow()

        let saved = try #require(ThreadFile.load(from: url))
        #expect(saved.schemaVersion == 1)
        #expect(saved.threads.map(\.id) == store.layout.panes)
        #expect(saved.threads.first?.folder == "/tmp")
        #expect(saved.threads.first?.resumeId == "s1")
        #expect(saved.threads.first?.command == "claude --model opus")
        #expect(saved.threads.first?.textSteps == -1)
        #expect(saved.layout == store.layout)
    }

    @Test func missingFileLoadsAsNothing() {
        #expect(ThreadFile.load(from: url) == nil)
    }

    @Test func unreadableFileIsKeptAsideNotOverwritten() throws {
        try Data("{ not json".utf8).write(to: url)
        #expect(ThreadFile.load(from: url) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(kept.count == 1)
        #expect(kept.first?.hasPrefix("threads.unreadable-") == true)
    }

    @Test func newerSchemaIsKeptAside() throws {
        try Data(#"{"schemaVersion": 99, "threads": [], "layout": {}}"#.utf8).write(to: url)
        #expect(ThreadFile.load(from: url) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).count == 1)
    }

    /// v0.2 files have thread numbers and no resume agents; up to v0.3 a layout is a fixed one with pins (now
    /// ignored), and may miss any key.
    @Test func olderFilesStillLoad() throws {
        let id = UUID()
        let json = #"{"schemaVersion": 1, "threads": [{"id": "\#(id)", "number": 2, "folder": "~/lab/shoji", "group": 0, "order": 0, "resumeId": "s1"}], "layout": {"mode": "single", "openThreadIds": ["\#(id)"], "columnSplit": 0.5, "rowSplit": 0.5}}"#
        try Data(json.utf8).write(to: url)
        let file = try #require(ThreadFile.load(from: url))
        #expect(file.threads.map(\.id) == [id])
        #expect(file.threads.first?.resumeAgent == nil)
        #expect(file.layout.panes == [id])

        let (a, b, c) = (UUID(), UUID(), UUID())
        let v3 = #"{"mode": "threePanes", "openThreadIds": ["\#(a)", "\#(b)", "\#(c)", "\#(UUID())"], "columnSplit": 0.3, "pinnedThreadIds": ["\#(b)"]}"#
        let layout = try JSONDecoder().decode(PaneLayout.self, from: Data(v3.utf8))
        #expect(layout.root == PaneLayout.Preset.threePanes.tree([a, b, c], columnSplit: 0.3))

        let empty = try JSONDecoder().decode(PaneLayout.self, from: Data(#"{"mode": "grid", "openThreadIds": []}"#.utf8))
        #expect(empty.root == nil)
    }

    @Test func layoutDropsThreadsThatNoLongerExist() {
        let thread = ShojiThread(folder: "/tmp")
        let gone = UUID()
        var layout = PaneLayout(.twoColumns, [gone, thread.id])
        layout.maximizedThreadId = gone
        let store = ThreadStore(threads: [thread], layout: layout)
        #expect(store.layout.panes == [thread.id])
        #expect(store.layout.maximizedThreadId == nil)
    }
}
