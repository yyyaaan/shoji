# PLAN.md — Shoji

## Status

- **Shipped:** v0.4.0 (reach-out, PR #4) released and installed, 2026-10-29: splits, quick terminal, menu bar Hachi, Dock badge and notifications, file drops, Open in Zed / VS Code, agents named by topic.
- **This session (finishing-touches → v0.4.1):** the menu bar item removed (user's call); terminal text size apart from interface size, with per-pane text steps; Open in VS Code (⌥⇧⌘E) / Open in Zed (⇧⌘E) as two plain menu items; menus split into Threads, Panes and View; the quick terminal sits a little above centre; a go-to glow on panes, ⌘Q asks only when something is busy, SwiftTerm's notice in the app and About panel, PLAN › Now cut down to what's unconfirmed. 70 tests; `MARKETING_VERSION` 0.4.1. No big features planned: the user wants a break from larger deliveries; Later stays as is until they pick something.
- **Next up:** open the `finishing-touches` PR (merging publishes v0.4.1), install it, then the checks in Now; design's review of the v0.4 chrome is still open.
- **Blockers:** none
- **Design:** menu bar artwork, exporters and references removed to match v0.4.1; cleanup handoff completed. Review of the pane header, edge-drop preview, shelf corner and quick terminal remains open (app-to-design handoff).

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
- **`NSApp` is nil during `ShojiApp.init`.** Anything created there (like `Notifier`) must wait for `NSApplication.didFinishLaunchingNotification` before touching `NSApp` (Dock badge, `isActive`); touching it earlier traps at launch. The test host never builds the `Notifier`, so tests won't catch it: launch the Debug app after changing launch wiring.
- **Notifications in the Debug build** ask for permission once as "Shoji Debug" (its own bundle id); test them with Shoji Debug in the background, since nothing is posted while it's the active app. A hook sent to `Shoji-Debug/hook.sock` with `scripts/shoji-hook` (`SHOJI_THREAD_ID`, `SHOJI_SOCKET`) raises needs-you without a real agent.
- **Hook socket paths are capped at 104 characters** (Unix sockets). A support folder under a long path (a scratchpad, a fake home for a demo) silently leaves Shoji without hooks; keep demo homes short, e.g. `build/demo-home`.
- **Only one Debug Shoji at a time.** A second instance (`open -n`) takes over `Shoji-Debug/hook.sock` and both write `threads.json`; quitting either removes the socket.
- **Panes keep their identity across layouts.** `PaneGrid` places one `PaneView` per thread by frame (`PaneTiles`, computed from the split tree); it used to rebuild the split views on every layout switch, re-hosting every terminal, the likely cause of terminals going blank on a switch (confirm by hand). Keep it that way when splitting, closing panes or arranging.
- **⌃Tab is read by a local key monitor** (`RecentSwitchKeys`), not the menu, because the switcher needs ⌃'s release (`flagsChanged`) and the keys must never reach the terminal. The menu items still show the shortcut, and a click switches at once. It stands down while a sheet or alert is up.
- **Drops on a pane land on SwiftUI's `onDrop`**, because SwiftTerm's view registers no dragged types; the drop never reaches the shell.
- **CI test report comment:** CI finds its earlier comment by the `<!-- shoji-test-report -->` first line and updates it in place. PRs from forks get a read-only token, so they only get the run summary. `xcresulttool get test-results summary|tests` (Xcode 16+) is the source; try it locally with `-resultBundlePath build/TestResults.xcresult` and `scripts/test-report.py build/TestResults.xcresult`.
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
- No toolbar row (user's call): the title bar is hidden and the shelf takes the top. Its left end holds the window buttons and Hachi's corner below them (empty; Hachi and a count while anything needs you, click opens it); the shelf runs to the right edge (presets live in the Panes menu); new threads come from ⌘N and shortcuts from ⌘/ or the Help menu, so neither has a button. The window drags by its background.
- Shelf of glass cards across the top in the user's order, split into groups by plain bars (no titles, no fixed meaning; user's call); scrolls sideways when cards overflow.
- Card: status icon, a tag for what runs (CLAUDE / CODEX / the command's name, none at an idle prompt), name (your rename, else a running agent's topic, else the folder's name; a number only when two threads would read the same folder name, like "shoji 2", given to the newer thread, so a `cd` into a subfolder and back changes nothing), a subtitle (the folder, or a plain command's command line, or the question while an agent needs you), elapsed time; the full folder as a tooltip.
- Needs-you card: orange border + glow, count badge, Hachi. A finished unseen turn keeps its tick and no count, with Quiet finish ivory chrome and static halo; focusing it or returning to Shoji on it clears it. Threads › Show Hachi When an Agent Finishes (default on, remembered) controls its portrait, Hachi corner and ⌘J participation, not the completion halo.
- Drag a card onto another to put it before or after it (by which half), joining that card's group; ⌘N plus a drag replaces any per-group + button.
- Card context menu: Show in This Pane, Rename, Move Left / Right (the non-drag path, also for VoiceOver), Add / Remove Bar Before, Open in VS Code / Zed, Restart (shell ended), Close Thread.
- Bars are lanes for scanning (say agents left, servers right), not layout: where terminals sit on screen is the pane layout's job.
- Split panes (v0.4, Decisions › Panes are splits): any pane splits right, left, down or up from its header's Split menu, its right-click menu, ⌘D / ⇧⌘D, or a card dropped on its edge (a highlighted half shows where it lands). A new split shows your most recent thread that isn't on screen, else a new shell. Close Pane keeps the thread on the shelf. the Panes menu (⌥⌘1–4) snaps the panes into 1 pane / 2 columns / 3 panes (one tall left, two stacked right) / 2×2 grid (2 up 1 down with three), keeping the pane you're in and filling from recent threads, then the shelf's.
- Clicking a card goes to its thread: one already on screen just takes focus (a line under its card says so); otherwise it opens in the pane you're in (with none focused: the one used longest ago that isn't waiting for you). ⌥-click or the card menu's Show in This Pane brings it to your pane, swapping when it's on screen elsewhere (user's call: a click never rearranges panes). Dropping a card on a pane puts it there (a thread already on screen trades places). Other panes never change behind your back, so there are no pins (Decisions).
- ⌃Tab / ⌃⇧Tab: recent threads like ⌘Tab; a quick tap returns to the previous thread, holding ⌃ shows the list (after 150 ms), Esc cancels.
- Pane header: status, name and folder; Split and Maximize appear on hover as plain icons; double-click maximizes; Restart once the shell has ended. No minimize (user's call): splits and Close Pane set how many panes, cards decide what's in them, ⌘W closes the thread.

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
  "layout": {
    "root": { "split": { "axis": "columns", "ratio": 0.5, "first": { "pane": { "id": "6F1C…" } }, "second": { "pane": { "id": "9A2E…" } } } },
    "mode": "twoColumns", "openThreadIds": ["6F1C…", "9A2E…"]
  }
}
```

`title` is optional (the card shows the folder's name), `folder` follows the shell's working directory, and `group` / `order` place the card (a bar between groups). The array is in creation order, which decides who carries the number among same-named threads (the newer one). Files from v0.2 still load: their `number` is ignored, and every `layout` key may be missing (`pinnedThreadIds` is newer). `layout.root` is the split tree (v0.4); a file without it becomes its fixed layout (`mode`, `openThreadIds`, `columnSplit`, `rowSplit`), and v0.4 keeps writing the nearest `mode` and `openThreadIds` so v0.3 still opens its files. `command` is what was running at the last save and `resumeId` the agent session in it, with `resumeAgent` naming its CLI (kept when a relaunch or a dead shell clears `command`; older files fall back to `command`, then Claude): a relaunch runs `claude --resume <id>` or `codex resume <id>` at the first prompt, or leaves `command` at the prompt for Return.

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
Everyday use (shelf, panes and splits, ⌃Tab, quick terminal, notifications, Claude and Codex status) is confirmed by the user's daily driving; what's left is what hasn't been seen yet.
- [ ] The terminal checklist below, item by item
- [ ] v0.4: the Dock badge with counts of 10 or more; a screenshot dragged from Finder onto Claude Code (path pasted, image attached); Open in VS Code (⌥⇧⌘E) / Open in Zed (⇧⌘E) from Threads, card and pane menus; Codex quit and reopen resumes its session
- [ ] v0.4.1 menus: Threads, Panes and View read well, Interface Size shows inline with a checkmark, the layouts sit in Panes without a submenu
- [ ] v0.4.1 sizes: ⌘+ / ⌘− change only terminal text, View › Interface Size only the chrome; ⌥⌘+ / ⌥⌘− on one pane keeps it a level apart through ⌘− and shows its size in the header, ⌥⌘0 puts it back; your old zoom came back as the text size
- [ ] v0.4.1: a card click, ⌘1–9, ⌃Tab or ⌘J landing on a pane already on screen makes it glow briefly (and not when it replaces your pane's thread); ⌘Q with something busy lists it and asks, with nothing busy quits at once; Shoji › About Shoji shows Hachi no Shoji and the SwiftTerm notice
- [ ] After installing v0.4.1: notifications still allowed (the first update since v0.4.0 asked); re-grant anything in Privacy & Security that agents running in Shoji need (Accessibility, Screen Recording), and trust its Codex hooks in `/hooks` if Codex asks

### Next
- [ ] Design: review the pane header, split drop preview, shelf corner and ⌘K quick terminal, now built (app-to-design handoff)
- [x] README screenshot retaken for v0.4 with invented demo threads; how to redo it: `docs/images/README.md`
- No sprint planned (user's call, 2026-10-29): a break from bigger deliveries; Later keeps the candidates (workspaces and multiple windows, a Settings window, the Hub) until the user picks one

### Parked
Only when the user asks for it.
- [ ] bash (and maybe fish) integration. No big win while zsh is both macOS's default and the user's shell; shells inside containers belong to the devcontainer question, not this
- [ ] opencode status and resume (`opencode -s <id>`). Not hook-compatible with Claude / Codex: it takes in-process JS plugins with events (`session.status`, `permission.asked`, `session.idle`). Likely a small Shoji plugin loaded per launch through `OPENCODE_CONFIG_DIR`, forwarding to `shoji-hook`; but v2 runs plugins in a shared background service, so telling threads apart probably needs `--standalone` per thread. Prototype first

### Later
- [ ] Multiple windows in two styles: **full** (today's shelf and panes, made for near-fullscreen) and **sidebar** (a slim column of compact cards beside your editor that shows who needs you and opens a thread in one click)
- [ ] Workspaces: a named set of threads with its layout (for example *gosta*, *home-lab*), one per window; every window comes back on relaunch with its workspace, style, size and position
- [ ] Hub view: Threads | Hub switch, agent cards sorted by attention with the last 3 lines, task cards with Restart / Stop / Open, totals pills, open folder in Zed
- [ ] "Allow once" from the Hub, with guardrails (see Open questions)
- [ ] Settings: default folders, command presets, notifications, terminal font, theme, scrollback, Option as Meta
- [ ] Devcontainer command presets
- [ ] Developer ID signing and notarization (needs a paid Apple Developer account)

### Done
- v0.4.1 finishing-touches: menu bar item removed; text size apart from interface size, per-pane text steps; Open in VS Code / Zed as menu items; go-to glow on panes, ⌘Q asks only when something is busy, SwiftTerm notice in the app and About panel
- v0.4.0 reach-out: Debug app id; split panes (tree, Split menu, ⌘D / ⇧⌘D, edge drops with a half preview, Close Pane, View › Arrange) instead of fixed layouts and pins; quiet pane header; dropped files and text paste into terminals; card drag type; Open in Zed / VS Code; options in the Threads menu; menu bar Hachi, Dock badge and macOS notifications; ⌘K quick terminal; agents named by their topic
- Design documentation audit: accepted-design index, obsolete references and intermediate exports removed; links checked.
- Menu bar artwork and design references removed with the feature in v0.4.1; cleanup handoff completed.
- Completion design: Quiet finish A + static ivory halo for unseen finishes, independent of the Hachi toggle (`docs/design/completion/`)
- Idle Torii design: SVG, vector PDF/template image set, status mapping and 75/100/200% size previews at 1×/2×
- Build: XcodeGen project, SwiftTerm 1.99.1 pinned, CI on GitHub (`xcode-27` runner), release workflow and `scripts/package.sh` (universal ad-hoc DMG), test report on PRs (`scripts/test-report.py`: one comment per PR, updated on each push, plus the run summary)
- Terminals: SwiftTerm panes (Metal) in glass cards, login-shell launch, 10k scrollback, Shift+Return fallback, hide / show without redraw glitches
- Status: `shoji-hook` → socket → `ThreadStore`, per-launch Claude hooks, terminal title / bell / exit; working / needs you / done / idle with elapsed time and needs-you count; resume id captured
- Shelf and panes: card shelf, click a card to open it, 1 / 2 / 3 / 2×2 layouts, maximize, drag splits
- Keyboard and zoom: one `Shortcut` catalog for menus and the ⌘/ sheet, app-wide zoom ⌘+ / ⌘− / ⌘0
- Hachi: vector portrait on needs-you cards (zoom-aware, behind the count badge) and in the window corner while anything needs you; a layered Icon Composer app icon
- Pane control (v0.3.0): a click goes to a thread (on screen: focus; else your pane, a free one, or the least recently used pane that doesn't want you); ⌥-click / Show in This Pane brings it to your pane; drop a card on a pane; pins; layout switches keep panes (no re-hosted terminals), the focused and pinned ones, and fill new panes; ⌃Tab recent-thread switcher; names number only same-named threads, newest last
- Unseen finishes (v0.3.0): a turn that ends out of sight keeps its tick and gets the Quiet finish halo; Threads › Show Hachi When an Agent Finishes adds Hachi, the corner and ⌘J
- Codex: status (working, needs you on `PermissionRequest`, done) and `codex resume` through its own hooks, like Claude
- Idle shows the approved Torii gate (`docs/design/status/`) instead of the dashed ring
- Daily driver: threads are shells (⌘N instant, welcome screen); zsh integration for folder, commands and Claude hooks; `threads.json` save and restore with Claude resume and last-command prefill; shelf bars with Move Left / Right; rename, restart, close (⌘W, confirm while running)

## Terminal checklist

Run by hand with Claude Code in Shoji; re-run after every SwiftTerm bump (AGENTS invariant 1), and refresh `Sources/Shoji/ThirdPartyNotices.txt` from the package's LICENSE. Record findings in Gotchas.

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
- **Performance:** how many live terminal views before it matters? Do hidden threads
  keep a live view, or keep only SwiftTerm's headless `Terminal` and reattach a view?
- **Themes:** ship a few built-in themes, or import Ghostty/iTerm2 theme files?
- **Task restart:** SIGINT then relaunch, or SIGTERM with a timeout? Per task setting?
- **Git branch on Hub cards:** read `.git/HEAD` directly vs. shelling out to `git`.
- **Stable local signing identity:** a self-signed code-signing certificate (kept as a CI secret) would keep TCC grants across updates without a paid account. Worth it before daily use, or wait for Developer ID? Seen 2026-10-29: after installing v0.4.0, the Accessibility and Screen Recording access granted to the previous build was gone, so agents running in Shoji lost them until re-granted.
- **Multiple windows:** a thread's terminal can be on screen in only one window at a time (one SwiftTerm view per thread). When a second window opens it, move it there, or show only its card?
- **Sidebar window:** clicking a card opens the thread in a full window, or expands it in place?

## Decisions

- **Codex through its hooks, not `notify`** (2026-10-28). Codex (checked on 0.164) has Claude-style hooks with the same stdin fields, passed per launch as `-c hooks={…}`, so `~/.codex` stays untouched and the user's own `notify` isn't overridden. Cost: the user trusts Shoji's hooks once in `/hooks`.

- **`schemaVersion` only for unreadable shapes** (2026-10-29, user's OK; AGENTS invariant 9). Optional additions and ignored removals stay on the current version, so older and newer Shoji keep reading each other's files; v0.3 dropped `number` and added `pinnedThreadIds` and `resumeAgent` on version 1.

- **A finished turn you didn't see wants you** (2026-10-29, user's call, after Zed's unread dot). The user doesn't need to tell "needs my click" from "done, needs my check", so both call Hachi; the tick stays to show which. A menu toggle keeps the quiet tick for focused work. Refined by design (Quiet finish A, user's pick): orange stays with needs-you; an unseen finish gets ivory chrome and a soft halo whatever the toggle, which only decides Hachi, the corner and ⌘J.

- **Releases follow the version** (2026-10-28). Bumping `MARKETING_VERSION` in `project.yml` inside a PR is the decision to release; merging it makes `release.yml` build the DMG and publish `vX.Y.Z` with generated notes, creating the tag on that commit. Other merges don't release. No manual tags. Chosen over release-please / semantic-release (Conventional Commit titles, a bot PR, a changelog file) while Shoji has one maintainer; revisit if contributors join.

- **⌘K is a popup terminal** (2026-10-29, user's call; replaces the Spotlight-style field). A small terminal floats over the window a little above centre (40% of the free height above it, like Spotlight; level with the panes it read as one more pane): a fresh login shell with the zsh integration (so PATH and aliases match) in the focused thread's current folder, home if none. ⌘K again, ⌘W, a click outside or `exit` closes it; if a command is still running then, nothing is killed and the shell becomes a regular thread card beside the focused one. It doesn't jump to threads (⌃Tab and ⌘1–9 do). Built as `TerminalSessions.Popup`: its shell gets its future thread's id as `SHOJI_THREAD_ID` from the start, so a shell that joins the shelf keeps its terminal and its hooks line up; until then status reports are ignored (it isn't a thread). Menus call it Quick Terminal (File › Quick terminal in this folder). Chosen over a one-line field with a result toast because completion, aliases, colour output and interactive commands come free, and it reuses the terminal and thread code instead of adding a second way to run commands.

- **Reaching the user in the background** (2026-10-29): a Dock badge for an always-visible count, plus macOS notifications for the moment something happens (v0.4.0 also had a menu bar Hachi; see No menu bar item). Native notifications over Zed-style popups (Zed draws its own 450×72 window at the screen's top right with View / Dismiss): they follow Focus / Do Not Disturb, stay hidden while sharing the screen by default (a prompt like "Allow Tool: rm …" shouldn't show on a call), keep a history in Notification Center, and already wear Hachi as the app icon. Own popups stay an option if banners turn out too easy to miss, or for "Allow once" later. Every channel counts the same `wantsYou` set as Hachi: Show Hachi When an Agent Finishes decides whether unseen finishes count, and Notify Me When Shoji Is Away decides whether that set also reaches macOS notifications, so two toggles cover both events.

- **Options live in the Threads menu** (2026-10-29, user's call). A bottom section holds Show Hachi When an Agent Finishes and Notify Me When Shoji Is Away: one click each, lighter than a Settings window for two options (v0.4.0 also had an Open Folders In picker; see Editors are two menu items). They move to a Settings window (⌘,) when fonts, themes and the other Later settings arrive.

- **No menu bar item** (2026-10-29, user's call; v0.4.0 had a menu bar Hachi with a count and a menu of threads). The Dock badge, notifications and Hachi's corner already say who wants you, and a status item was one more thing in the menu bar for little gain. Removed in v0.4.1 with its view and asset; associated design files and references are also removed.

- **Quit asks only when something is busy** (2026-10-29, user's call). ⌘Q stops every shell, so it asks first, naming them, while a thread is working, needs you or runs a command (and the quick terminal runs one); an agent idle at its prompt doesn't count, since it resumes on relaunch. Otherwise it quits at once. `ThreadStore.busyThreads`, `AppDelegate.applicationShouldTerminate`.

- **Go-to glow** (2026-10-29, user's call). When a card click, ⌘1–9, ⌃Tab, ⌘J, Hachi or a notification moves focus to a pane already on screen, that pane glows ivory (`Palette.done`, the Quiet finish tone; orange stays for needs-you) for about 0.7 s, or shows a plain border for half a second with Reduce Motion. Not when the thread replaces your pane's (that change is visible) and not when you're already there. `ThreadStore.paneGlow`.

- **Open-source notices** (2026-10-29): SwiftTerm's MIT notice ships in the app as `ThirdPartyNotices.txt` and shows in the About panel's credits, under the full name Hachi no Shoji.

- **Agents go by their topic** (2026-10-29, user's call). A thread running an agent is named by the agent's own terminal title (Claude's topic) unless you renamed it, so the card's subtitle can always show the folder it works in. A title that only names the agent or repeats its command line ("Claude Code", "codex resume …") doesn't count, and the topic goes when the agent exits or another command starts. The one exception: while an agent needs you, the subtitle shows its question. `ThreadStore.name(of:)` applies it everywhere (cards, pane headers, menus, ⌃Tab, notifications).

- **No pins** (2026-10-29, user's call; v0.3 had them). A click only replaces the pane you're in (or, with none focused, the least recently used one), so other panes never change behind your back and a pin only guarded your own pane from you. Splits and Close Pane give that control directly. Old files' `pinnedThreadIds` are ignored.

- **Quiet chrome** (2026-10-29, user's call): glass stays on surfaces (shelf, cards, pane headers) but not on small controls inside them. Pane header buttons appear only on hover, and the layout switcher leaves the window (presets live in the Panes menu).

- **Panes are splits** (2026-10-29, user's call; replaces the four fixed layouts). A binary split tree, each split an axis and a ratio, like Ghostty. Its leaves in reading order are the pane order the v0.3 rules already use (a click goes to a thread, ⌥-click brings it here, the least recently used pane that doesn't want you), so those rules carry over. Split from the header's Split menu (Right, Left, Down, Up), ⌘D (right) or ⇧⌘D (down), or drop a card on the edge band of a pane, with a preview of the half it will take; dropping in the middle still swaps. A split from the menu or keys shows the most recent thread that isn't on screen (⌃Tab order), else a new shell in that pane's folder, and takes focus, so one click on a card replaces it; a dropped card shows that thread. Close Pane (Split menu, right-click on the header) removes the pane and keeps its thread running on the shelf; closing a thread (⌘W) closes its pane the same way, and the sibling takes the space. The last pane stays and shows the next recent thread. Dragging a gap resizes that split; double-click evens it. A split that would leave a pane too small to use is refused. the Panes menu (⌥⌘1–4) snaps the panes into single, two columns, three panes or a grid of four, keeping the focused pane and filling from recents as v0.3's layout switch did. `threads.json` gains the tree as an additive field (schema stays 1) and keeps writing the nearest preset and pane order, so v0.3 still opens it.

- **Threads are shells** (2026-10-28, user's call). A thread no longer has a fixed command or an agent/task kind: it's the user's login shell, and the card reflects what runs in it. Quitting an agent returns to the prompt, `cd` replaces a folder picker, and the old Agents | Tasks split became user-placed bars.

- **Name:** the app is **Shoji** (Dock, menus, repo, bundle id, code); **Hachi no Shoji** (ハチの障子) is the full name for places with room for the story, like the README header and an About box.
- **Bundle id `fi.yan.shoji`**, ad-hoc signed until there's a Developer ID. Debug builds are `fi.yan.shoji.debug` (shown as Shoji Debug), so notifications, their permission, Launch Services and UserDefaults never mix the two up.
- **The `.xcodeproj` is generated and not committed**; `project.yml` is the only source. Package.resolved therefore isn't committed either; SwiftTerm itself is pinned exactly.
- **Shift+Return → ESC CR** (Meta+Return, a newline in Claude Code) for every thread whose program hasn't enabled the Kitty keyboard protocol.
- **Shortcuts sheet on ⌘/** (the user suggested ⌘K): ⌘K is "clear" in every Mac terminal and is reserved for the ⌘K popup terminal. It's a real sheet, not an overlay, so Esc closes it without reaching the focused terminal (Esc would interrupt Claude).
- **Text size and interface size are separate** (2026-10-29, user's call; until v0.4.0 one zoom scaled both). ⌘+ / ⌘− / ⌘0 step the terminal text through `TextZoom.levels` (75–200%, UserDefaults `zoom`, so the old zoom carries over as the text size); View › Interface Size (Small 85%, Default, Large 115%, Extra Large 130%; `interfaceSize`) scales the chrome through `@Environment(\.zoom)`. A thread can sit levels away from the others (⌥⌘+ / ⌥⌘−, ⌥⌘0 back in line; the pane's right-click › Text Size): `ShojiThread.textSteps`, saved in `threads.json`, so ⌘− takes a 100% / 80% pair to 90% / 70%. A pane that differs shows its size in the header. Terminal font = 13 pt × level, rounded to half points.

- **Menus: Threads, Panes, View** (2026-10-29, user's call). Threads: the cards (⌘1–9), getting to a thread (⌘J, ⌃Tab), Open in VS Code / Zed and the two options. Panes: focus, split, close, maximize and the four layouts (⌥⌘1–4), inline. View: how things look, Interface Size inline with checkmarks, terminal text sizes, full screen. No submenus; Title Case titles from the one `Shortcut` catalog, with sheet-only extra words in `hint`.

- **Editors are two menu items** (2026-10-29, user's call; v0.4.0 had a picker and ⇧⌘E). Open in VS Code (⌥⇧⌘E), then Open in Zed (⇧⌘E), each only when installed, in the pane and card right-click menus and the Threads menu (focused thread; the shortcuts live there only).
- **Terminal engine: SwiftTerm** (chosen over libghostty). Pure Swift package, no Zig
  build, stable versioned API, Metal renderer, Kitty keyboard and graphics protocols,
  runs on iOS too, MIT license (compatible with Shoji's Apache 2.0). Accepted costs:
  less battle-tested than Ghostty, themes/fonts are ours to build, Claude Code needs the
  setup rules in AGENTS.md. Fallback: libghostty behind the same `TerminalBackend`.
