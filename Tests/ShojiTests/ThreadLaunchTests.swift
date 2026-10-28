import Foundation
import Testing
@testable import Shoji

struct ThreadLaunchTests {
    private let context = LaunchContext(
        shell: "/bin/zsh",
        socketPath: "/tmp/shoji.sock",
        hookScript: "/Apps/Shoji Dev.app/shoji-hook",
        environment: ["PATH": "/usr/bin", "HOME": "/Users/me", "DYLD_INSERT_LIBRARIES": "x", "CLAUDECODE": "1"]
    )

    private func thread(_ command: [String], kind: ShojiThread.Kind = .claude, resumeId: String? = nil) -> ShojiThread {
        ShojiThread(group: .agent, kind: kind, title: "t", folder: "~/code", command: command, resumeId: resumeId)
    }

    @Test func claudeGetsHooksRightAfterTheExecutableAndResumes() throws {
        let launch = thread(["claude", "--model", "opus"], resumeId: "abc").launch(in: context)
        #expect(launch.executable == "/bin/zsh")
        #expect(Array(launch.arguments.prefix(3)) == ["-l", "-i", "-c"])

        let script = try #require(launch.arguments.last)
        let hooks = ClaudeHooks.settingsJSON(hookCommand: "'/Apps/Shoji Dev.app/shoji-hook'")
        #expect(script == "exec claude --settings \(hooks.shellQuoted) --resume abc --model opus")
        #expect(hooks.contains(#""command":"'/Apps/Shoji Dev.app/shoji-hook'""#))
    }

    @Test func explicitSessionFlagsWinOverStoredResumeId() throws {
        let script = try #require(thread(["claude", "-r"], resumeId: "abc").launch(in: context).arguments.last)
        #expect(!script.contains("--resume abc"))
    }

    @Test func otherCommandsRunUntouched() {
        #expect(thread(["pnpm", "dev"], kind: .command).launch(in: context).arguments.last == "exec pnpm dev")
        #expect(thread([], kind: .command).launch(in: context).arguments == ["-l"])
    }

    @Test func environmentCarriesThreadIdentityAndDropsHostNoise() {
        let item = thread(["claude"])
        let launch = item.launch(in: context)
        #expect(launch.environment["SHOJI_THREAD_ID"] == item.id.uuidString)
        #expect(launch.environment["SHOJI_SOCKET"] == "/tmp/shoji.sock")
        #expect(launch.environment["TERM"] == "xterm-256color")
        #expect(launch.environment["PATH"] == "/usr/bin")
        #expect(launch.environment["DYLD_INSERT_LIBRARIES"] == nil)
        #expect(launch.environment["CLAUDECODE"] == nil)
        #expect(launch.directory == "\(NSHomeDirectory())/code")
    }

    @Test func shellQuoting() {
        #expect("plain-word_1.2/x".shellQuoted == "plain-word_1.2/x")
        #expect("".shellQuoted == "''")
        #expect("it's here".shellQuoted == #"'it'\''s here'"#)
    }
}
