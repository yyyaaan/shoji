<div align="center">

<img src="docs/images/icon.png" width="128" height="128" alt="Shoji app icon: Hachi the Akita peeking between two shoji panels">

# Shoji

*Hachi no Shoji · ハチの障子*

**A calm, native macOS home for the terminals you keep open all day.**

Coding agents like Claude Code and Codex sit next to long-running tasks like `pnpm dev`, and Hachi lets you know when one of them needs you.

[![CI](https://github.com/yyyaaan/shoji/actions/workflows/ci.yml/badge.svg)](https://github.com/yyyaaan/shoji/actions/workflows/ci.yml)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-111?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

</div>

<p align="center"><img src="docs/images/shoji.png" alt="Shoji window: a shelf of glass cards on top, one agent card asking for attention with Hachi, and a Claude Code terminal below"></p>

## Why Shoji

Agent CLIs are at their best in a real terminal, but a dozen terminal tabs hide which agent is waiting on you. Shoji keeps every session (a **thread**) as a glass **card** on a **shelf**, opens the ones you are working with in **panes**, and shows at a glance which agent is working, done, or blocked on your answer.

Shoji is deliberately not an editor, a diff viewer or an agent client. It never talks to a model or an API: Claude Code and Codex stay plain CLIs on your own subscription, and Shoji only hosts their terminals and listens to their hooks.

## Features

- **Every thread is your shell.** ⌘N opens one next to the card you're on. `cd` anywhere, run `claude`, `codex` or `pnpm dev`, quit back to the prompt; the card follows along. Reopen Shoji and your threads, layout and Claude conversations come back.
- **Your shelf, your groups.** Drag cards into place and drop plain bars between them (right-click a card); groups mean whatever you want. Unnamed threads read like "~ 2", so two shells in the same folder stay apart.
- **Know who needs you.** Cards show working, needs you, done, idle, running and exited, each with its own shape and label. A needs-you card turns orange, counts what's waiting and brings out Hachi, who also peeks out under the window buttons: one click opens the thread that's waiting.
- **Status from the CLI itself.** Claude Code reports through its own hooks, injected per launch with `--settings`, so your `~/.claude` is never touched. Shoji never scrapes terminal output.
- **Real terminals.** SwiftTerm with Metal rendering, your login shell's environment, 10,000 lines of scrollback, and Shift+Return for a new line in agent prompts.
- **Panes that stay out of the way.** One, two, three (one tall beside two stacked) or four panes; drag the gap between them to resize; maximize one or send it back to the shelf. Hidden threads keep running. No toolbar row: the shelf shares the top of the window with the window buttons.
- **Keyboard first.** Jump to any card, cycle panes, switch layouts or find the next agent waiting on you without touching the mouse. Press ⌘/ to see every shortcut.
- **Zoom everything.** ⌘+ and ⌘− scale terminal text and the glass chrome together, from 75% to 200%.
- **Native to macOS 26.** SwiftUI and Liquid Glass on the chrome, solid backgrounds behind terminal text.

> [!NOTE]
> Shoji is an early preview (v0). Folder, command and Claude status need zsh (the macOS default); Codex status and resume are on the [roadmap](#roadmap).

## Requirements

- macOS 26 Tahoe or later
- [Claude Code](https://github.com/anthropics/claude-code) for live agent status (Codex support is on the roadmap)
- To build: Xcode 27 (CI uses 27.1) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Install

### Build from source (recommended)

```sh
brew install xcodegen
git clone https://github.com/yyyaaan/shoji.git && cd shoji
scripts/package.sh                         # universal Release build and DMG
ditto build/Build/Products/Release/Shoji.app /Applications/Shoji.app
open /Applications/Shoji.app
```

Apps you build yourself open without a Gatekeeper prompt.

### Download

Every version merged to `main` publishes a DMG on [Releases](https://github.com/yyyaaan/shoji/releases). These builds are ad-hoc signed and not notarized, so macOS blocks the first launch: open **System Settings › Privacy & Security** and choose **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Shoji.app`.

## Keyboard shortcuts

| Action | Keys |
|---|---|
| New thread (next to the current card) | ⌘N |
| Close thread (asks while something runs) | ⌘W |
| Jump to card 1–9 | ⌘1 … ⌘9 |
| Next thread that needs you | ⌘J |
| Next / previous pane | ⌘] / ⌘[ |
| Maximize or restore pane | ⇧⌘↩ |
| Minimize pane to shelf | ⇧⌘M |
| One / two / three / four panes | ⌥⌘1 / ⌥⌘2 / ⌥⌘3 / ⌥⌘4 |
| Zoom in / out / actual size | ⌘+ / ⌘− / ⌘0 |
| All shortcuts | ⌘/ |

Shortcuts work while a terminal has focus. In agent prompts, Shift+Return inserts a new line.

## How it works

```mermaid
flowchart LR
    CLI["Claude Code<br/>(in a Shoji pane)"] -- "hook event (JSON)" --> Hook["shoji-hook"]
    Hook -- "Unix socket" --> Server["HookServer"]
    Zsh["zsh integration"] -- "folder · command · exit code<br/>(OSC 1337)" --> PTY
    PTY["SwiftTerm PTY"] -- "title · bell · shell reports · exit" --> Store
    Server -- "StatusEvent" --> Store["ThreadStore"]
    Store --> UI["Cards and panes"]
```

- Each thread is your login shell with `SHOJI_THREAD_ID` and `SHOJI_SOCKET` in its environment. For zsh, Shoji points `ZDOTDIR` at a tiny loader that restores yours, so your dotfiles load unchanged, then adds prompt hooks that report the folder and each command.
- Typing `claude` in a thread runs it with Shoji's hooks for that run only (`--settings`). They call the bundled `shoji-hook`, which forwards the event to Shoji in about 10 ms and exits silently when Shoji isn't running, so it never slows the CLI.
- Every status change, from a hook or from the terminal, goes through one path into `ThreadStore`.
- No tmux, no multiplexer: threads persist through each CLI's own resume. On relaunch a Claude thread runs `claude --resume <id>` at its first prompt; any other last command waits at the prompt for you to press Return.
- Shoji never types into a terminal on its own; anything it sends will come from an explicit click, showing exactly what it sends.

## Development

```sh
xcodegen generate     # after cloning and after any project.yml change
xcodebuild -scheme Shoji -derivedDataPath build -destination 'platform=macOS' -skipPackagePluginValidation test
open build/Build/Products/Debug/Shoji.app
```

`project.yml` is the source of truth; the Xcode project is generated and not committed. `-skipPackagePluginValidation` is needed because SwiftTerm runs a build-tool plugin; in Xcode, choose **Trust & Enable** once instead. Tests use Swift Testing, and CI runs them on every pull request.

[AGENTS.md](AGENTS.md) is the contributor guide for people and coding agents alike: layout, conventions and the invariants that keep Shoji safe around your CLIs. [PLAN.md](PLAN.md) holds the current state, gotchas and decisions.

## Roadmap

- **Now:** a hands-on polish pass on everyday use
- **Next:** a recent-thread switcher, macOS notifications while Shoji is in the background, Codex status and resume, bash integration
- **Later:** multiple windows with a slim sidebar style, saved workspaces, a Hub view of every agent sorted by attention, "Allow once" from the Hub, quick jump, settings and themes

The live list is in [PLAN.md](PLAN.md#tasks).

## About the name

Shoji (障子) are the paper sliding panels of a Japanese room: they let the light through and keep things quietly apart. **Hachi no Shoji** means *Hachi's shoji*. Hachi, an Akita, rests behind the panels and only peeks out when one of your threads needs you.

## Acknowledgements

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza (MIT) powers every terminal.
- Hachi, the Akita, was drawn for Shoji. Design sources live in [docs/design/hachi](docs/design/hachi/README.md).

## License

[Apache License 2.0](LICENSE)
