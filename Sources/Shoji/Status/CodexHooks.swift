import Foundation

/// Hooks passed to each Codex launch as one `-c` config override, so `~/.codex` is never touched.
/// Codex runs a hook only after the user trusts its exact definition in `/hooks`; keep it stable.
enum CodexHooks {
    static let events = ["UserPromptSubmit", "PostToolUse", "PermissionRequest", "Stop", "Interrupt"]

    /// An inline TOML table: `hooks={Stop=[{hooks=[{type="command",command="…",timeout=3}]}],…}`.
    /// 3 s is the most Codex allows for Interrupt; the hook returns at once anyway.
    static func configOverride(hookCommand: String) -> String {
        let command = hookCommand.replacingOccurrences(of: #"\"#, with: #"\\"#).replacingOccurrences(of: #"""#, with: #"\""#)
        let group = #"[{hooks=[{type="command",command="\#(command)",timeout=3}]}]"#
        return "hooks={" + events.map { "\($0)=\(group)" }.joined(separator: ",") + "}"
    }
}
