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
        store.layout.mode = .grid
        store.layout.columnSplit = 0.3
        store.apply(StatusEvent(threadId: id, signal: .directory("/tmp")))
        store.apply(StatusEvent(threadId: id, signal: .commandStarted("claude --model opus")))
        store.apply(StatusEvent(threadId: id, signal: .working(sessionId: "s1")))
        store.saveNow()

        let saved = try #require(ThreadFile.load(from: url))
        #expect(saved.schemaVersion == 1)
        #expect(saved.threads.map(\.id) == [id])
        #expect(saved.threads.first?.folder == "/tmp")
        #expect(saved.threads.first?.resumeId == "s1")
        #expect(saved.threads.first?.command == "claude --model opus")
        #expect(saved.layout.mode == .grid)
        #expect(saved.layout.columnSplit == 0.3)
        #expect(saved.layout.openThreadIds == [id])
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

    @Test func filesWithThreadNumbersStillLoad() throws {
        let id = UUID()
        let json = #"{"schemaVersion": 1, "threads": [{"id": "\#(id)", "number": 2, "folder": "~/lab/shoji", "group": 0, "order": 0}], "layout": {"mode": "single", "openThreadIds": ["\#(id)"], "columnSplit": 0.5, "rowSplit": 0.5}}"#
        try Data(json.utf8).write(to: url)
        let file = try #require(ThreadFile.load(from: url))
        #expect(file.threads.map(\.id) == [id])
    }

    @Test func layoutDropsThreadsThatNoLongerExist() {
        let thread = ShojiThread(folder: "/tmp")
        let gone = UUID()
        let store = ThreadStore(threads: [thread], layout: PaneLayout(openThreadIds: [gone, thread.id], maximizedThreadId: gone))
        #expect(store.layout.openThreadIds == [thread.id])
        #expect(store.layout.maximizedThreadId == nil)
    }
}
