import Foundation

/// Hook settings for an agent in a container (a devcontainer, `docker exec` from a thread), where the socket is out of reach.
/// The hook finds the terminal its agent draws in (hooks run without one) and writes its input there as
/// `OSC 1337 ; ShojiEvent=hook;<agent>;<base64>`, which reaches the thread through `docker exec`.
/// It needs Linux's /proc, so the same settings do nothing on the Mac.
enum ContainerHooks {
    static func command(for agent: Agent) -> String {
        [
            "p=$PPID; t=",
            #"while [ "${p:-0}" -gt 0 ]; do t=$(readlink /proc/$p/fd/1 2>/dev/null); case "$t" in /dev/pts/*) break;; esac; t=; p=$(sed 's/.*) //' /proc/$p/stat 2>/dev/null | cut -d' ' -f2); done"#,
            // Large payloads (a long reply, a big tool result) are skipped rather than flooding the terminal.
            #"b=$(base64 | tr -d '\n'); [ -n "$t" ] && [ ${#b} -le 131072 ] && printf '\033]1337;ShojiEvent=hook;\#(agent.rawValue);%s\007' "$b" >"$t" 2>/dev/null; exit 0"#,
        ].joined(separator: "; ")
    }

    /// For the container's `~/.claude/settings.json` or the project's `.claude/settings.local.json`.
    static var claudeSettings: String { ClaudeHooks.settingsJSON(hookCommand: command(for: .claude)) }

    /// A line for the container's `~/.codex/config.toml`, above its first table.
    static var codexConfig: String { CodexHooks.configOverride(hookCommand: command(for: .codex)) }
}
