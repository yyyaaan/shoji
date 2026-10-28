# PLAN.md — Shoji

## Status

- **Last session (initial-sprint):** spike to a usable v0 (SwiftTerm panes, Claude hooks → status cards, layouts with drag splits, CI + release workflow, shortcuts with a ⌘/ sheet, app-wide zoom), shelf without group titles, then the Hachi integration from the design handoff (needs-you portrait, Icon Composer app icon; checked at 75/100/200%, counts 1/999, all statuses, every icon appearance, 16 pt). Handoffs are now local-only (gitignored). 25 Swift Testing tests pass.
- **Next up:** top of **Tasks › Now**.
- **Blockers:** none

_Agents: update this section at the end of every session (what changed, what's next), tick or move tasks, and add new wishes to the right bucket._

## Gotchas

- **SwiftTerm's default scrollback is 500 lines.** Long Claude Code replies overflow it
  and the view drifts while scrolled up. Set a large scrollback.
- **Launch environment.** A GUI app doesn't inherit the user's shell PATH or variables;
  a SwiftTerm-hosted Claude Code has been reported missing MCP servers that worked in a
  normal terminal. Start every thread via the login shell.
- **Shift+Enter is not guaranteed.** SwiftTerm isn't on Claude Code's "works without
  setup" list. If it submits instead of inserting a newline, send ESC + CR for Shift+Enter.
- **Option key.** Option shortcuts (e.g. Option+Enter) need "Option as Meta" enabled.
- **Scroll wheel on the alternate screen** can be turned into arrow keys when mouse
  reporting is off; Claude Code then reads them as keystrokes. Test scrolling.
- **SwiftTerm delegate defaults can't be overridden** (`bell`, `requestOpenLink` come from a protocol extension). `DelegateRelay` sits in front as `terminalDelegate` and forwards every call. It must not also be the `processDelegate`, or the shared-signature calls loop. Details in `docs/swiftterm.md`.
- **SwiftTerm `keyDown` / `becomeFirstResponder` aren't `open`.** Shift+Return is an `NSEvent` local monitor that stands down when the app enabled the Kitty keyboard protocol; focus is observed by overriding `hasFocus`.
- **Metal must be turned on after the view joins a window** (`viewDidMoveToWindow`).
- **SwiftTerm's build plugin** needs `-skipPackagePluginValidation` on the command line (Trust & Enable in Xcode).
- **Inside a `GlassEffectContainer`, overlays added after `.glassEffect` are drawn under the glass.** Put borders and badges before the glass modifier.
- **Login shell must be interactive too** (`$SHELL -l -i -c 'exec …'`), or PATH set in `.zshrc` (nvm, where `codex` lives here) is missing.
- **Darwin `accept()` inherits `O_NONBLOCK`** from the listener; `HookServer` clears it before reading.
- **Claude `Notification` with `idle_prompt`** fires about 60 s after a finished turn; it's ignored so Done doesn't flip to Needs you.
- **No hook fires between approving a permission prompt and the tool finishing.** Typing into a needs-you thread is taken as the answer (→ Working).
- **Resume ids come from `UserPromptSubmit` / `PostToolUse`**, not `SessionStart`: SessionStart also fires for sessions that never got a message, and those can't be resumed. (`claude --session-id <uuid>` exists if we ever need to pick the id up front.)
- **UI automation:** System Events keystrokes go to the user's frontmost app, not Shoji (macOS won't let a script steal focus). Use `AXPress` on buttons and `screencapture -l <windowid>`.
- **No terminal-native notifications from Claude Code** (it only sends them in Ghostty,
  Kitty and iTerm2). "Needs you" relies entirely on hooks → socket.
- **Reference app:** TermQ (open source, macOS) is built on SwiftTerm and runs Claude
  Code; its fixes are a good source of lessons. It uses tmux, which Shoji does not.
- **App Sandbox must be off** (Shoji spawns shells and CLIs). Distribute outside the
  App Store, signed with Developer ID and notarized.
