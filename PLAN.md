# PLAN.md — Shoji

The current state of Shoji: what's next, what to watch out for, and why things are the way they are. Not a history; git and the GitHub releases keep that.

## Status

- **Released:** v0.5.0. **In progress (`hub`, v0.6.0):** the Hub (⇧⌘H) and mini cards, with design's polish on the Hub, mini cards, pane headers, drop previews and ⌘K. 78 tests.
- **Next up:** the user tries the Hub on real threads (the Hub checks in Now), then merges, publishing v0.6.0.
- **Blockers:** none.

_Agents: update Status and Tasks at the end of every session; record decisions and gotchas as they stand now, not how they got there._

## Tasks

Priorities follow the user's wishes. Keep items one line, small enough for one PR.

### Now (the user's checks)
- [ ] Hub: ⇧⌘H and the Torii button; no pane shows through and typing reaches no terminal; Esc returns to your pane; a card click, ⌘1–9, ⌘J, Hachi or a notification opens the thread; Esc in ⌘K over the Hub reaches the shell
- [ ] Hub cards on real threads: the last lines skip Claude Code's and Codex's input box and footer (else tune `Excerpt`), the git branch shows, a working agent names its last tool
- [ ] Mini cards: card menu › Mini Card; the name reads top to bottom in the subtitle's style; dragging, drops, ⌘ numbers (in the left margin) and the needs-you glow still work
- [ ] From design's review, natively: Interface Size 85–130% at window widths near 740 and 1360, compact and ⌘K at 480 pt; VoiceOver, Full Keyboard Access (pane header controls show while focused), Increase Contrast, Reduce Transparency, Reduce Motion; a card dragged to a pane edge previews only a split that would happen
- [ ] The terminal checklist below
- [ ] Room light: no seam at the terminal's margin; all panes solid with Reduce Transparency
- [ ] Compact form: Split View beside a full-screen Zed or Chrome, narrow below 680 pt and back above 720 without flicker; the dropdown (shelf order, bars as separators, status) picks and swaps rows, New Thread; ⇧⌘D adds a row, ⌘D and ⌥⌘2–4 are off; the full layout comes back intact
- [ ] Full form: the hover chevron beside a pane's name opens the same dropdown; double-clicking the name still maximizes
- [ ] Holding ⌘ shows 1–9 on the first nine cards after a moment; ⌘C, ⌘N and other quick shortcuts don't flash them
- [ ] Notifications: none while Shoji is visible (Split View), one when it's on another Space; Dock badge at 10 or more
- [ ] Not yet seen: a screenshot dragged from Finder onto Claude Code, Open in VS Code / Zed, Codex resuming after quit and reopen, the go-to glow, ⌘Q's busy list, the About panel

### Next
- [ ] Design: bring `hub.html` up to the shipped Hub, and settle a full card's ⌘ number beside the previous card's count badge, which reads as one number ("9+ 2") (app-to-design handoff)

### Later
- [ ] "Allow once" from the Hub (see Open questions)
- [ ] Hub: a running command's listening ports (libproc on the shell's children) with Open in Browser
- [ ] Developer ID signing and notarization (needs a paid Apple Developer account)

### Parked
Only when the user asks.
- [ ] Workspaces (named sets of threads): shelf bars already group threads
- [ ] Devcontainers and SSH: presets, and status from agents that can't reach the host socket (a localhost TCP listener with a per-launch token via `host.docker.internal`, or a mounted socket)
- [ ] bash / fish integration: zsh is macOS's default and the user's shell
- [ ] opencode status and resume: no Claude-style hooks; it takes in-process JS plugins (`session.status`, `permission.asked`, `session.idle`), likely a small plugin loaded through `OPENCODE_CONFIG_DIR` forwarding to `shoji-hook`, with `--standalone` per thread to tell threads apart. Prototype first

## Product

A calm command center for the terminals the user already runs all day. Claude Code and Codex stay plain CLIs on their subscriptions; Shoji organizes them, shows what each needs, and gets the user there in one step. Not an editor, diff viewer, file browser or agent client.

