import Foundation

/// Hook settings passed to each Claude Code launch with `--settings`, so `~/.claude` is never touched.
enum ClaudeHooks {
    static let events = ["UserPromptSubmit", "PostToolUse", "Notification", "Stop"]

    static func settingsJSON(hookCommand: String) -> String {
        let group = [MatcherGroup(hooks: [Handler(command: hookCommand)])]
        let settings = ["hooks": Dictionary(uniqueKeysWithValues: events.map { ($0, group) })]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(settings) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private struct MatcherGroup: Encodable {
        let hooks: [Handler]
    }

    private struct Handler: Encodable {
        var type = "command"
        let command: String
        var timeout = 5
    }
}
