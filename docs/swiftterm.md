# SwiftTerm notes (v1.99.1)

What Shoji relies on, found by reading the pinned source. Re-check this file when bumping SwiftTerm. Only `Sources/Shoji/Terminal/` may use these APIs.

## Hosting a process

- `LocalProcessTerminalView` owns a PTY and a `LocalProcess`. `startProcess(executable:args:environment:execName:currentDirectory:)` takes the environment as `["KEY=VALUE"]`; nil means SwiftTerm's minimal defaults, so Shoji always passes a full environment.
- `TerminalOptions(scrollback:)` sets scrollback at creation; the default is only 500 lines.
- `processDelegate` (`LocalProcessTerminalViewDelegate`) delivers title, cwd (OSC 7), process exit and launch failure. Shoji's `SwiftTermBackend` is the process delegate.

## Delegates

- The view sets `terminalDelegate = self`. `bell(source:)` and `requestOpenLink` defaults live in a protocol extension, so a subclass cannot override `bell`. Shoji installs `DelegateRelay` as `terminalDelegate`: it forwards every `TerminalViewDelegate` call to the view and reports input and bell.
- Several methods share one signature in both delegate protocols (`hostCurrentDirectoryUpdate`, the kitty clipboard calls, `programStatusChanged`). The view forwards them to `processDelegate`, so the relay must not also be the process delegate or calls loop.
- `bellStyle = .visual` skips the delegate call entirely; keep `.sound` or `.soundAndVisual` if bell events matter.
- `Terminal.registerOscHandler(code:handler:)` is public, but the view's `terminal` is internal, so an app can't add its own OSC code. OSC 1337 keys other than `File` (and `Capabilities`) go to `iTermContent(source:content:)` on the main thread, in order: Shoji's zsh integration reports through `OSC 1337 ; ShojiEvent=…`, which `DelegateRelay` intercepts before forwarding the rest.

## Input and focus

- `keyDown`, `becomeFirstResponder` and `resignFirstResponder` are `public`, not `open`. Key rebinding happens in an `NSEvent` local monitor in front of the view (Shift+Return), and focus is observed by overriding `open var hasFocus`.
- `keyboardEnhancementFlags` (public, nonisolated) tells whether the app in the terminal enabled the Kitty keyboard protocol. When it has, SwiftTerm encodes Shift+Return itself and Shoji's monitor stands down.
- Clicking doesn't focus the terminal by itself: SwiftTerm leaves it to AppKit, which only focuses the exact view hit (sometimes a render subview). `mouseDown` is `open`, so `ShojiTerminalView` calls `makeFirstResponder(self)` there.
- `makeFirstResponder` on a view that already is first responder calls nothing, so `hasFocus` doesn't change; `SwiftTermBackend.focus()` reports `.focused` itself in that case.
- The view doesn't register for dragged types, so nothing dropped on a pane (a shelf card, text) reaches the shell.
- `optionAsMetaKey` defaults to true.
- Scroll wheel on the alternate screen becomes cursor keys only when the app enabled alternate scroll mode (`?1007`) and mouse reporting is off; Option or Shift scrolls locally.

## Rendering

- Metal is off by default. Call `setUseMetal(true)` after the view is in a window (Shoji does it in `viewDidMoveToWindow`). It throws on hardware without Metal, and the view stays on CoreGraphics.
- v1.99.1 redraws a hidden terminal correctly when it is shown again (#769). Shoji detaches a terminal that leaves the screen, and the Hub covers panes at opacity 0; neither hides nor zero-sizes the view, so the PTY size stays stable.
- `nativeBackgroundColor` / `nativeForegroundColor` set the default colors; `installColors` sets the 16-color palette (for themes).
- `backgroundOpacity` (the alpha of `nativeBackgroundColor`) makes only the default background translucent and updates the Metal layer's `isOpaque`; text, caret, selections, explicit cell backgrounds and SGR reverse stay opaque. The IME overlay and whole-screen reverse video use the background colour as is.

## Reading the screen

- `terminalContentSnapshot(region: .history(maximumScrollbackRows: -1))` copies the live screen under the terminal lock, whatever the user scrolled to: the Hub's last lines (`SwiftTermBackend.screenLines()`). `visibleRowsText(_:)` and `Terminal.getLine(row:)` follow the scroll (`yDisp`), despite `getLine`'s doc. Never derive status from either (AGENTS invariant 5).

## Useful later

- `observeOscEvents(_:)` reports OSC 9/99/777 desktop notifications without touching the terminal.
- `send(txt:)` writes to the PTY: the only way Hub "Allow once" may type (AGENTS invariant 6).

## Build

- The package runs a build-tool plugin (`SwiftTermBuildInfoPlugin`). `xcodebuild` needs `-skipPackagePluginValidation`; in Xcode, click Trust & Enable once.
- Transitive packages (swift-argument-parser, swift-docc-plugin, swift-png) resolve but aren't linked into the macOS app.
