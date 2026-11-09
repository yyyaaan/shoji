# PLAN.md — Shoji

The current state of Shoji: what's next, what to watch out for, and why things are the way they are. Not a history; git and the GitHub releases keep that.

## Status

- **Released:** v0.8.0: Reopen Closed (⇧⌘T), the compact form starting from the right edge, mini cards without the idle Torii, cards that keep their state when reordered.
- **In progress (`no-pane-close-on-cmd-w`, v0.8.1):** a closed thread leaves its pane empty, with a picker; ⌘W again closes the pane.
- **Next up:** the user's checks under Now, then merge.
- **Blockers:** none.

## Tasks

Priorities follow the user's wishes. Keep items one line, small enough for one PR.

### Now (the user's checks)
- [ ] Empty pane: ⌘W (or Close Thread on a card) leaves the pane with a centred picker (threads not on screen, shelf order, status and folder, bars as separators; New Thread; Close Pane at the bottom, not on the last pane). It has the keyboard at once: ↑ ↓ and Return pick, a click too; ⌘1–9, ⌘J, ⌃Tab, a card click or a card dropped on it fill it; ⇧⌘T puts the closed thread back in it; ⌘W closes it, off on the last pane. Also in compact rows, maximized, after ⌘K closes and after a relaunch
- [ ] Hub cards on real threads: the last lines skip Claude Code's and Codex's input box, footer and spinner, and the reply shows (else tune `Excerpt`)
- [ ] Accessibility sweep: Interface Size 85–130% at widths near 740 and 1360, compact and ⌘K at 480 pt; VoiceOver, Full Keyboard Access, Increase Contrast, Reduce Transparency, Reduce Motion
- [ ] Not yet seen: a screenshot dragged from Finder onto Claude Code, Codex resuming after quit and reopen, ⌘Q's busy list
- [ ] The terminal checklist below, at the next SwiftTerm bump

### Next
No tasks pending; new wishes go here.

### Later
- [ ] "Allow once" from the Hub (see Open questions)
- [ ] Hub: a running command's listening ports (libproc on the shell's children) with Open in Browser

### Parked
Only when the user asks.
- [ ] Devcontainers and SSH: status from agents that can't reach the host socket (a localhost TCP listener with a per-launch token via `host.docker.internal`, or a mounted socket)
- [ ] opencode status and resume: no Claude-style hooks; likely a small JS plugin through `OPENCODE_CONFIG_DIR` forwarding to `shoji-hook`

## Product

A calm command center for the terminals the user already runs all day. Claude Code and Codex stay plain CLIs on their subscriptions; Shoji organizes them, shows what each needs, and gets the user there in one step. Not an editor, diff viewer, file browser or agent client.

### The window
- **One window, two forms, by width** (the Split View divider sets it): full above 720 pt, compact below 680, unchanged in between so a drag doesn't flicker; the window goes down to 480 pt (about 60 columns). Each form has its own panes.
- **Full form:** no title bar; the shelf shares the top row with the window buttons, Hachi's corner below them (empty until something needs you; a click opens it), and a column at the top right: the lantern (Hub), the stones (a new thread in a folder) and the bamboo (⌘K). Panes fill the rest.
- **Compact form** (made for Split View beside a full-screen editor or browser): no shelf; a slim strip with Hachi beside the window buttons; one column of one or two rows. Each time the window narrows it starts from the full layout's right edge: the bottom two panes of its right-hand column, else its last two panes (not saved). ⇧⌘D adds a second row; ⌘D and ⌥⌘2–4 are off.
- **Room light:** panes are `Palette.paneOpacity` (80%) opaque with no blur, so the backdrop tints them, cool on the left and warm on the right; text, caret, selections and coloured cells stay opaque. The quick terminal stays solid, and Reduce Transparency makes every pane solid.

