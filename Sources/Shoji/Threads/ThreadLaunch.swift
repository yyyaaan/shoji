import Foundation

/// Machine-wide inputs for launching any thread.
struct LaunchContext: Sendable {
    var shell: String
    var socketPath: String
    var hookScript: String?
    var environment: [String: String]

    static func current(socketPath: String) -> LaunchContext {
        let environment = ProcessInfo.processInfo.environment
        let accountShell = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_shell) }
        return LaunchContext(
            shell: environment["SHELL"] ?? accountShell ?? "/bin/zsh",
            socketPath: socketPath,
            hookScript: Bundle.main.path(forResource: "shoji-hook", ofType: nil),
            environment: environment
        )
    }
}

extension ShojiThread {
    /// Runs through the user's login shell (interactive too, so `.zshrc` PATH setup like nvm applies).
    func launch(in context: LaunchContext) -> TerminalLaunch {
        let argv = launchArguments(hookScript: context.hookScript)
        return TerminalLaunch(
            executable: context.shell,
            arguments: argv.isEmpty ? ["-l"] : ["-l", "-i", "-c", "exec " + argv.map(\.shellQuoted).joined(separator: " ")],
            environment: launchEnvironment(context),
            directory: (folder as NSString).expandingTildeInPath
        )
    }

    private static let claudeSessionFlags: Set = ["-r", "--resume", "-c", "--continue", "--session-id"]
    /// Set by Xcode, launchd or a parent Claude Code; children shouldn't inherit them.
    private static let strippedVariablePrefixes = ["DYLD_", "__XCODE", "__CF", "XPC_", "CLAUDECODE", "CLAUDE_CODE_"]

    private func launchArguments(hookScript: String?) -> [String] {
        guard kind == .claude, let executable = command.first else { return command }
        var flags: [String] = []
        if let hookScript {
            flags += ["--settings", ClaudeHooks.settingsJSON(hookCommand: hookScript.shellQuoted)]
        }
        if let resumeId, !command.contains(where: Self.claudeSessionFlags.contains) {
            flags += ["--resume", resumeId]
        }
        return [executable] + flags + command.dropFirst()
    }

    private func launchEnvironment(_ context: LaunchContext) -> [String: String] {
        var environment = context.environment.filter { name, _ in
            !Self.strippedVariablePrefixes.contains { name.hasPrefix($0) }
        }
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["TERM_PROGRAM"] = "Shoji"
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        environment["SHOJI_THREAD_ID"] = id.uuidString
        environment["SHOJI_SOCKET"] = context.socketPath
        return environment
    }
}

extension String {
    /// POSIX shell single-quoting, skipped for plain words.
    var shellQuoted: String {
        let plain = !isEmpty && allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-_./=:@%+,".contains($0)) }
        return plain ? self : "'" + replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
