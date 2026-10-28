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

## Input and focus

- `keyDown`, `becomeFirstResponder` and `resignFirstResponder` are `public`, not `open`. Key rebinding happens in an `NSEvent` local monitor in front of the view (Shift+Return), and focus is observed by overriding `open var hasFocus`.
- `keyboardEnhancementFlags` (public, nonisolated) tells whether the app in the terminal enabled the Kitty keyboard protocol. When it has, SwiftTerm encodes Shift+Return itself and Shoji's monitor stands down.
- `optionAsMetaKey` defaults to true.
- Scroll wheel on the alternate screen becomes cursor keys only when the app enabled alternate scroll mode (`?1007`) and mouse reporting is off; Option or Shift scrolls locally.

## Rendering

- Metal is off by default. Call `setUseMetal(true)` after the view is in a window (Shoji does it in `viewDidMoveToWindow`). It throws on hardware without Metal, and the view stays on CoreGraphics.
- v1.99.1 redraws a hidden terminal correctly when it is shown again (#769). Shoji detaches terminal views from the window instead of hiding or zero-sizing them, so the PTY size stays stable.
- `nativeBackgroundColor` / `nativeForegroundColor` set the default colors; `installColors` sets the 16-color palette (themes, M5).

## Useful later

- `visibleRowsText(_:)` copies visible rows as text: Hub "last 3 lines" preview (M4). Never derive status from it (AGENTS invariant 5).
- `observeOscEvents(_:)` reports OSC 9/99/777 desktop notifications without touching the terminal.
- `send(txt:)` writes to the PTY: the only way Hub "Allow once" may type (AGENTS invariant 6).

## Build

- The package runs a build-tool plugin (`SwiftTermBuildInfoPlugin`). `xcodebuild` needs `-skipPackagePluginValidation`; in Xcode, click Trust & Enable once.
- Transitive packages (swift-argument-parser, swift-docc-plugin, swift-png) resolve but aren't linked into the macOS app.