### Shelf and cards
- Glass cards in the user's order, split into groups by plain bars (no titles, no fixed meaning); scrolls sideways when full. Drag a card onto another to place it before or after (by half); the card menu also has Move Left / Right and Add / Remove Bar Before.
- Card: status icon, a tag for what runs (CLAUDE / CODEX / the command's name), name, subtitle, elapsed time; the full folder as a tooltip.
- **Name:** your rename, else a running agent's topic (its terminal title, unless that only names the agent or repeats its command line), else the folder's name, numbered ("shoji 2") only when two threads would read the same, the newer one getting the number. **Subtitle:** the folder; a plain command's command line; an agent's question while it needs you.
- **Mini card** (card menu › Mini Card, full form): 44 pt wide, the status icon (none while idle) over the name in the subtitle's style, reading top to bottom; the glow, count badge (9+ above nine), drops and the ⌘ badge work as on a full card. Hovering a moment shows the full name and the subtitle under the card.
- Needs-you card: orange border and glow, count badge, Hachi. A turn that finishes unseen keeps its tick with ivory chrome and a soft halo; Threads › Show Hachi When an Agent Finishes also brings Hachi, the corner and ⌘J.

### Panes
- A split tree: split right, left, down or up from the header's Split menu, its right-click menu, ⌘D / ⇧⌘D, or a card dropped on a pane's edge (the half it takes is previewed, only where that split is allowed); the middle of a pane swaps. A new split shows your most recent thread that isn't on screen, else a new shell in that folder. Drag a gap to resize, double-click it to even. Splits that would leave a pane under 320×160 are refused. Panes › ⌥⌘1–4 snaps to one, two columns, three (one tall left) or a grid, keeping your pane and filling from recent threads.
- **Going to a thread** (card click, ⌘1–9, ⌃Tab, ⌘J, Hachi, a notification): on screen, it just takes focus and glows ivory briefly; otherwise it fills an empty pane (yours first), else opens in your pane (with none focused, the least recently used one that isn't waiting for you). Other panes never change behind your back. ⌥-click or Show in This Pane brings it to your pane; dropping a card, or picking it from a pane's dropdown, puts it in that pane, trading places if it's on screen.
- **Pane header:** status, name, folder (giving way to the name when narrow); on hover, or while one has keyboard focus, a chevron (the thread dropdown: the shelf's cards with status, then New Thread), Split and Maximize, whose space is kept so the name never moves. Double-click maximizes; Restart once the shell has ended. In the compact form the name itself is the dropdown.
- Close Pane keeps the thread on the shelf; ⌘W closes the thread (asking while something runs) and leaves its pane **empty**: a centred picker of the threads not on screen (shelf order, bars as separators), New Thread, and Close Pane at the bottom. ↑ ↓ and Return pick; a go-to or a card dropped anywhere on it fills it; ⌘W there closes the pane. The last pane always stays. Empty panes are saved with the layout; the other form just loses the closed thread's pane. ⇧⌘T reopens the latest close this session, newest first: a pane goes back to its spot (the same tree if nothing changed since, else split beside its old neighbour); a thread gets its card place and pane back (the same tree, else the pane it left empty, else beside its old neighbour) and relaunches like after a quit, its agent resumed and a command left at the prompt. Its scrollback is gone. Closing an empty pane isn't reopened.
- Files or text dropped on a pane paste into its terminal (files as escaped paths, like Terminal).

### Getting around
- Hold ⌘ on its own for a moment and the first nine cards show their ⌘1–9 number as a badge over their top-leading corner; any key or leaving Shoji hides them.
- **Stones** (under the lantern): the folders inside one you choose, home until you do (Choose Folder to List… in the same menu, remembered; hidden folders and app bundles left out). Picking one opens a new thread there, after your card.
- ⌃Tab / ⌃⇧Tab: recent threads like ⌘Tab; a tap returns to the previous one, holding ⌃ shows the list, Esc cancels.
- ⌘K or the bamboo: a quick terminal over the window, a little above centre, in the focused thread's folder. ⌘K, ⌘W, a click outside or `exit` closes it; a command still running then becomes a thread beside the focused card. When narrow, its hint takes a second line.
- Menus: **Threads** (cards ⌘1–9, ⌘J, ⌃Tab, Open in VS Code ⌥⇧⌘E / Zed ⇧⌘E, the two options), **Panes** (focus, split, close, maximize, layouts), **View** (Hub ⇧⌘H, Interface Size, text sizes). No submenus; titles come from the `Shortcut` catalog, which also feeds the ⌘/ sheet.
- **Sizes:** ⌘+ / ⌘− / ⌘0 step the terminal text (50–200%); View › Interface Size scales the chrome (85–130%); ⌥⌘+ / ⌥⌘− / ⌥⌘0 keep one thread levels apart from the rest.
- **Reaching you:** Hachi's corner and count, the Dock badge, and macOS notifications while Shoji's window is out of sight (another Space, minimized or covered). All count the same threads; Threads › Notify Me When Shoji Is Away turns notifications off.
- ⌘Q asks only when something is busy (working, needs you, running a command, or the quick terminal running one), naming it.

### Hub
- ⇧⌘H or the lantern at the top right (brighter while the Hub shows), full form only (narrowing the window leaves it). It covers the panes, which stay hosted underneath with no terminal holding the keyboard; Esc, a card click or any go-to returns to Threads. ⌘W is off there, since the focused thread is out of sight.
- Top row: Hachi, the thread count, and pills for needs you (a click is ⌘J), finished unseen, working, running and failed; when they don't fit, the pills wrap onto rows below and the corner column stays put. With no pill to show, a bonsai and "All quiet".
- Small cards (from 320 pt), all one height, in shelf order: groups run left to right like the shelf, each a column read top to bottom, with a full-height bar between groups. Spare columns go to the tallest group, as many as it takes to lose a row; with more groups than fit, the Hub also scrolls sideways. Each card: status, name and status pill (none while idle); tag, folder and git branch, elapsed time; one line from hooks or the shell (the question, the agent's last tool, the command, the failure; none while idle, where the screen gets its room); the last 2 lines of its screen (4 when idle), skipping an agent's input box, footer and the two lines above the box; a last row with Open Maximized, Restart once the shell has ended and Hachi when it wants you, then Finder, VS Code and Zed at the end. A click on the card opens the thread; right-click is the card menu.
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
  "layout": { "root": { "pane": { "id": "6F1C…" } }, "mode": "single", "openThreadIds": ["6F1C…"] }
}
```

- `title`, `textSteps` and `isMini` are optional; `folder` follows the shell; `group` / `order` place the card. The array is in creation order, which decides who gets the number among same-named threads.
- `command` is what ran at the last save and `resumeId` its agent session, `resumeAgent` naming the CLI: a relaunch runs `claude --resume <id>` or `codex resume <id>` at the first prompt, or leaves `command` at the prompt for Return.
- `layout.root` is the split tree, panes named by their thread's id; an id that is no thread's is an empty pane. `mode` and `openThreadIds` are written for older Shoji and read when `root` is missing. Unknown keys are ignored.
- Runtime only: status, activity, agent, terminal views, which form is showing and the compact form's panes, the Hub, what ⇧⌘T can reopen.

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
- **The mini card peek is an overlay, not a popover:** a transient popover swallows the click that closes it, so the card would need two clicks. `ThreadCard` raises a `MiniPeek` anchor preference and `MainView` draws it, not hit-testable.
- **Cards are one flat `ForEach` keyed by thread**, on the shelf (a bar drawn beside the card after it) and in the Hub (the `HubColumns` layout). Nesting them per group re-creates a card whenever its group's identity changes, losing its state and screen lines. `HubColumns` isn't lazy (bars need the tallest column), so `HubCard` snapshots only while `onScrollVisibilityChange` says it's in view.
- **Inside a `GlassEffectContainer`, overlays added after `.glassEffect` draw under the glass.** Put borders and badges first.
- **Hidden title bar:** content ignores the top safe area; the leading 78 pt stays clear for the window buttons; the window drags by its background.
- **⌃Tab is a local key monitor** (`RecentSwitchKeys`), since the switcher needs ⌃'s release and the keys must not reach the terminal; it stands down while a sheet or alert is up. The ⌘ card numbers (`CardNumberKeys`) watch the same events but never consume them; ⌘Tab's Tab never reaches the app, so the numbers can show under the app switcher until Shoji goes inactive.
- **⌘W is Close Thread, or Close Pane on an empty pane:** `ShojiCommands` replaces `.saveItem`, which also removes Close Window. `focusedPaneId` may be an empty pane; `focusedThreadId` is only ever a thread.
- **`NSApp` is nil during `ShojiApp.init`.** `Notifier` waits for `didFinishLaunchingNotification`; tests never build it, so launch the Debug app after changing launch wiring.
- **Debug notifications** ask once as "Shoji Debug" and post nothing while its window is in sight. `scripts/shoji-hook` with `SHOJI_THREAD_ID` and `SHOJI_SOCKET` raises needs-you without an agent.
- **One Debug Shoji at a time:** a second instance takes over `hook.sock`, and both write `threads.json`.
- **A blank icon in ⌘Tab or the Dock is a stale icon cache:** `touch` the app bundle and `lsregister -f` it, then relaunch.
- **Icon Composer:** XcodeGen adds `AppIcon.icon` as one `wrapper.icon` file, compiled with `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Check renders with `ictool <file>.icon --export-image --platform macOS --rendition Default|Dark|ClearLight|TintedDark …`.
- **Visual checks without the live app:** `screencapture` needs Screen Recording for the agent's terminal; without it, `ImageRenderer` in a throwaway test renders SwiftUI views (glass flat, terminals, `ScrollView`s and some backgrounds blank or a placeholder). A new test file needs `xcodegen generate` before it runs.
- **AX `set value` on a SwiftUI text field reaches its binding only when editing ends;** move focus before pressing a button.
- **Signing:** `package.sh` signs with the self-signed "Shoji Local" certificate (Keychain Access › Certificate Assistant, Code Signing) when it's in the keychain, so local builds keep one designated requirement and privacy grants survive updates; `find-identity` without `-v`, since it's untrusted. CI and anyone without it get ad-hoc signing, so privacy grants reset with every update (quarantine: README › Download). App Sandbox stays off (Shoji spawns shells).
- **`package.sh --install`** removes the build's Release and Debug apps and every DMG afterwards (Spotlight indexes `build/`); the Debug app stays while it's running.
- **CI:** the test report comment is found by its `<!-- shoji-test-report -->` first line; fork PRs only get the run summary. Runs on the `xcode-27` label (preview) until a GA label exists. Tags pushed with `GITHUB_TOKEN` trigger no workflows, so `release.yml` tags and releases in one run.

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

## Decisions

- **Threads are shells.** No fixed command or kind: the card reflects what runs in the user's login shell; bars, not categories, group them.
- **SwiftTerm** over libghostty: a Swift package, Metal, Kitty protocols, MIT. Its gaps are ours (themes, Claude Code setup rules); libghostty stays the fallback behind `TerminalBackend`.
- **Status through each CLI's own hooks,** injected per launch (`--settings`, `-c hooks={…}`), never the user's config or Codex's `notify`.
- **Other panes never change behind your back.** A click only ever fills an empty pane or replaces yours; splits, drops and the pane dropdown give exact control.
- **A closed thread leaves its pane empty** (the user's wish): ⌘W twice closes both, so a slip never reshapes the layout. An empty pane takes a card anywhere, never as a split, since there's nothing to split beside.
- **An unseen finish wants you** like a question does; ivory, not orange, so the two stay apart.
- **One window, two forms, by width,** because Split View sets the width; the green button stays macOS's.
- **Room light:** 80% opaque, never blurred; more would cost contrast and show colours that mean status.
- **The Hub follows the shelf** (order and groups), so cards stay put and match ⌘1–9; needs-you cards stand out anyway.
- **Reopening relaunches, it doesn't revive:** a hidden live process would be one you can't see. Session only, so nothing closed lingers in `threads.json`.
- **The compact form starts from the right edge each time, unsaved** (the user's choice): the full layout is the one that lasts.
- **You stop processes yourself:** no Stop or command Restart buttons; ⌃C in the terminal and Close Thread (which asks) are the ways. Restart is only for a shell that has ended.
- **Git branch from `.git/HEAD`** (worktrees too), never a `git` process.
- **Hub screen lines once a second,** only while the Hub shows and for cards in view (about 1 ms a snapshot).
- **Options are one-click menu items;** there's no Settings window. A wish that would need one gets a menu item or isn't built.
- **Quiet chrome:** glass on surfaces, never on small controls (the zen icons and a Hub card's buttons are bare); pane controls appear on hover. Lantern, stones and bamboo are the only custom control glyphs; the rest are SF Symbols. The bonsai is decoration, shown only where no status is.
- **⌘ numbers overhang a card's top-leading corner;** mini cards use the same badge, which can touch the previous card's count badge while ⌘ is held.
- **Native notifications** over own popups: they follow Focus and screen sharing and keep a history.
- **⌘K is a popup terminal**, not a command field: completion, aliases and interactive commands come free. ⌘/ shows shortcuts, as a sheet so Esc never reaches a terminal.
- **`schemaVersion` only for shapes another Shoji can't read;** optional additions stay on version 1 (AGENTS invariant 9).
- **Self-signed is enough:** Shoji is for the user's own Mac, so no Developer ID or notarization.
- **Releases follow the version:** bumping `MARKETING_VERSION` in a PR is the decision; merging publishes `vX.Y.Z` with its DMG.
- **Names and ids:** the app is Shoji, *Hachi no Shoji* (ハチの障子) where there's room for the story. `fi.yan.shoji`, Debug `fi.yan.shoji.debug` (Shoji Debug), so the two never share notifications or settings.
