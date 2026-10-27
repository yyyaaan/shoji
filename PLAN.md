# PLAN.md — Shoji

## Status

- **Current milestone:** M0 — repo and build
- **Last session:** repo kick-off: AGENTS.md, PLAN.md, design HTML in `docs/design/`, `.gitignore`, Ghostty pinned to v1.4.0 (Zig 0.17.0) in `scripts/ghostty.version`. Toolchain needed: Xcode 27.1, Metal Toolchain, XcodeGen, Zig 0.17.0 (brew stable matches the pin).
- **Next up:** `scripts/build-ghostty.sh` (fetch the pinned commit, build `GhosttyKit.xcframework` into `Vendor/`), `project.yml`, empty window that builds and launches
- **Blockers:** none

_Agents: update this section at the end of every session (what changed, what's next)._

## Gotchas

- **libghostty's embedding API is not a stable public API.** Pin the Ghostty commit,
  keep all calls inside `Terminal/`, read Ghostty's own macOS app source when unsure.
- **Building GhosttyKit needs the exact Zig version** that the pinned commit expects.
  Record it in `scripts/ghostty.version`.
- **Xcode 26+ ships the Metal Toolchain separately.** Without it the GhosttyKit build fails on shader compilation: `xcodebuild -downloadComponent MetalToolchain`.
- **Read the embedding API at the pinned commit, not main.** `include/ghostty.h` and `macos/Sources/Ghostty/` at `GHOSTTY_COMMIT` are the reference; main can differ.
- **App Sandbox must be off** (Shoji spawns shells and CLIs). Distribute outside the
  App Store, signed with Developer ID and notarized.
- **Hidden or minimized surfaces:** keep their size stable. Resizing a terminal to
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
            │  Terminal/GhosttyBridge ── surface callbacks ───────────┤        │
            │     (title, bell, desktop notification, child exit)     │        │
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

Runtime-only (not persisted): status, last activity, unread count, surface handle.

### Status states and sources

| State | Agents | Tasks |
|---|---|---|
| Working | prompt submitted / tool running (hook) | — |
| Needs you | Claude `Notification` hook; bell or desktop notification from surface | — |
| Done | Claude `Stop` hook; Codex `notify` turn complete | — |
| Idle | Done and already seen, or fresh session at prompt | — |
| Running | — | process alive |
| Exited(code) | process exited | process exited (non-zero = error) |

Resume ids: Claude from the `SessionStart` hook payload; Codex — to confirm (Open questions).

## Milestones

### M0 — Repo and build
- [ ] `project.yml` (XcodeGen), macOS 26 target, App Sandbox off, Debug/Release
- [ ] `scripts/ghostty.version` (commit + Zig version) and `scripts/build-ghostty.sh`
- [x] `.gitignore` (Vendor/, build output, generated project)
- [ ] Empty window builds and launches via `xcodebuild`
- [x] `docs/design/` HTML mockups of Option B and Hub view

### M1 — Spike (prove the risky parts)
- [ ] One libghostty surface in a SwiftUI view, shell runs, typing works
- [ ] Two surfaces side by side inside glass-framed cards (solid terminal background)
- [ ] Each launches `claude -r` in a hard-coded folder
- [ ] Window resize and focus switching between panes are smooth
- [ ] Hide/show one pane without redraw glitches (stable size while hidden)
- [ ] One Claude `Notification` hook → `shoji-hook` → socket → card turns orange
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
- [ ] Surface callbacks → StatusEvent: title, bell, desktop notification, child exit
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
- [ ] Settings: default folders, command presets, notifications on/off
- [ ] Devcontainer command presets
- [ ] Developer ID signing + notarization

## Open questions

- **Allow once:** allow from the Hub/toast for any prompt, or only for commands the
  user has approved before? Default proposal: only when the prompt text is visible
  on the card, and send exactly the shown keystroke.
- **Devcontainers:** how do hooks inside a container reach Shoji? Options: localhost
  TCP listener with a per-launch token, reached via `host.docker.internal`; or mount
  the socket into the container.
- **Codex:** does it expose a resume id and a needs-approval event we can hook, or do
  we rely on bell / desktop notification from the surface?
- **Performance:** how many live surfaces before it matters? Do hidden threads keep a
  live surface or detach and reattach?
- **Task restart:** SIGINT then relaunch, or SIGTERM with a timeout? Per task setting?
- **Git branch on Hub cards:** read `.git/HEAD` directly vs. shelling out to `git`.
