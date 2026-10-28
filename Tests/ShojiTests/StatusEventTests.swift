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

    @Test func codexHooksMapToSignals() {
        #expect(event(#"{"hook_event_name":"UserPromptSubmit","session_id":"c1","turn_id":"t1","model":"gpt-5"}"#)?.signal == .working(sessionId: "c1"))
        #expect(event(#"{"hook_event_name":"PermissionRequest","session_id":"c1","tool_name":"Bash","tool_input":{"command":"uv run pytest"}}"#)?.signal
            == .needsYou(message: "Allow Bash: uv run pytest"))
        #expect(event(#"{"hook_event_name":"PermissionRequest","session_id":"c1","tool_name":"apply_patch","tool_input":{"patch":["a"]}}"#)?.signal
            == .needsYou(message: "Allow apply_patch"))
        #expect(event(#"{"hook_event_name":"PermissionRequest","session_id":"c1","tool_name":"Bash","tool_input":{"command":["ls","-la"]}}"#)?.signal
            == .needsYou(message: "Allow Bash"))
        #expect(event(#"{"hook_event_name":"Stop","session_id":"c1","stop_hook_active":false}"#)?.signal == .finished)
        #expect(event(#"{"hook_event_name":"Interrupt","session_id":"c1"}"#)?.signal == .finished)
    }

    @Test func malformedMessagesAreDropped() {
        #expect(StatusEvent(hookMessage: Data(#"{"hook_event_name":"Stop"}"#.utf8)) == nil)
        #expect(StatusEvent(hookMessage: Data("not-a-uuid\n{\"hook_event_name\":\"Stop\"}".utf8)) == nil)
        #expect(event("{broken") == nil)
    }
}
