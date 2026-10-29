import AppKit
import Carbon.HIToolbox
import SwiftTerm

@MainActor
final class SwiftTermBackend: TerminalBackend, LocalProcessTerminalViewDelegate {
    var onEvent: ((TerminalEvent) -> Void)?
    var view: NSView { terminalView }

    private let terminalView: ShojiTerminalView
    private let relay: DelegateRelay

    init() {
        terminalView = ShojiTerminalView(
            frame: CGRect(x: 0, y: 0, width: 960, height: 600),
            font: .monospacedSystemFont(ofSize: TerminalSessions.baseFontSize, weight: .regular),
            options: TerminalOptions(scrollback: 10_000)
        )
        terminalView.optionAsMetaKey = true
        terminalView.nativeBackgroundColor = NSColor(srgbRed: 0x0C / 255, green: 0x0F / 255, blue: 0x15 / 255, alpha: 1)
        terminalView.nativeForegroundColor = NSColor(srgbRed: 0xD7 / 255, green: 0xDC / 255, blue: 0xE4 / 255, alpha: 1)
        relay = DelegateRelay(view: terminalView)
        terminalView.terminalDelegate = relay
        terminalView.processDelegate = self
        relay.onEvent = { [weak self] in self?.onEvent?($0) }
        terminalView.onFocus = { [weak self] in self?.onEvent?(.focused) }
        ShiftReturn.installMonitor()
    }

    func start(_ launch: TerminalLaunch) {
        terminalView.startProcess(
            executable: launch.executable,
            args: launch.arguments,
            environment: launch.environment.map { "\($0.key)=\($0.value)" },
            currentDirectory: launch.directory
        )
    }

    func terminate() {
        terminalView.terminate()
    }

    func focus() {
        guard let window = terminalView.window else { return }
        if window.firstResponder === terminalView {
            // AppKit reports nothing when focus doesn't move; say so, or the request never settles.
            onEvent?(.focused)
        } else {
            window.makeFirstResponder(terminalView)
        }
    }

    func setFontSize(_ size: CGFloat) {
        guard terminalView.font.pointSize != size else { return }
        terminalView.font = .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func paste(_ text: String) {
        terminalView.pasteText(text)
    }

    // MARK: LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        onEvent?(.title(title))
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        onEvent?(.exited(code: exitCode))
    }

    func processFailedToStart(source: TerminalView, error: LocalProcessError) {
        onEvent?(.exited(code: nil))
    }
}

final class ShojiTerminalView: LocalProcessTerminalView {
    var onFocus: (() -> Void)?

    // `becomeFirstResponder` isn't open in SwiftTerm; `hasFocus` is set from it.
    override var hasFocus: Bool {
        get { super.hasFocus }
        set {
            super.hasFocus = newValue
            if newValue { onFocus?() }
        }
    }

    // AppKit focuses only the exact view clicked, which can be one of SwiftTerm's render subviews.
    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, !isUsingMetalRenderer {
            try? setUseMetal(true)
        }
    }
}

/// `LocalProcessTerminalView` is its own delegate and `bell` comes from a protocol extension,
/// so a subclass can't observe it. This relay forwards every call to the view and reports what Shoji needs.
@MainActor
private final class DelegateRelay: TerminalViewDelegate {
    unowned let view: ShojiTerminalView
    var onEvent: ((TerminalEvent) -> Void)?

    init(view: ShojiTerminalView) {
        self.view = view
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        view.send(source: source, data: data)
        onEvent?(.input)
    }

    func bell(source: TerminalView) {
        view.bell(source: source)
        onEvent?(.bell)
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        view.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        view.setTerminalTitle(source: source, title: title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        view.hostCurrentDirectoryUpdate(source: source, directory: directory)
    }

    func scrolled(source: TerminalView, position: Double) {
        view.scrolled(source: source, position: position)
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        view.requestOpenLink(source: source, link: link, params: params)
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        view.clipboardCopy(source: source, content: content)
    }

    func clipboardRead(source: TerminalView) -> Data? {
        view.clipboardRead(source: source)
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
        if let event = TerminalEvent(shojiReport: String(decoding: content, as: UTF8.self)) {
            onEvent?(event)
            return
        }
        view.iTermContent(source: source, content: content)
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        view.rangeChanged(source: source, startY: startY, endY: endY)
    }

    func programStatusChanged(source: TerminalView, records: [TerminalProgramStatus]) {
        view.programStatusChanged(source: source, records: records)
    }

    func kittyClipboardCapabilities(source: TerminalView) -> KittyClipboardCapabilities {
        view.kittyClipboardCapabilities(source: source)
    }

    func kittyClipboardAvailableMimeTypes(source: TerminalView, location: KittyClipboardLocation) -> [String]? {
        view.kittyClipboardAvailableMimeTypes(source: source, location: location)
    }

    func kittyClipboardRead(source: TerminalView, location: KittyClipboardLocation, mimeType: String) -> KittyClipboardReadResult? {
        view.kittyClipboardRead(source: source, location: location, mimeType: mimeType)
    }

    func kittyClipboardWrite(source: TerminalView, location: KittyClipboardLocation, content: KittyClipboardWriteContent) -> KittyClipboardWriteResult {
        view.kittyClipboardWrite(source: source, location: location, content: content)
    }

    func kittyClipboardRequestPermission(source: TerminalView, request: KittyClipboardPermissionRequest) -> KittyClipboardPermissionResult {
        view.kittyClipboardRequestPermission(source: source, request: request)
    }
}

/// Shift+Return must insert a newline in agent CLIs. When the program hasn't enabled the Kitty
/// keyboard protocol (which encodes Shift+Return itself), send ESC+CR, the Meta+Return newline.
/// SwiftTerm's `keyDown` isn't open, so this runs as an event monitor in front of the view.
@MainActor
private enum ShiftReturn {
    private static var monitor: Any?

    static func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == UInt16(kVK_Return),
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift,
                  let window = event.window
            else { return event }
            return MainActor.assumeIsolated { sendNewline(in: window) } ? nil : event
        }
    }

    private static func sendNewline(in window: NSWindow) -> Bool {
        guard let view = window.firstResponder as? ShojiTerminalView, view.keyboardEnhancementFlags.isEmpty else {
            return false
        }
        view.send(txt: "\u{1b}\r")
        return true
    }
}
