import Foundation
import Testing
@testable import Shoji

struct ThreadLaunchTests {
    private let context = LaunchContext(
        shell: "/bin/zsh",
        socketPath: "/tmp/shoji.sock",
        hookScript: "/Apps/Shoji Dev.app/shoji-hook",
        zsh: LaunchContext.Zsh(dotDir: "/support/zsh", script: "/Apps/Shoji Dev.app/shoji.zsh"),
        environment: [
            "PATH": "/usr/bin", "HOME": "/Users/me", "ZDOTDIR": "/Users/me/.config/zsh",
            "DYLD_INSERT_LIBRARIES": "x", "CLAUDECODE": "1", "SHOJI_THREAD_ID": "outer",
        ]
    )

    @Test func everyThreadIsTheLoginShellWithZshIntegration() {
        let thread = ShojiThread(folder: "/tmp")
        let launch = thread.launch(in: context)
        #expect(launch.executable == "/bin/zsh")
        #expect(launch.arguments == ["-l", "-i"])
        #expect(launch.directory == "/tmp")
        #expect(launch.environment["ZDOTDIR"] == "/support/zsh")
        #expect(launch.environment["SHOJI_USER_ZDOTDIR"] == "/Users/me/.config/zsh")
        #expect(launch.environment["SHOJI_ZSH"] == "/Apps/Shoji Dev.app/shoji.zsh")
        let hooks = ClaudeHooks.settingsJSON(hookCommand: "'/Apps/Shoji Dev.app/shoji-hook'")
        #expect(launch.environment["SHOJI_CLAUDE_SETTINGS"] == hooks)
        #expect(hooks.contains(#""command":"'/Apps/Shoji Dev.app/shoji-hook'""#))
        #expect(launch.environment["SHOJI_CODEX_HOOKS"] == CodexHooks.configOverride(hookCommand: "'/Apps/Shoji Dev.app/shoji-hook'"))
        #expect(launch.environment["SHOJI_RESUME"] == nil)
        #expect(launch.environment["SHOJI_PREFILL"] == nil)
    }

    @Test func relaunchResumesTheAgentOrPrefillsTheLastCommand() {
        let claude = ShojiThread(resumeId: "abc", command: "claude --model opus").launch(in: context)
        #expect(claude.environment["SHOJI_RESUME"] == "claude --resume abc")
        #expect(claude.environment["SHOJI_PREFILL"] == nil)

        let codex = ShojiThread(resumeId: "019a-c0de", command: "codex --full-auto").launch(in: context)
        #expect(codex.environment["SHOJI_RESUME"] == "codex resume 019a-c0de")
        let alias = ShojiThread(resumeId: "abc", command: "cc").launch(in: context)
        #expect(alias.environment["SHOJI_RESUME"] == "claude --resume abc")

        let task = ShojiThread(command: "pnpm dev").launch(in: context)
        #expect(task.environment["SHOJI_PREFILL"] == "pnpm dev")
    }

    @Test func otherShellsRunWithoutIntegration() {
        var bash = context
        bash.shell = "/bin/bash"
        bash.zsh = nil
        let launch = ShojiThread(resumeId: "abc").launch(in: bash)
        #expect(launch.executable == "/bin/bash")
        #expect(launch.environment["ZDOTDIR"] == "/Users/me/.config/zsh")
        #expect(launch.environment["SHOJI_RESUME"] == nil)
    }

    @Test func codexHooksAreOneInlineTable() {
        let override = CodexHooks.configOverride(hookCommand: #"'/Apps/My "Dev" \ Shoji.app/shoji-hook'"#)
        let group = #"[{hooks=[{type="command",command="'/Apps/My \"Dev\" \\ Shoji.app/shoji-hook'",timeout=3}]}]"#
        #expect(override == "hooks={UserPromptSubmit=\(group),PostToolUse=\(group),PermissionRequest=\(group),Stop=\(group),Interrupt=\(group)}")
    }

    /// Runs the bundled zsh integration with stand-in `claude` and `codex` executables that print their arguments.
    @Test func zshIntegrationHandsAgentsTheirHooks() throws {
        let bin = FileManager.default.temporaryDirectory.appending(path: "shoji-bin-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bin) }
        for name in ["claude", "codex"] {
            let url = bin.appending(path: name)
            try Data("#!/bin/sh\nprintf '%s\\n' \"$@\"\n".utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        let script = try #require(Bundle.main.path(forResource: "shoji", ofType: "zsh"))
        let codexHooks = CodexHooks.configOverride(hookCommand: "'/Apps/Shoji Dev.app/shoji-hook'")

        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = ["-f", "-c", #"source "$SHOJI_ZSH"; _shoji_init >/dev/null; codex resume abc; claude -r"#]
        process.environment = [
            "PATH": bin.path + ":/usr/bin:/bin", "SHOJI_ZSH": script,
            "SHOJI_CODEX_HOOKS": codexHooks, "SHOJI_CLAUDE_SETTINGS": #"{"hooks":{}}"#,
        ]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let lines = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).split(separator: "\n").map(String.init)
        #expect(lines == ["-c", codexHooks, "resume", "abc", "--settings", #"{"hooks":{}}"#, "-r"])
    }

    @Test func missingFolderStartsAtHome() {
        #expect(ShojiThread(folder: "/no/such/folder").launch(in: context).directory == NSHomeDirectory())
        #expect(ShojiThread(folder: "~").launch(in: context).directory == NSHomeDirectory())
    }

    @Test func environmentCarriesThreadIdentityAndDropsHostNoise() {
        let thread = ShojiThread()
        let launch = thread.launch(in: context)
        #expect(launch.environment["SHOJI_THREAD_ID"] == thread.id.uuidString)
        #expect(launch.environment["SHOJI_SOCKET"] == "/tmp/shoji.sock")
        #expect(launch.environment["TERM"] == "xterm-256color")
        #expect(launch.environment["PATH"] == "/usr/bin")
        #expect(launch.environment["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(launch.environment["CLAUDECODE"] == nil)
    }

    @Test func shellReportsParse() {
        #expect(TerminalEvent(shojiReport: "ShojiEvent=cmd;git commit -m \"a;b\"") == .commandStarted("git commit -m \"a;b\""))
        #expect(TerminalEvent(shojiReport: "ShojiEvent=done;130") == .commandFinished(130))
        #expect(TerminalEvent(shojiReport: "ShojiEvent=cwd;/tmp/a b") == .directory("/tmp/a b"))
        #expect(TerminalEvent(shojiReport: "ShojiEvent=cwd;") == nil)
        #expect(TerminalEvent(shojiReport: "ShojiEvent=done;x") == nil)
        #expect(TerminalEvent(shojiReport: "SetUserVar=foo=YmFy") == nil)
    }

    @Test func agentsAreRecognisedByTheirExecutable() {
        #expect(Agent(commandLine: "/opt/homebrew/bin/claude -c") == .claude)
        #expect(Agent(commandLine: "  codex resume") == .codex)
        #expect(Agent(commandLine: "pnpm dev") == nil)
        #expect(Agent(commandLine: "") == nil)
    }

    @Test func shellQuoting() {
        #expect("plain-word_1.2/x".shellQuoted == "plain-word_1.2/x")
        #expect("".shellQuoted == "''")
        #expect("it's here".shellQuoted == #"'it'\''s here'"#)
    }
}
