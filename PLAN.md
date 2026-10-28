# PLAN.md — Shoji

## Status

- **Current milestone:** M0 — repo and build
- **Last session:** terminal engine switched from libghostty to SwiftTerm (decision below); Ghostty pin file and Zig ignores removed.
- **Next up:** `project.yml` with the SwiftTerm package pinned, empty window that builds and launches. SwiftTerm latest is v1.99.1 (2026-10-21, "preview before 2.0"): pin it exactly, and treat the 2.0 move as its own bump.
- **Blockers:** none

_Agents: update this section at the end of every session (what changed, what's next)._

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
- **Link clicks:** subclass overrides of SwiftTerm's delegate defaults are not called;
  use a proxy `TerminalViewDelegate` that forwards every call.
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
- Shelf of glass cards across the top, two clusters: **Agents | Tasks**, divider between.
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
  "layout": { "mode": "twoColumns", "openThreadIds": ["6F1C…", "9A2E…"] }
}
```

Runtime-only (not persisted): status, last activity, unread count, terminal view.

### Status states and sources

| State | Agents | Tasks |
|---|---|---|
| Working | prompt submitted / tool running (hook) | — |
| Needs you | Claude `Notification` hook; bell from the terminal as a hint | — |
| Done | Claude `Stop` hook; Codex `notify` turn complete | — |
| Idle | Done and already seen, or fresh session at prompt | — |
| Running | — | process alive |
| Exited(code) | process exited | process exited (non-zero = error) |

Resume ids: Claude from the `SessionStart` hook payload; Codex — to confirm (Open questions).

## Milestones

### M0 — Repo and build
- [ ] `project.yml` (XcodeGen), macOS 26 target, App Sandbox off, Debug/Release
- [ ] SwiftTerm added as a Swift package in `project.yml`, pinned to an exact version
- [x] `.gitignore` (build output, generated project)
- [ ] Empty window builds and launches via `xcodebuild`
- [x] `docs/design/` HTML mockups of Option B and Hub view

### M1 — Spike (prove the risky parts)
- [ ] `TerminalBackend` protocol + SwiftTerm view (Metal renderer) in SwiftUI;
      login shell runs, typing works
- [ ] Two terminals side by side inside glass-framed cards (solid terminal background)
- [ ] Each launches `claude -r` in a hard-coded folder
- [ ] Window resize and focus switching between panes are smooth
- [ ] Hide/show one pane without redraw glitches (stable size while hidden)
- [ ] One Claude `Notification` hook → `shoji-hook` → socket → card turns orange
- [ ] Terminal checklist with Claude Code (re-run after every SwiftTerm bump):
  - [ ] Shift+Enter inserts a newline; Option+Enter works with Option as Meta
  - [ ] Long reply + scrolling up: no drift, scroll wheel scrolls (no stray keystrokes)
  - [ ] Heavy output (`docker compose up` logs) stays responsive
  - [ ] Same PATH, env and MCP servers as in a normal terminal
  - [ ] Cmd+click opens URLs and file paths correctly
  - [ ] IME input, copy/paste, selection, emoji and wide characters render correctly
- **Exit:** all of the above work in a single debug build. Record findings in Gotchas.

### M2 — Threads and shelf
- [ ] `Thread`, `ThreadStore`, `threads.json` with schemaVersion + mock data
- [ ] New thread sheet: group, folder picker, command preset (claude / claude -r /
      codex / custom)
- [ ] Card shelf with Agents | Tasks clusters, selection opens in a pane
- [ ] Rename inline, context menu, drag to reorder, move between groups
- [ ] Layouts: 1 / 2 / 2×2; Maximize; Minimize to shelf
- [ ] Restore layout and open threads on relaunch

### M3 — Status and resume
- [ ] `shoji-hook` client (fast, silent when Shoji is down)
- [ ] Per-launch hook injection for Claude Code (no global config edits)
- [ ] Capture Claude resume id from `SessionStart`; relaunch with `--resume`
- [ ] Codex `notify` wiring + resume
- [ ] Terminal delegate callbacks → StatusEvent: title, bell, process exit
- [ ] Full state machine from the table above, elapsed timers, unread counts
- [ ] Native macOS notification for needs-you when the app is in the background

### M4 — Hub view
- [ ] Threads | Hub switch
- [ ] Agent big cards sorted by attention, last 3 lines preview, actions
- [ ] Task cards: last log line, Restart (SIGINT, wait, relaunch) / Stop / Open
- [ ] Header totals pills
- [ ] "Allow once" with guardrails (see Open questions)
- [ ] Open folder in Zed

### M5 — Hachi and polish
- [ ] App icon: Hachi sitting behind a shoji panel
- [ ] Hachi on needs-you cards; subtle appear animation
- [ ] Shortcuts: ⌘1–9 jump, ⌘J next needs-you, ⌘N new thread, ⌘K quick jump
- [ ] Settings: default folders, command presets, notifications on/off,
      terminal font, theme, scrollback, Option as Meta
- [ ] Devcontainer command presets
- [ ] Developer ID signing + notarization
- [ ] Third-party notices in the app bundle (SwiftTerm MIT license text)

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

## Decisions

- **Terminal engine: SwiftTerm** (chosen over libghostty). Pure Swift package, no Zig
  build, stable versioned API, Metal renderer, Kitty keyboard and graphics protocols,
  runs on iOS too, MIT license (compatible with Shoji's Apache 2.0). Accepted costs:
  less battle-tested than Ghostty, themes/fonts are ours to build, Claude Code needs the
  setup rules in AGENTS.md. Fallback: libghostty behind the same `TerminalBackend`.
