import Foundation
import Synchronization
import Testing
@testable import Shoji

/// Runs the bundled `shoji-hook` script against a real `HookServer`, as Claude Code would.
struct HookPipelineTests {
    private let socketPath = NSTemporaryDirectory() + "shoji-\(UUID().uuidString.prefix(8)).sock"

    @Test func hookPayloadReachesTheServer() throws {
        let received = Mutex<[Data]>([])
        let server = try HookServer(path: socketPath) { message in
            received.withLock { $0.append(message) }
        }
        let threadId = UUID()

        let result = try runHook(stdin: #"{"hook_event_name":"Stop","session_id":"s1"}"#, threadId: threadId)
        withExtendedLifetime(server) {}

        #expect(result.status == 0)
        let event = try #require(received.withLock { $0.first }.flatMap(StatusEvent.init(hookMessage:)))
        #expect(event == StatusEvent(threadId: threadId, signal: .finished))
    }

    @Test func hookIsSilentAndFastWithoutShoji() throws {
        let result = try runHook(stdin: #"{"hook_event_name":"Stop"}"#, threadId: UUID())
        #expect(result.status == 0)
        #expect(result.output.isEmpty)
        #expect(result.duration < .milliseconds(500))
    }

    private func runHook(stdin: String, threadId: UUID) throws -> (status: Int32, output: Data, duration: Duration) {
        let script = try #require(Bundle.main.url(forResource: "shoji-hook", withExtension: nil))
        let process = Process()
        process.executableURL = script
        process.environment = ["SHOJI_THREAD_ID": threadId.uuidString, "SHOJI_SOCKET": socketPath]
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output

        let started = ContinuousClock.now
        try process.run()
        input.fileHandleForWriting.write(Data(stdin.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        let duration = ContinuousClock.now - started
        return (process.terminationStatus, output.fileHandleForReading.readDataToEndOfFile(), duration)
    }
}
