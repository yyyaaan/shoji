import Foundation
import Testing
@testable import Shoji

struct StatusEventTests {
    private let threadId = UUID()

    private func event(_ json: String) -> StatusEvent? {
        StatusEvent(hookMessage: Data("\(threadId.uuidString)\n\(json)".utf8))
    }

    @Test func claudeHooksMapToSignals() {
        #expect(event(#"{"hook_event_name":"UserPromptSubmit","session_id":"s1"}"#)?.signal == .working(sessionId: "s1"))
        #expect(event(#"{"hook_event_name":"PostToolUse","session_id":"s1","tool_name":"Bash"}"#)?.signal == .working(sessionId: "s1"))
        #expect(event(#"{"hook_event_name":"Stop","session_id":"s1"}"#)?.signal == .finished)
        #expect(event(#"{"hook_event_name":"Notification","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}"#)?.signal
            == .needsYou(message: "Claude needs your permission to use Bash"))
        #expect(event(#"{"hook_event_name":"Notification","message":"Claude is waiting for your input","notification_type":"idle_prompt"}"#) == nil)
        #expect(event(#"{"hook_event_name":"Notification","message":"Approve?"}"#)?.signal == .needsYou(message: "Approve?"))
        #expect(event(#"{"hook_event_name":"SessionStart","session_id":"s1"}"#) == nil)
    }

    @Test func codexNotifyMarksTurnFinished() {
        #expect(event(#"{"type":"agent-turn-complete","thread-id":"t1","last-assistant-message":"done"}"#)?.signal == .finished)
    }

    @Test func malformedMessagesAreDropped() {
        #expect(StatusEvent(hookMessage: Data(#"{"hook_event_name":"Stop"}"#.utf8)) == nil)
        #expect(StatusEvent(hookMessage: Data("not-a-uuid\n{\"hook_event_name\":\"Stop\"}".utf8)) == nil)
        #expect(event("{broken") == nil)
    }
}
