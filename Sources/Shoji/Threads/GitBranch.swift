import Foundation

/// The branch checked out in a folder's repository, read from `.git/HEAD` without running git.
enum GitBranch {
    /// Nil outside a repository; a detached HEAD gives its short commit.
    static func of(_ folder: String) -> String? {
        var path = (folder as NSString).expandingTildeInPath
        while true {
            let dotGit = (path as NSString).appendingPathComponent(".git")
            var isFolder: ObjCBool = false
            if FileManager.default.fileExists(atPath: dotGit, isDirectory: &isFolder) {
                return head(in: isFolder.boolValue ? dotGit : linkedFolder(dotGit))
            }
            let parent = (path as NSString).deletingLastPathComponent
            guard !parent.isEmpty, parent != path else { return nil }
            path = parent
        }
    }

    /// Worktrees and submodules have a `.git` file: `gitdir: <path>`, relative to its folder or absolute.
    private static func linkedFolder(_ file: String) -> String? {
        guard let text = try? String(contentsOfFile: file, encoding: .utf8),
              let line = text.split(whereSeparator: \.isNewline).first, line.hasPrefix("gitdir: ")
        else { return nil }
        let target = String(line.dropFirst("gitdir: ".count))
        return target.hasPrefix("/") ? target : ((file as NSString).deletingLastPathComponent as NSString).appendingPathComponent(target)
    }

    private static func head(in gitFolder: String?) -> String? {
        guard let gitFolder,
              let head = try? String(contentsOfFile: (gitFolder as NSString).appendingPathComponent("HEAD"), encoding: .utf8)
        else { return nil }
        let ref = head.trimmingCharacters(in: .whitespacesAndNewlines)
        return ref.hasPrefix("ref: refs/heads/") ? String(ref.dropFirst("ref: refs/heads/".count)) : String(ref.prefix(7))
    }
}