### The window
- **One window, two forms, by width** (the Split View divider sets it): full above 720 pt, compact below 680, unchanged in between so a drag doesn't flicker; the window goes down to 480 pt (about 60 columns). Each form keeps its own panes; closing a thread removes it from both.
- **Full form:** no title bar; the shelf shares the top row with the window buttons, Hachi's corner below them (empty until something needs you; a click opens it). Panes fill the rest.
- **Compact form** (made for Split View beside a full-screen editor or browser): no shelf; a slim strip with Hachi beside the window buttons; one column of one or two rows. The first visit shows your thread; ⇧⌘D adds the second row; ⌘D and ⌥⌘2–4 are off.
- **Room light:** panes are `Palette.paneOpacity` (80%) opaque with no blur, so the backdrop tints them, cool on the left and warm on the right; text, caret, selections and coloured cells stay opaque. The quick terminal stays solid, and Reduce Transparency makes every pane solid.

### Shelf and cards
- Glass cards in the user's order, split into groups by plain bars (no titles, no fixed meaning); scrolls sideways when full. Drag a card onto another to place it before or after (by half); the card menu also has Move Left / Right and Add / Remove Bar Before.
- Card: status icon, a tag for what runs (CLAUDE / CODEX / the command's name), name, subtitle, elapsed time; the full folder as a tooltip.
- **Name:** your rename, else a running agent's topic (its terminal title, unless that only names the agent or repeats its command line), else the folder's name, numbered ("shoji 2") only when two threads would read the same, the newer one getting the number. **Subtitle:** the folder; a plain command's command line; an agent's question while it needs you.
- **Mini card** (card menu › Mini Card, full form): 44 pt wide, the status icon over the name in the subtitle's style, reading top to bottom; the glow, count badge (9+ above nine) and drops still work, the ⌘ number sits in the left margin, and the tooltip has the rest.
- Needs-you card: orange border and glow, count badge, Hachi. A turn that finishes unseen keeps its tick with ivory chrome and a soft halo; Threads › Show Hachi When an Agent Finishes also brings Hachi, the corner and ⌘J.

### Panes
- A split tree: split right, left, down or up from the header's Split menu, its right-click menu, ⌘D / ⇧⌘D, or a card dropped on a pane's edge (the half it takes is previewed, only where that split is allowed); the middle of a pane swaps. A new split shows your most recent thread that isn't on screen, else a new shell in that folder. Drag a gap to resize, double-click it to even. Splits that would leave a pane under 320×160 are refused. Panes › ⌥⌘1–4 snaps to one, two columns, three (one tall left) or a grid, keeping your pane and filling from recent threads.
- **Going to a thread** (card click, ⌘1–9, ⌃Tab, ⌘J, Hachi, a notification): on screen, it just takes focus and glows ivory briefly; otherwise it opens in your pane (with none focused, the least recently used one that isn't waiting for you). Other panes never change behind your back. ⌥-click or Show in This Pane brings it to your pane; dropping a card, or picking it from a pane's dropdown, puts it in that pane, trading places if it's on screen.
- **Pane header:** status, name, folder (giving way to the name when narrow); on hover, or while one has keyboard focus, a chevron (the thread dropdown: the shelf's cards with status, then New Thread), Split and Maximize, whose space is kept so the name never moves. Double-click maximizes; Restart once the shell has ended. In the compact form the name itself is the dropdown.
- Close Pane keeps the thread on the shelf; ⌘W closes the thread (asking while something runs). The last pane stays and shows your next recent thread.
- Files or text dropped on a pane paste into its terminal (files as escaped paths, like Terminal).

### Getting around
- Hold ⌘ on its own for a moment and the first nine cards show their ⌘1–9 number; any key or leaving Shoji hides them.
- ⌃Tab / ⌃⇧Tab: recent threads like ⌘Tab; a tap returns to the previous one, holding ⌃ shows the list, Esc cancels.
- ⌘K: a quick terminal over the window, a little above centre, in the focused thread's folder. ⌘K, ⌘W, a click outside or `exit` closes it; a command still running then becomes a thread beside the focused card. When narrow, its hint takes a second line.
- Menus: **Threads** (cards ⌘1–9, ⌘J, ⌃Tab, Open in VS Code ⌥⇧⌘E / Zed ⇧⌘E, the two options), **Panes** (focus, split, close, maximize, layouts), **View** (Hub ⇧⌘H, Interface Size, text sizes). No submenus; titles come from the `Shortcut` catalog, which also feeds the ⌘/ sheet.
- **Sizes:** ⌘+ / ⌘− / ⌘0 step the terminal text (50–200%); View › Interface Size scales the chrome (85–130%); ⌥⌘+ / ⌥⌘− / ⌥⌘0 keep one thread levels apart from the rest.
- **Reaching you:** Hachi's corner and count, the Dock badge, and macOS notifications while Shoji's window is out of sight (another Space, minimized or covered). All count the same threads; Threads › Notify Me When Shoji Is Away turns notifications off.
- ⌘Q asks only when something is busy (working, needs you, running a command, or the quick terminal running one), naming it.

### Hub
- ⇧⌘H or the Torii at the top right (brighter while the Hub shows), full form only (narrowing the window leaves it). It covers the panes, which stay hosted underneath with no terminal holding the keyboard; Esc, a card click or any go-to returns to Threads. ⌘W is off there, since the focused thread is out of sight.
- Top row: Hachi, the thread count, and pills for needs you (a click is ⌘J), finished unseen, working, running and failed; when they don't fit, the pills wrap onto rows below and the Torii stays put.
- Small cards (from 320 pt, about four across) in shelf order, bars as section breaks, all one height. Each card: status, name and status pill; tag, folder and git branch, elapsed time; one line from hooks or the shell (the question, the agent's last tool, the command, the failure; none while idle, where the screen gets its room); the last 3 lines of its screen (5 when idle), skipping an agent's input box and footer; a last row with Open Maximized, Restart once the shell has ended and Hachi when it wants you, then Finder, VS Code and Zed at the end. A click on the card opens the thread; right-click is the card menu.
- Visual reference: `docs/design/hub.html`.

## Architecture

```
┌──────────────────────── Shoji.app (SwiftUI) ────────────────────────┐
│  UI: shelf · panes · Hachi                                          │
│        ▲ observes                                                   │
│  ThreadStore (@MainActor @Observable) ◄── StatusEvent ──┐           │
│        │ saves                                          │           │
│  threads.json                                           │           │
│  Terminal/SwiftTerm ── title, bell, exit, shell reports ┤           │
│  Status/HookServer ◄── shoji-hook ◄── CLI hooks ────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

Files live in `~/Library/Application Support/Shoji` (`Shoji-Debug` for Debug builds): `threads.json`, saved half a second after a change and on quit, and `hook.sock`. A `threads.json` Shoji can't read (corrupt or newer) is renamed `threads.unreadable-<time>.json`, never overwritten.

### `threads.json`

```json
{
  "schemaVersion": 1,
  "threads": [
    { "id": "6F1C…", "title": "auth-refactor", "folder": "~/code/app", "group": 0, "order": 0,
      "command": "claude", "resumeId": "abc123…", "resumeAgent": "claude", "textSteps": -1, "isMini": true }
  ],
  "layout": { "root": { "pane": { "id": "6F1C…" } }, "mode": "single", "openThreadIds": ["6F1C…"] },
  "compactLayout": { "root": { "pane": { "id": "6F1C…" } } }
}
```

- `title`, `textSteps` and `isMini` are optional; `folder` follows the shell; `group` / `order` place the card. The array is in creation order, which decides who gets the number among same-named threads.
- `command` is what ran at the last save and `resumeId` its agent session, `resumeAgent` naming the CLI: a relaunch runs `claude --resume <id>` or `codex resume <id>` at the first prompt, or leaves `command` at the prompt for Return.
- `layout.root` is the split tree; `mode` and `openThreadIds` are still written for older Shoji, and read when `root` is missing. `compactLayout` is optional. Unknown keys are ignored.
- Runtime only: status, activity, agent, terminal views, which form is showing, the Hub.

### Status

| State | Source |
|---|---|
| Idle | at the prompt (launched, or a command ended with 0 / 130); Claude at its own prompt; Done or a failed command once focused |
| Running | a command other than claude / codex (zsh `preexec`) |
| Working | Claude or Codex `UserPromptSubmit` / `PostToolUse` (which also names the tool for the Hub); typing into a needs-you thread |
| Needs you | Claude `Notification` (not `idle_prompt`); Codex `PermissionRequest`; bell while working |
| Done | Claude or Codex `Stop`; Codex `Interrupt`. Unseen when it lands outside the focused pane or while Shoji is in the background |
| Exited(code) | a command failed (clears on focus), or the shell ended (Restart) |

Shell reports from the zsh integration: `cwd;<path>` each prompt, `cmd;<line>` before a command, `done;<code>` after it. Hook transport: `shoji-hook` opens one connection per event to `hook.sock`, the thread id on the first line, then the CLI's JSON.

## Gotchas

- **Login shell must be interactive too** (`$SHELL -l -i -c 'exec …'`), or PATH from `.zshrc` (nvm, where `codex` lives) is missing.
- **zsh integration hooks in on the first prompt**, after `.zshrc`, with its precmd first so `$?` is the command's; a `.zshrc` that resets `precmd_functions` disables it. Typed `claude` / `codex` get hooks through its functions (aliases work); scripts calling the binary directly get none.
- **Claude `Notification` with `idle_prompt`** fires about 60 s after a finished turn; it's ignored so Done doesn't turn into Needs you.
- **No hook fires between approving a permission and the tool finishing**, so typing into a needs-you thread counts as the answer (→ Working).
- **Resume ids come from `UserPromptSubmit` / `PostToolUse`**, not `SessionStart`, which also fires for sessions that can't be resumed.
- **Codex hooks need the user's trust once** in `/hooks` (keyed by their hash; Debug and installed builds separately). Keep `CodexHooks` stable, never pass `--dangerously-bypass-hook-trust`; `codex debug prompt-input -c '…'` checks an override without a model call. `Stop` / `Interrupt` expect JSON when a hook prints; `shoji-hook` prints nothing.
- **Darwin `accept()` inherits `O_NONBLOCK`** from the listener; `HookServer` clears it.
- **Hook socket paths are capped at 104 characters.** A support folder under a long path (a scratchpad, a demo home) silently leaves Shoji without hooks.
- **A restarted terminal's old process still reports its exit**; `TerminalSessions` ignores events from a backend that's no longer the thread's.
- **Focus requests must settle.** `SwiftTermBackend.focus()` reports `.focused` itself when the view already has focus; `TerminalHost` acts only when a request arrives, so a stale one can't pull typing back; clicks focus in `ShojiTerminalView.mouseDown`.
- **Terminals keep their size and their host.** Never size one to zero (TUIs redraw badly); `TerminalContainer` keeps the last real size. `PaneGrid` places one `PaneView` per thread by frame, at the same place in both forms, so layout changes don't re-host terminals.
- **A translucent terminal stacks with whatever is behind it.** SwiftTerm paints its own background at `backgroundOpacity`, so `PaneView` fills only the margin around it (an even-odd `Margin`). Never set the terminal's background to 0 and let SwiftUI draw it: the IME overlay and whole-screen reverse video use that colour.
- **The Hub hides the panes, it doesn't remove them.** `PaneGrid` stays at opacity 0 underneath so terminals keep their host and size, and `MainView` takes first responder from the terminal. `focusRequest` and `showsHub` clear each other: asking for a pane's focus leaves the Hub, closing a thread from it doesn't. Esc is a key equivalent there, off while ⌘K is open.
- **The Hub's lines come from the live screen:** `terminalContentSnapshot(region: .history(maximumScrollbackRows: -1))`, whatever the user scrolled to (`visibleRowsText` and `getLine(row:)` follow the scroll). Display only; `Excerpt` cuts at the first box-drawing rule in the last 12 non-blank rows (an agent's input box).
- **Inside a `GlassEffectContainer`, overlays added after `.glassEffect` draw under the glass.** Put borders and badges first.
- **Hidden title bar:** content ignores the top safe area; the leading 78 pt stays clear for the window buttons; the window drags by its background.
- **⌃Tab is a local key monitor** (`RecentSwitchKeys`), since the switcher needs ⌃'s release and the keys must not reach the terminal; it stands down while a sheet or alert is up. The ⌘ card numbers (`CardNumberKeys`) watch the same events but never consume them; ⌘Tab's Tab never reaches the app, so the numbers can show under the app switcher until Shoji goes inactive.
- **⌘W is Close Thread:** `ShojiCommands` replaces `.saveItem`, which also removes Close Window.
- **`NSApp` is nil during `ShojiApp.init`.** `Notifier` waits for `didFinishLaunchingNotification`; tests never build it, so launch the Debug app after changing launch wiring.
- **Debug notifications** ask once as "Shoji Debug" and post nothing while its window is in sight. `scripts/shoji-hook` with `SHOJI_THREAD_ID` and `SHOJI_SOCKET` raises needs-you without an agent.
- **One Debug Shoji at a time:** a second instance takes over `hook.sock`, and both write `threads.json`.
- **A blank icon in ⌘Tab or the Dock is a stale icon cache:** `touch` the app bundle and `lsregister -f` it, then relaunch.
- **Icon Composer:** XcodeGen adds `AppIcon.icon` as one `wrapper.icon` file, compiled with `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Check renders with `ictool <file>.icon --export-image --platform macOS --rendition Default|Dark|ClearLight|TintedDark …`.
- **Visual checks without the live app:** `ImageRenderer` in a throwaway test renders SwiftUI views (glass flat, terminals absent).
- **AX `set value` on a SwiftUI text field reaches its binding only when editing ends;** move focus before pressing a button.
- **Ad-hoc signing:** a downloaded DMG is quarantined (Privacy & Security › Open Anyway, or `xattr -dr com.apple.quarantine`), and macOS privacy grants reset with every update. App Sandbox stays off (Shoji spawns shells).
- **CI:** the test report comment is found by its `<!-- shoji-test-report -->` first line; fork PRs only get the run summary. Runs on the `xcode-27` label (preview) until a GA label exists. Tags pushed with `GITHUB_TOKEN` trigger no workflows, so `release.yml` tags and releases in one run.
- **Reference app:** TermQ (open source, SwiftTerm, runs Claude Code) is a good source of fixes; it uses tmux, which Shoji does not.

## Terminal checklist

Run by hand with Claude Code in Shoji after every SwiftTerm bump (AGENTS invariant 1), and refresh `Sources/Shoji/ThirdPartyNotices.txt` from the package's LICENSE.

- [ ] Shift+Enter inserts a newline; Option+Enter works with Option as Meta
- [ ] Long reply and scrolling up: no drift, the wheel scrolls (no stray keystrokes)
- [ ] Heavy output (`docker compose up`) stays responsive
- [ ] Same PATH, environment and MCP servers as a normal terminal
- [ ] ⌘-click opens URLs and file paths
- [ ] IME input, copy and paste, selection, emoji and wide characters
- [ ] Window resize and focus switching between panes are smooth

## Open questions

- **Allow once:** for any prompt, or only commands approved before? Proposal: only when the prompt is visible on the card, sending exactly the shown keystroke.
- **Performance:** how many live terminal views before it matters? Keep only SwiftTerm's headless `Terminal` for hidden threads?
- **Stable local signing identity:** a self-signed certificate (a CI secret) would keep privacy grants across updates without a paid account. Now, or wait for Developer ID?

## Decisions

- **Threads are shells.** No fixed command or kind: the card reflects what runs in the user's login shell; bars, not categories, group them.
- **SwiftTerm** over libghostty: a Swift package, Metal, Kitty protocols, MIT. Its gaps are ours (themes, Claude Code setup rules); libghostty stays the fallback behind `TerminalBackend`.
- **Status through each CLI's own hooks,** injected per launch (`--settings`, `-c hooks={…}`), never the user's config or Codex's `notify`.
- **Other panes never change behind your back.** A click only ever replaces your pane; splits, drops and the pane dropdown give exact control.
- **An unseen finish wants you** like a question does; ivory, not orange, so the two stay apart.
- **One window, two forms, by width,** because Split View sets the width; the green button stays macOS's.
- **Room light:** 80% opaque, never blurred; at 90% the backdrop barely moved the colour. More transparency or blur would cost contrast and show colours that mean status.
- **The Hub follows the shelf:** shelf order with bars as breaks, not attention order or an Agents / Tasks split, so cards stay put and match ⌘1–9; needs-you cards stand out anyway.
- **You stop processes yourself:** no Stop or command Restart buttons; ⌃C in the terminal and Close Thread (which asks) are the ways. Restart is only for a shell that has ended.
- **Git branch from `.git/HEAD`** (worktrees too), never a `git` process.
- **Options are one-click menu items;** there's no Settings window. A wish that would need one gets a menu item or isn't built.
- **Quiet chrome:** glass on surfaces, never on small controls (the Torii and a Hub card's buttons are bare); pane controls appear on hover.
- **Native notifications** over own popups: they follow Focus and screen sharing and keep a history.
- **⌘K is a popup terminal**, not a command field: completion, aliases and interactive commands come free. ⌘/ shows shortcuts, as a sheet so Esc never reaches a terminal.
- **`schemaVersion` only for shapes another Shoji can't read;** optional additions stay on version 1 (AGENTS invariant 9).
- **Releases follow the version:** bumping `MARKETING_VERSION` in a PR is the decision; merging publishes `vX.Y.Z` with its DMG.
- **Names and ids:** the app is Shoji, *Hachi no Shoji* (ハチの障子) where there's room for the story. `fi.yan.shoji`, Debug `fi.yan.shoji.debug` (Shoji Debug), so the two never share notifications or settings. The `.xcodeproj` and `Package.resolved` aren't committed; `project.yml` is the source.
