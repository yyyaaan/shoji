# PLAN.md — Shoji

## Status

- **Last session (daily-driver):** Shoji keeps your threads, and every thread is now a plain shell. ⌘N opens one at once next to the focused card, in its folder; you `cd` and run `claude`, `codex` or a dev server, and quit back to the prompt. A zsh integration reports folder and commands and gives typed `claude` the status hooks; a relaunch restores threads, layout and splits, resumes Claude sessions and leaves other last commands at the prompt. Shelf groups are just bars the user adds or removes (context menu: Move Left / Right, Add / Remove Bar Before, Rename, Restart, Close). ⌘W closes, confirming only when something is running. Verified the integration in a pty (events, resume autorun with a fake claude, ZDOTDIR restored) and in the Debug app (folder report reaches `threads.json`). Then: clicking a pane now always moves typing there, the toolbar row is gone (title bar hidden; + under the window buttons, layout and shortcuts at the shelf's right end), and unnamed threads read "<folder> <number>" with stable, lowest-free numbers. Last: cards drag into place (drop on a card's left or right half; a blue line shows where), and the shortcuts and + buttons left the top row (⌘/, the Help menu and ⌘N remain). New three-pane layout, one tall left and two stacked right, on ⌥⌘3; the grid moved to ⌥⌘4 so the number matches the panes. Hachi's corner under the window buttons: empty, or Hachi with the count while any thread needs you (click = ⌘J); the Hachi spec now lists this placement. 47 tests pass.
- **Next up:** the user's hands-on pass (Tasks › Now), then **Tasks › Next**.
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
- **Typed `claude` only reports status through the zsh integration.** The `claude` function adds `--settings`; an alias still works (aliases expand first), but a script or other shell calling the binary directly gets no hooks. bash and fish have no integration yet.
- **SwiftTerm's `registerOscHandler` isn't public** (the `Terminal` is internal to the view). Shell reports therefore use `OSC 1337 ; ShojiEvent=<kind>;<value>`: SwiftTerm hands unknown 1337 keys to `iTermContent`, in order, on the main thread.
- **zsh integration hooks in on the first prompt**, after the user's `.zshrc`, and puts its precmd first so `$?` is the command's exit code. A `.zshrc` that resets `precmd_functions` wholesale disables it.
- **Focus requests must always settle.** `makeFirstResponder` on a view that's already first responder fires no `becomeFirstResponder`, so `SwiftTermBackend.focus()` reports `.focused` itself; and `TerminalHost` only acts when a request arrives, so a pending one can't pull typing back after the user clicks another pane. Clicks focus explicitly in `ShojiTerminalView.mouseDown` because AppKit only focuses the exact view hit.
- **Hidden title bar:** content ignores the top safe area so the shelf shares the row with the traffic lights; the leading 78 pt column stays clear for them. `windowBackgroundDragBehavior(.enabled)` keeps the window draggable.
- **A blank app icon in ⌘Tab or the Dock is a stale icon cache**, not a missing icon: macOS keys it on the bundle folder's date, which incremental builds don't touch. `touch build/Build/Products/Debug/Shoji.app` and `lsregister -f` it, then relaunch.
- **Only one Debug Shoji at a time.** A second instance (`open -n`) takes over `Shoji-Debug/hook.sock` and both write `threads.json`; quitting either removes the socket.
- **⌘W is Close thread.** `ShojiCommands` replaces the `.saveItem` group, which also removes the system Close Window item, so ⌘W can't close the main window by accident.
- **A restarted terminal's old process still reports its exit.** `TerminalSessions` ignores events from any backend that is no longer the thread's current one.
- **AX `set value` on a SwiftUI text field doesn't reach its binding until editing ends.** In accessibility-driven checks, move focus (set another field) before pressing a button.
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
- No toolbar row (user's call): the title bar is hidden and the shelf takes the top. Its left end holds the window buttons and Hachi's corner below them (empty; Hachi and a count while anything needs you, click opens it), its right end the layout switcher; new threads come from ⌘N and shortcuts from ⌘/ or the Help menu, so neither has a button. The window drags by its background.
- Shelf of glass cards across the top in the user's order, split into groups by plain bars (no titles, no fixed meaning; user's call); scrolls sideways when cards overflow.
- Card: status icon, a tag for what runs (CLAUDE / CODEX / the command's name, none at an idle prompt), name (folder and number, like "~ 2", unless renamed), one-line status, command or folder, elapsed time.
- Needs-you card: orange border + glow, count badge, Hachi.
- Drag a card onto another to put it before or after it (by which half), joining that card's group; ⌘N plus a drag replaces any per-group + button.
- Card context menu: Rename, Move Left / Right (the non-drag path, also for VoiceOver), Add / Remove Bar Before, Restart (shell ended), Close Thread. Later: open folder in Zed.
- Bars are lanes for scanning (say agents left, servers right), not layout: where terminals sit on screen is the pane layout's job.
- Layout switcher (macOS tiling icons, ⌥⌘1–4 by pane count): 1 pane / 2 columns / 3 panes (one tall left, two stacked right) / 2×2 grid, which shows 2 up 1 down with three open. Pane header: name, folder,
  Maximize, Minimize to shelf; Restart once the shell has ended.

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
      "number": 1,
      "title": "auth-refactor",
      "folder": "~/code/gosta",
      "group": 0,
      "order": 0,
      "command": "claude",
      "resumeId": "abc123…"
    },
    {
      "id": "9A2E…",
      "number": 2,
      "folder": "~/code/gosta",
      "group": 1,
      "order": 0,
      "command": "docker compose up"
    }
  ],
  "layout": { "mode": "twoColumns", "openThreadIds": ["6F1C…", "9A2E…"], "columnSplit": 0.5, "rowSplit": 0.5 }
}
```

`number` is stable and the lowest free one at creation (a file without numbers gets them on load); `title` is optional (the card shows folder and number), `folder` follows the shell's working directory, and `group` / `order` place the card (a bar between groups). `command` is what was running at the last save and `resumeId` the Claude session in it: a relaunch runs `claude --resume <id>` at the first prompt, or leaves `command` at the prompt for Return.

Runtime-only (not persisted): status, last activity, unread count, agent, terminal view.

### Status states and sources

| State | Source |
|---|---|
| Idle | at the shell prompt (launched, or a command finished with 0 / 130); Claude at its own prompt; Done or a failed command once focused |
| Running | a command other than claude is running (zsh `preexec`) |
| Working | Claude `UserPromptSubmit` / `PostToolUse` hook; typing into a needs-you thread |
| Needs you | Claude `Notification` hook (not `idle_prompt`); bell while Working |
| Done | Claude `Stop` hook; Codex `notify` `agent-turn-complete` |
| Exited(code) | a command failed (shell still alive, clears on focus), or the shell itself ended (Restart) |

Shell reports from the zsh integration: `cwd;<path>` each prompt, `cmd;<line>` before a command, `done;<code>` after it.

Files live in `~/Library/Application Support/Shoji` (`Shoji-Debug` for Debug builds): `threads.json`, saved half a second after a change and on quit, and `hook.sock`. A `threads.json` Shoji can't read (corrupt, or from a newer version) is renamed to `threads.unreadable-<time>.json`, never overwritten.

Hook transport: `shoji-hook` sends one connection per event to `hook.sock` in that folder: the thread id on the first line, then the CLI's JSON (stdin for Claude, argv[1] for Codex `notify`). Resume ids: Claude from `session_id` in prompt/tool hooks; Codex — to confirm (Open questions).

## Tasks

Priorities shift with the user's wishes; reorder freely. Keep items one line, small enough for one PR.

### Now
- [ ] Hands-on pass by the user: the terminal checklist below, plus pane resize / focus feel, split dragging, and shortcuts with a terminal focused
- [ ] Hands-on pass on daily-driver: ⌘N opens a shell beside the focused card; `cd` updates the card; typed `claude` shows status and `/exit` returns to the prompt; quit and reopen resumes Claude and prefills a stopped `pnpm dev`; Move Left / Right and bars; ⌘W confirm only while running

### Next
- [ ] Recent-thread switcher: ⌃Tab / ⌃⇧Tab cycles threads in most-recently-used order, like ⌘Tab for apps; a quick tap returns to the previous thread. (⌘1–9 stays "card by shelf position"; check ⌃Tab doesn't collide with the CLIs.)
- [ ] Keep waiting panes on screen: when opening a thread replaces a pane, never replace one whose agent needs you; take the least recently used other pane
- [ ] Open folder in Zed from the card context menu
- [ ] bash (and maybe fish) integration, so threads in those shells get folder, command and Claude status
- [ ] Drop a card onto a pane to show it there (direct control over which pane a thread takes)
- [ ] Pin a pane so opening other threads never replaces it (a dev server's log, a waiting agent)
- [ ] macOS notification for needs-you while Shoji is in the background
- [ ] Codex `notify` and resume through the zsh integration's `codex` function (decide the notify override first, see Open questions); until then Codex shows as running and a relaunch leaves `codex` at the prompt

### Later
- [ ] Multiple windows in two styles: **full** (today's shelf and panes, made for near-fullscreen) and **sidebar** (a slim column of compact cards beside your editor that shows who needs you and opens a thread in one click)
- [ ] Workspaces: a named set of threads with its layout (for example *gosta*, *home-lab*), one per window; every window comes back on relaunch with its workspace, style, size and position
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
- Shelf and panes: Agents | Tasks shelf, click a card to open it, 1 / 2 / 3 / 2×2 layouts, maximize / minimize, drag splits
- Keyboard and zoom: one `Shortcut` catalog for menus and the ⌘/ sheet, app-wide zoom ⌘+ / ⌘− / ⌘0
- Hachi: vector portrait on needs-you agent cards (zoom-aware, behind the count badge) and a layered Icon Composer app icon
- Daily driver: threads are shells (⌘N instant, welcome screen); zsh integration for folder, commands and Claude hooks; `threads.json` save and restore with Claude resume and last-command prefill; shelf bars with Move Left / Right; rename, restart, close (⌘W, confirm while running)

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
- **Multiple windows:** a thread's terminal can be on screen in only one window at a time (one SwiftTerm view per thread). When a second window opens it, move it there, or show only its card?
- **Sidebar window:** clicking a card opens the thread in a full window, or expands it in place?
- **Quitting with live agents:** quitting closes every PTY (agents get SIGHUP). Confirm before quit while something is Working / Needs you?

## Decisions

- **Threads are shells** (2026-10-28, user's call). A thread no longer has a fixed command or an agent/task kind: it's the user's login shell, and the card reflects what runs in it. Quitting an agent returns to the prompt, `cd` replaces a folder picker, and the old Agents | Tasks split became user-placed bars.

- **Name:** the app is **Shoji** (Dock, menus, repo, bundle id, code); **Hachi no Shoji** (ハチの障子) is the full name for places with room for the story, like the README header and an About box.
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