- **Hidden or minimized terminals:** keep their size stable. Resizing a terminal to
  zero makes TUIs like Claude Code redraw badly when restored.
- **Glass behind terminal text hurts readability.** Solid terminal backgrounds only.
- **Devcontainers can't reach a host Unix socket.** Threads that run CLIs inside a
  container need another path (see Open questions).
- **Hooks run on every agent event.** A slow or failing hook makes the CLI feel broken;
  `shoji-hook` must be fast and fail silently.
- **Agents editing `.pbxproj` break projects.** Use XcodeGen.
- **No paid Apple Developer account yet:** builds are ad-hoc signed and not notarized. A downloaded DMG is quarantined; first launch needs Privacy & Security › Open Anyway (or `xattr -dr com.apple.quarantine`). Locally built apps aren't quarantined.
- **Ad-hoc signatures change every build**, so macOS privacy grants (TCC, e.g. Files & Folders prompts that child CLIs trigger in Shoji's name) reset after each update.
- **Icon Composer documents:** XcodeGen adds `AppIcon.icon` as one `wrapper.icon` file, and actool compiles it to `AppIcon.icns` + `Assets.car` with `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Check renders with `ictool <file>.icon --export-image --platform macOS --rendition Default|Dark|ClearLight|TintedDark …`; in `icon.json`, `groups` and `layers` list front to back.
- **Visual checks of SwiftUI views without touching the live app:** render them with `ImageRenderer` from a throwaway test (the test host has the asset catalog). Glass renders flat there, so confirm glass ordering in the running app.
- **CI runs on the `xcode-27` runner label** (public preview) to match local Xcode 27.1; `macos-26` only has Xcode 26. Move to the GA label once it exists.

## Vision

A calm, beautiful command center for the terminals the user already runs all day.
Claude Code and Codex stay plain CLIs on subscription plans; Shoji only organizes
them, shows what each needs, and lets the user jump there instantly.

Not in scope: editor, git diff, file browser (Zed / VS Code), any model API calls.

## Design

Design canvas: https://claude.ai/artifact/2VNVkmAvTghL9S4cS9uNSZ
Chosen: **B · Card shelf + split** and **Hub view**, exported as standalone HTML to
`docs/design/threads-shelf.html` and `docs/design/hub.html` (the canvas link above is
private to Yan's account; agents can't open it, so the HTML files are what they read).

**Threads screen (Option B)**
- Shelf of glass cards across the top: agents, a divider, then tasks. No group titles (user's call); scrolls sideways when cards overflow.
- Agent card: status icon, CLI kind (CLAUDE / CODEX), name, folder or one-line status,
  elapsed time. Task card: status, name, command, port.
- Needs-you card: orange border + glow, count badge, Hachi.
- Card context menu: Rename, Move left/right, Move to other group, Resume in new pane,
  Open folder in Zed, Close thread.
- Drag to reorder within a group.
- Layout switcher: 1 pane / 2 columns / 2×2 grid. Pane header: name, folder,
  Maximize, Minimize to shelf; tasks also get Restart.

**Hub view**
- Header: Threads | Hub switch, totals pills (needs you / working / tasks down).
- Agents section, sorted by attention (needs you → working → done → idle):
  big card with name, kind, folder + git branch, status pill, one-line "what it's
  doing / waiting on", last 3 terminal lines, actions (Open thread, Allow once,
  Maximize, Open folder in Zed, Rename), elapsed.
- Tasks section: name, command + folder, port, last log line, Restart / Stop / Open.

## Architecture

```
            ┌────────────────────── Shoji.app (SwiftUI) ──────────────────────┐
            │  UI: Shelf · Panes · Hub · Hachi                                 │
            │        ▲ observes                                                │
            │  ThreadStore (@MainActor @Observable) ◄── StatusEvent ──┐        │
            │        │ persists                                       │        │
            │  threads.json (~/Library/Application Support/Shoji)     │        │
            │                                                         │        │
            │  Terminal/SwiftTerm ── delegate callbacks ──────────────┤        │
            │     (title, bell, process exit)                         │        │
            │  Status/SocketListener ◄── shoji-hook ◄── CLI hooks ────┘        │
            └──────────────────────────────────────────────────────────────────┘
```

### Thread model (`threads.json`)

```json
{
  "schemaVersion": 1,
  "threads": [
    {
      "id": "6F1C…",
      "group": "agent",
      "kind": "claude",
      "title": "auth-refactor",
      "folder": "/Users/yan/code/gosta",
      "command": ["claude"],
      "resumeId": "abc123…",
      "order": 0
    },
    {
      "id": "9A2E…",
      "group": "task",
      "kind": "command",
      "title": "api stack",
      "folder": "/Users/yan/code/gosta",
      "command": ["docker", "compose", "up"],
      "order": 0
    }
  ],
  "layout": { "mode": "twoColumns", "openThreadIds": ["6F1C…", "9A2E…"], "columnSplit": 0.5, "rowSplit": 0.5 }
}
```

Runtime-only (not persisted): status, last activity, unread count, terminal view.

### Status states and sources

| State | Agents | Tasks |
|---|---|---|
| Working | `UserPromptSubmit` / `PostToolUse` hook; typing into a needs-you thread | — |
| Needs you | `Notification` hook (not `idle_prompt`); bell while Working | — |
| Done | `Stop` hook; Codex `notify` `agent-turn-complete` | — |
| Idle | launched, or Done and then focused | — |
| Running | — | process alive |
| Exited(code) | process exited | process exited (non-zero = error) |

Hook transport: `shoji-hook` sends one connection per event to `~/Library/Application Support/Shoji/hook.sock`: the thread id on the first line, then the CLI's JSON (stdin for Claude, argv[1] for Codex `notify`). Resume ids: Claude from `session_id` in prompt/tool hooks; Codex — to confirm (Open questions).

## Tasks

Priorities shift with the user's wishes; reorder freely. Keep items one line, small enough for one PR.

### Now
- [ ] Hands-on pass by the user: the terminal checklist below, plus pane resize / focus feel, split dragging, and shortcuts with a terminal focused
- [ ] `threads.json` (schemaVersion 1) and restore threads, layout and splits on relaunch
- [ ] New-thread sheet (group, folder, preset: claude / claude -r / codex / custom) on ⌘N; drop the hard-coded spike threads

### Next
- [ ] Relaunch Claude threads with `--resume <id>` (the id is already captured from hooks; needs `threads.json`)
- [ ] Card context menu: rename, move left / right, move to other group, resume in new pane, open folder in Zed, close thread
- [ ] Drag to reorder cards within a group
- [ ] macOS notification for needs-you while Shoji is in the background
- [ ] Codex `notify` and resume (decide the notify override first, see Open questions)

### Later
- [ ] Hub view: Threads | Hub switch, agent cards sorted by attention with the last 3 lines, task cards with Restart / Stop / Open, totals pills, open folder in Zed
- [ ] "Allow once" from the Hub, with guardrails (see Open questions)
- [ ] ⌘K quick jump
- [ ] Settings: default folders, command presets, notifications, terminal font, theme, scrollback, Option as Meta
- [ ] Devcontainer command presets
- [ ] Push the first `v*` tag to try `release.yml`
- [ ] Third-party notices in the app bundle (SwiftTerm MIT license text)
- [ ] Developer ID signing and notarization (needs a paid Apple Developer account)

### Done
- Build: XcodeGen project, SwiftTerm 1.99.1 pinned, CI on GitHub (`xcode-27` runner), release workflow and `scripts/package.sh` (universal ad-hoc DMG)
- Terminals: SwiftTerm panes (Metal) in glass cards, login-shell launch, 10k scrollback, Shift+Return fallback, hide / show without redraw glitches
- Status: `shoji-hook` → socket → `ThreadStore`, per-launch Claude hooks, terminal title / bell / exit; working / needs you / done / idle with elapsed time and needs-you count; resume id captured
- Shelf and panes: Agents | Tasks shelf, click a card to open it, 1 / 2 / 2×2 layouts, maximize / minimize, drag splits
- Keyboard and zoom: one `Shortcut` catalog for menus and the ⌘/ sheet, app-wide zoom ⌘+ / ⌘− / ⌘0
- Hachi: vector portrait on needs-you agent cards (zoom-aware, behind the count badge) and a layered Icon Composer app icon

## Terminal checklist

Run by hand with Claude Code in Shoji; re-run after every SwiftTerm bump (AGENTS invariant 1). Record findings in Gotchas.

- [ ] Shift+Enter inserts a newline; Option+Enter works with Option as Meta
- [ ] Long reply + scrolling up: no drift, scroll wheel scrolls (no stray keystrokes)
- [ ] Heavy output (`docker compose up` logs) stays responsive
- [ ] Same PATH, env and MCP servers as in a normal terminal
- [ ] Cmd+click opens URLs and file paths correctly
- [ ] IME input, copy/paste, selection, emoji and wide characters render correctly
- [ ] Window resize and focus switching between panes are smooth

## Open questions

- **Allow once:** allow from the Hub/toast for any prompt, or only for commands the
  user has approved before? Default proposal: only when the prompt text is visible
  on the card, and send exactly the shown keystroke.
- **Devcontainers:** how do hooks inside a container reach Shoji? Options: localhost
  TCP listener with a per-launch token, reached via `host.docker.internal`; or mount
  the socket into the container.
- **Codex:** does it expose a resume id and a needs-approval event we can hook, or do
  we rely on the terminal bell?
- **Performance:** how many live terminal views before it matters? Do hidden threads
  keep a live view, or keep only SwiftTerm's headless `Terminal` and reattach a view?
- **Themes:** ship a few built-in themes, or import Ghostty/iTerm2 theme files?
- **Task restart:** SIGINT then relaunch, or SIGTERM with a timeout? Per task setting?
- **Git branch on Hub cards:** read `.git/HEAD` directly vs. shelling out to `git`.
- **Codex notify:** `codex -c 'notify=["…/shoji-hook"]'` per launch replaces any `notify` program the user configured. Chain to theirs, or accept the override?
- **Stable local signing identity:** a self-signed code-signing certificate (kept as a CI secret) would keep TCC grants across updates without a paid account. Worth it before daily use, or wait for Developer ID?
- **Quitting with live agents:** quitting closes every PTY (agents get SIGHUP). Confirm before quit while something is Working / Needs you?

## Decisions

- **Bundle id `fi.yan.shoji`**, ad-hoc signed until there's a Developer ID.
- **The `.xcodeproj` is generated and not committed**; `project.yml` is the only source. Package.resolved therefore isn't committed either; SwiftTerm itself is pinned exactly.
- **Shift+Return → ESC CR** (Meta+Return, a newline in Claude Code) for every thread whose program hasn't enabled the Kitty keyboard protocol.
- **Shortcuts sheet on ⌘/** (the user suggested ⌘K): ⌘K is "clear" in every Mac terminal and is reserved for quick jump. It's a real sheet, not an overlay, so Esc closes it without reaching the focused terminal (Esc would interrupt Claude).
- **Zoom is one factor for everything**, browser style, stored in UserDefaults (`zoom`). Terminal font = 13 pt × zoom, rounded to half points.
- **Terminal engine: SwiftTerm** (chosen over libghostty). Pure Swift package, no Zig
  build, stable versioned API, Metal renderer, Kitty keyboard and graphics protocols,
  runs on iOS too, MIT license (compatible with Shoji's Apache 2.0). Accepted costs:
  less battle-tested than Ghostty, themes/fonts are ours to build, Claude Code needs the
  setup rules in AGENTS.md. Fallback: libghostty behind the same `TerminalBackend`.
