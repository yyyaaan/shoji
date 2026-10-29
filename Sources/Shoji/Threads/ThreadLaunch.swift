import Foundation

/// Machine-wide inputs for launching any thread.
struct LaunchContext: Sendable {
    /// Shoji's zsh integration: `dotDir` holds the `.zshenv` that restores the user's ZDOTDIR and sources `script`.
    struct Zsh: Sendable {
        var dotDir: String
        var script: String
    }

    var shell: String
    var socketPath: String
    var hookScript: String?
    /// Nil for shells other than zsh, which run without integration.
    var zsh: Zsh?
    var environment: [String: String]

    static func current(socketPath: String, supportFolder: URL) -> LaunchContext {
        let environment = ProcessInfo.processInfo.environment
        let accountShell = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_shell) }
        let shell = environment["SHELL"] ?? accountShell ?? "/bin/zsh"
        return LaunchContext(
            shell: shell,
            socketPath: socketPath,
            hookScript: Bundle.main.path(forResource: "shoji-hook", ofType: nil),
            zsh: (shell as NSString).lastPathComponent == "zsh" ? installZsh(in: supportFolder) : nil,
            environment: environment
        )
    }

    /// Copies the bundled loader to `<support>/zsh/.zshenv` (a dotfile doesn't survive the resource copy).
    private static func installZsh(in supportFolder: URL) -> Zsh? {
        guard let loader = Bundle.main.url(forResource: "zshenv", withExtension: nil),
              let script = Bundle.main.path(forResource: "shoji", ofType: "zsh"),
              let contents = try? Data(contentsOf: loader)
        else { return nil }
        let dotDir = supportFolder.appending(path: "zsh", directoryHint: .isDirectory)
        let target = dotDir.appending(path: ".zshenv")
        if (try? Data(contentsOf: target)) != contents {
            try? FileManager.default.createDirectory(at: dotDir, withIntermediateDirectories: true)
            guard (try? contents.write(to: target, options: .atomic)) != nil else { return nil }
        }
        return Zsh(dotDir: dotDir.path(percentEncoded: false), script: script)
    }
}

extension ShojiThread {
    /// The user's login shell (interactive, so `.zshrc` PATH setup like nvm applies) in the thread's folder.
    func launch(in context: LaunchContext) -> TerminalLaunch {
        TerminalLaunch(
            executable: context.shell,
            arguments: ["-l", "-i"],
            environment: launchEnvironment(context),
            directory: startDirectory
        )
    }

    /// Set by Xcode, launchd, a parent Claude Code or a Shoji that launched this one; children shouldn't inherit them.
    private static let strippedVariablePrefixes = ["DYLD_", "__XCODE", "__CF", "XPC_", "CLAUDECODE", "CLAUDE_CODE_", "SHOJI_"]

    /// The saved folder, or home when it no longer exists.
    private var startDirectory: String {
        let path = (folder as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue ? path : NSHomeDirectory()
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
        guard let zsh = context.zsh else { return environment }

        if let userDotDir = environment["ZDOTDIR"] {
            environment["SHOJI_USER_ZDOTDIR"] = userDotDir
        }
        environment["ZDOTDIR"] = zsh.dotDir
        environment["SHOJI_ZSH"] = zsh.script
        if let hookScript = context.hookScript {
            environment["SHOJI_CLAUDE_SETTINGS"] = ClaudeHooks.settingsJSON(hookCommand: hookScript.shellQuoted)
            environment["SHOJI_CODEX_HOOKS"] = CodexHooks.configOverride(hookCommand: hookScript.shellQuoted)
        }
        if let resumeId {
            // The agent's own resume; files from before `resumeAgent` fall back to the saved command, then Claude.
            environment["SHOJI_RESUME"] = (resumeAgent ?? Agent(commandLine: command ?? "")) == .codex
                ? "codex resume \(resumeId.shellQuoted)"
                : "claude --resume \(resumeId.shellQuoted)"
        } else if let command {
            environment["SHOJI_PREFILL"] = command
        }
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
