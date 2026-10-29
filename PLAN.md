# PLAN.md — Shoji

## Status

- **Last session (pane-control, PR #3, releases v0.3.0):** panes are under the user's control. A card click goes to its thread (focus if on screen, else it opens in the pane you're in; a line under the card marks threads in panes); ⌥-click or Show in This Pane brings it to your pane, swapping if needed; drop a card on a pane; pin panes (⇧⌘P); layout switches keep panes in place (no re-hosted terminals), keep the focused and pinned ones, and fill new panes; minimize is gone. ⌃Tab / ⌃⇧Tab switches recent threads like ⌘Tab. Names carry a number only when two would read the same. Codex reports status and resumes through its own hooks, like Claude (tried live by the user, `/hooks` trust included). Idle shows the Torii gate. A turn that finishes out of sight (not the focused pane, or Shoji in the background) is unseen and calls Hachi like needs-you, keeping its tick; Threads › Show Hachi When an Agent Finishes (on by default) turns that off. 64 tests pass.
- **Next up:** after the merge, `release.yml` publishes v0.3.0; install it and trust its Codex hooks once (a new path). Then Tasks › Next, with macOS notifications as the likely v0.4 headline.
- **Design update (completion):** optional Hachi-on-finish visual alternatives are in `docs/design/completion/`; no new treatment selected and no app changes from this design session.
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
- **Hidden terminals:** keep their size stable. Resizing a terminal to
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
- **Codex hooks need the user's trust once.** Codex skips any hook whose exact definition hasn't been trusted in `/hooks` (keyed by its hash), so the first Codex run in Shoji shows no status until the user trusts Shoji's hooks; Debug and installed builds have different hook paths, so each is trusted once. Keep `CodexHooks` stable: changing events, command or timeout asks for trust again. Shoji never passes `--dangerously-bypass-hook-trust`. `codex debug prompt-input -c '…'` validates an override without a model call (an unknown hook type fails; an unknown event is ignored). The `-c` hooks add to the user's own hooks, never replace them: CLI overrides are their own config layer (`SessionFlags`), and Codex reads hooks from each layer separately (`codex-rs/hooks/src/engine/discovery.rs`).
- **Codex `Stop` / `Interrupt` hooks expect JSON on stdout** when they print anything; `shoji-hook` prints nothing, which counts as success.
- **Typed `claude` / `codex` only report status through the zsh integration.** The functions add `--settings` / `-c`; an alias still works (aliases expand first), but a script or other shell calling the binary directly gets no hooks. bash and fish have no integration yet.
- **SwiftTerm's `registerOscHandler` isn't public** (the `Terminal` is internal to the view). Shell reports therefore use `OSC 1337 ; ShojiEvent=<kind>;<value>`: SwiftTerm hands unknown 1337 keys to `iTermContent`, in order, on the main thread.
- **zsh integration hooks in on the first prompt**, after the user's `.zshrc`, and puts its precmd first so `$?` is the command's exit code. A `.zshrc` that resets `precmd_functions` wholesale disables it.
- **Focus requests must always settle.** `makeFirstResponder` on a view that's already first responder fires no `becomeFirstResponder`, so `SwiftTermBackend.focus()` reports `.focused` itself; and `TerminalHost` only acts when a request arrives, so a pending one can't pull typing back after the user clicks another pane. Clicks focus explicitly in `ShojiTerminalView.mouseDown` because AppKit only focuses the exact view hit.
- **Hidden title bar:** content ignores the top safe area so the shelf shares the row with the traffic lights; the leading 78 pt column stays clear for them. `windowBackgroundDragBehavior(.enabled)` keeps the window draggable.
- **A blank app icon in ⌘Tab or the Dock is a stale icon cache**, not a missing icon: macOS keys it on the bundle folder's date, which incremental builds don't touch. `touch build/Build/Products/Debug/Shoji.app` and `lsregister -f` it, then relaunch.
- **Only one Debug Shoji at a time.** A second instance (`open -n`) takes over `Shoji-Debug/hook.sock` and both write `threads.json`; quitting either removes the socket.
- **Panes keep their identity across layouts.** `PaneGrid` places one `PaneView` per thread by frame (`PaneTiles`); it used to rebuild the split views on every layout switch, re-hosting every terminal, the likely cause of terminals going blank on a switch (confirm by hand).
- **⌃Tab is read by a local key monitor** (`RecentSwitchKeys`), not the menu, because the switcher needs ⌃'s release (`flagsChanged`) and the keys must never reach the terminal. The menu items still show the shortcut, and a click switches at once. It stands down while a sheet or alert is up.
- **Drops on a pane land on SwiftUI's `onDrop`**, because SwiftTerm's view registers no dragged types; the drop never reaches the shell.
- **⌘W is Close thread.** `ShojiCommands` replaces the `.saveItem` group, which also removes the system Close Window item, so ⌘W can't close the main window by accident.
- **A restarted terminal's old process still reports its exit.** `TerminalSessions` ignores events from any backend that is no longer the thread's current one.
- **AX `set value` on a SwiftUI text field doesn't reach its binding until editing ends.** In accessibility-driven checks, move focus (set another field) before pressing a button.
- **Tags pushed with `GITHUB_TOKEN` don't trigger other workflows**, so `release.yml` creates the tag and the release in one run (`gh release create --target`). The `v*` tag ruleset still blocks moving or deleting it afterwards.
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
- Card: status icon, a tag for what runs (CLAUDE / CODEX / the command's name, none at an idle prompt), name (the folder's name unless renamed; a number only when two unnamed threads would read the same, like "shoji 2", given to the newer thread, so a `cd` into a subfolder and back changes nothing), one-line status, command or folder, elapsed time.
- Needs-you card: orange border + glow, count badge, Hachi. A finished turn you haven't seen (Zed's unread dot: it ended outside the focused pane, or while Shoji was in the background) gets the same card, Hachi corner and ⌘J, keeping its tick and without a count; focusing it or returning to Shoji on it clears it. Threads › Show Hachi When an Agent Finishes (default on, remembered) leaves only the quiet tick.
- Drag a card onto another to put it before or after it (by which half), joining that card's group; ⌘N plus a drag replaces any per-group + button.
- Card context menu: Show in This Pane, Rename, Move Left / Right (the non-drag path, also for VoiceOver), Add / Remove Bar Before, Restart (shell ended), Close Thread. Later: open folder in Zed.
- Bars are lanes for scanning (say agents left, servers right), not layout: where terminals sit on screen is the pane layout's job.
- Layout switcher (macOS tiling icons, ⌥⌘1–4 by pane count): 1 pane / 2 columns / 3 panes (one tall left, two stacked right) / 2×2 grid, which shows 2 up 1 down with three open. Switching keeps the pane you're in on screen, and new panes show threads that were there before, then recent ones, then the shelf's.
- Clicking a card goes to its thread: one already on screen just takes focus (a line under its card says so); otherwise it opens in a free pane, else in the pane you're in (with none focused: the one used longest ago that isn't waiting for you), and the thread it replaces comes back first when the layout grows. ⌥-click or the card menu's Show in This Pane brings it to your pane, swapping when it's on screen elsewhere (user's call: a click never rearranges panes). Dropping a card on a pane puts it there (a thread already on screen trades places). A pinned pane is passed over by clicks until every pane is pinned; pins follow the thread and end when it leaves the panes.
- ⌃Tab / ⌃⇧Tab: recent threads like ⌘Tab; a quick tap returns to the previous thread, holding ⌃ shows the list (after 150 ms), Esc cancels.
- Pane header: name, folder, Pin, Maximize; Restart once the shell has ended. No minimize (user's call): the layout sets how many panes, cards decide what's in them, ⌘W closes.

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
      "title": "auth-refactor",
      "folder": "~/code/gosta",
      "group": 0,
      "order": 0,
      "command": "claude",
      "resumeId": "abc123…",
      "resumeAgent": "claude"
    },
    {
      "id": "9A2E…",
      "folder": "~/code/gosta",
      "group": 1,
      "order": 0,
      "command": "docker compose up"
    }
  ],
  "layout": { "mode": "twoColumns", "openThreadIds": ["6F1C…", "9A2E…"], "pinnedThreadIds": ["9A2E…"], "columnSplit": 0.5, "rowSplit": 0.5 }
}
```

`title` is optional (the card shows the folder's name), `folder` follows the shell's working directory, and `group` / `order` place the card (a bar between groups). The array is in creation order, which decides who carries the number among same-named threads (the newer one). Files from v0.2 still load: their `number` is ignored, and every `layout` key may be missing (`pinnedThreadIds` is newer). `command` is what was running at the last save and `resumeId` the agent session in it, with `resumeAgent` naming its CLI (kept when a relaunch or a dead shell clears `command`; older files fall back to `command`, then Claude): a relaunch runs `claude --resume <id>` or `codex resume <id>` at the first prompt, or leaves `command` at the prompt for Return.

Runtime-only (not persisted): status, last activity, unread count, agent, terminal view.

### Status states and sources

| State | Source |
|---|---|
| Idle | at the shell prompt (launched, or a command finished with 0 / 130); Claude at its own prompt; Done or a failed command once focused |
| Running | a command other than claude / codex is running (zsh `preexec`) |
| Working | Claude or Codex `UserPromptSubmit` / `PostToolUse` hook; typing into a needs-you thread |
| Needs you | Claude `Notification` hook (not `idle_prompt`); Codex `PermissionRequest`; bell while Working |
| Done | Claude or Codex `Stop` hook; Codex `Interrupt`. Unseen (wants you, with the menu setting) when it lands outside the focused pane or while Shoji is in the background |
| Exited(code) | a command failed (shell still alive, clears on focus), or the shell itself ended (Restart) |

Shell reports from the zsh integration: `cwd;<path>` each prompt, `cmd;<line>` before a command, `done;<code>` after it.

Files live in `~/Library/Application Support/Shoji` (`Shoji-Debug` for Debug builds): `threads.json`, saved half a second after a change and on quit, and `hook.sock`. A `threads.json` Shoji can't read (corrupt, or from a newer version) is renamed to `threads.unreadable-<time>.json`, never overwritten.

Hook transport: `shoji-hook` sends one connection per event to `hook.sock` in that folder: the thread id on the first line, then the CLI's JSON from stdin (Claude and Codex send the same core fields). Resume ids come from `session_id` in prompt/tool hooks for both; `command` tells which CLI resumes it.

## Tasks

Priorities shift with the user's wishes; reorder freely. Keep items one line, small enough for one PR.

### Now
- [ ] Hands-on pass by the user: the terminal checklist below, plus pane resize / focus feel, split dragging, and shortcuts with a terminal focused
- [ ] Hands-on pass on daily-driver: ⌘N opens a shell beside the focused card; `cd` updates the card; typed `claude` shows status and `/exit` returns to the prompt; quit and reopen resumes Claude and prefills a stopped `pnpm dev`; Move Left / Right and bars; ⌘W confirm only while running

- [ ] Open the v0.3.0 DMG once and check its first launch (Open Anyway)
- [ ] Rest of the pane-control pass (⌃Tab and Codex status already confirmed): click a card on screen (focus only, line under the card), ⌥-click and Show in This Pane (swap), drag a card onto a pane and onto another visible pane (swap), pin then click cards, two shells in one folder ("shoji", "shoji 2"), no blank panes when switching layouts with busy terminals, Codex quit + reopen resumes; an agent finishing in another pane or with Shoji in the background calls Hachi, focusing it clears, and the Threads menu toggle turns it off; the Torii gate on idle cards

### Next
- [ ] Open folder in Zed from the card context menu
- [ ] bash (and maybe fish) integration, so threads in those shells get folder, command and Claude status
- [ ] macOS notification for needs-you while Shoji is in the background
- [ ] Give card drags their own drag type: panes accept `.plainText`, so text dragged in from another app highlights a pane and is accepted as a drop that does nothing (review finding; needs a live drag test, so not in v0.3)
- [ ] opencode status and resume (`opencode -s <id>`). Not hook-compatible with Claude / Codex: it takes in-process JS plugins with events (`session.status`, `permission.asked`, `session.idle`). Likely a small Shoji plugin loaded per launch through `OPENCODE_CONFIG_DIR`, forwarding to `shoji-hook`; but v2 runs plugins in a shared background service, so telling threads apart probably needs `--standalone` per thread. Prototype first

### Later
- [ ] Multiple windows in two styles: **full** (today's shelf and panes, made for near-fullscreen) and **sidebar** (a slim column of compact cards beside your editor that shows who needs you and opens a thread in one click)
- [ ] Workspaces: a named set of threads with its layout (for example *gosta*, *home-lab*), one per window; every window comes back on relaunch with its workspace, style, size and position
- [ ] Hub view: Threads | Hub switch, agent cards sorted by attention with the last 3 lines, task cards with Restart / Stop / Open, totals pills, open folder in Zed
- [ ] "Allow once" from the Hub, with guardrails (see Open questions)
- [ ] ⌘K quick jump
- [ ] Settings: default folders, command presets, notifications, terminal font, theme, scrollback, Option as Meta
- [ ] Devcontainer command presets
- [ ] Third-party notices in the app bundle (SwiftTerm MIT license text)
- [ ] Developer ID signing and notarization (needs a paid Apple Developer account)

### Done
- Completion design study: current orange treatment compared with quiet ivory chrome, an ink-circle check and a small shoji mark; interactive preview, selection still open
- Idle Torii design: SVG, vector PDF/template image set, status mapping and 75/100/200% size previews at 1×/2×
- Build: XcodeGen project, SwiftTerm 1.99.1 pinned, CI on GitHub (`xcode-27` runner), release workflow and `scripts/package.sh` (universal ad-hoc DMG)
- Terminals: SwiftTerm panes (Metal) in glass cards, login-shell launch, 10k scrollback, Shift+Return fallback, hide / show without redraw glitches
- Status: `shoji-hook` → socket → `ThreadStore`, per-launch Claude hooks, terminal title / bell / exit; working / needs you / done / idle with elapsed time and needs-you count; resume id captured
- Shelf and panes: card shelf, click a card to open it, 1 / 2 / 3 / 2×2 layouts, maximize, drag splits
- Keyboard and zoom: one `Shortcut` catalog for menus and the ⌘/ sheet, app-wide zoom ⌘+ / ⌘− / ⌘0
- Hachi: vector portrait on needs-you cards (zoom-aware, behind the count badge) and in the window corner while anything needs you; a layered Icon Composer app icon
- Pane control: a card opens in the pane you're in, or a free one, else the least recently used pane that isn't waiting; layout switches keep panes (no re-hosted terminals), the focused and pinned ones on screen, and fill new panes; drop a card on a pane; pin a pane; a card click brings its thread to your pane; ⌃Tab recent-thread switcher; names number only same-named threads
- Codex: status (working, needs you on `PermissionRequest`, done) and `codex resume` through its own hooks, like Claude
- Idle shows the approved Torii gate (`docs/design/status/`) instead of the dashed ring
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

- **Completion presentation:** retain current orange unseen-finish chrome, or choose A (quiet ivory), B (ink-circle check) or C (shoji corner mark)? See `docs/design/completion/preview.html`; design recommends A first.
- **Allow once:** allow from the Hub/toast for any prompt, or only for commands the
  user has approved before? Default proposal: only when the prompt text is visible
  on the card, and send exactly the shown keystroke.
- **Devcontainers:** how do hooks inside a container reach Shoji? Options: localhost
  TCP listener with a per-launch token, reached via `host.docker.internal`; or mount
  the socket into the container.
- **Performance:** how many live terminal views before it matters? Do hidden threads
  keep a live view, or keep only SwiftTerm's headless `Terminal` and reattach a view?
- **Themes:** ship a few built-in themes, or import Ghostty/iTerm2 theme files?
- **Task restart:** SIGINT then relaunch, or SIGTERM with a timeout? Per task setting?
- **Git branch on Hub cards:** read `.git/HEAD` directly vs. shelling out to `git`.
- **Stable local signing identity:** a self-signed code-signing certificate (kept as a CI secret) would keep TCC grants across updates without a paid account. Worth it before daily use, or wait for Developer ID?
- **Multiple windows:** a thread's terminal can be on screen in only one window at a time (one SwiftTerm view per thread). When a second window opens it, move it there, or show only its card?
- **Sidebar window:** clicking a card opens the thread in a full window, or expands it in place?
- **Invariant 9 wording:** v0.3 changed the `threads.json` shape (dropped `number`; added `pinnedThreadIds`, `resumeAgent`) without bumping `schemaVersion`, because both directions still read it, and a bump would make an older Shoji set the whole file aside. Proposal: bump (and migrate) only when an older or newer Shoji couldn't read the file; additive optional fields and ignored removed fields stay on the current version. Needs the user's OK to reword the invariant.
- **Quitting with live agents:** quitting closes every PTY (agents get SIGHUP). Confirm before quit while something is Working / Needs you?

## Decisions

- **Codex through its hooks, not `notify`** (2026-10-28). Codex (checked on 0.164) has Claude-style hooks with the same stdin fields, passed per launch as `-c hooks={…}`, so `~/.codex` stays untouched and the user's own `notify` isn't overridden. Cost: the user trusts Shoji's hooks once in `/hooks`.

- **A finished turn you didn't see wants you** (2026-10-29, user's call, after Zed's unread dot). The user doesn't need to tell "needs my click" from "done, needs my check", so both call Hachi; the tick stays to show which. A menu toggle keeps the quiet tick for focused work.

- **Releases follow the version** (2026-10-28). Bumping `MARKETING_VERSION` in `project.yml` inside a PR is the decision to release; merging it makes `release.yml` build the DMG and publish `vX.Y.Z` with generated notes, creating the tag on that commit. Other merges don't release. No manual tags. Chosen over release-please / semantic-release (Conventional Commit titles, a bot PR, a changelog file) while Shoji has one maintainer; revisit if contributors join.

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
