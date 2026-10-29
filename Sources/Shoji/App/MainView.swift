import SwiftUI

struct MainView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @AppStorage(Zoom.storageKey) private var zoom = 1.0
    @State private var showsShortcuts = false
    @State private var zoomToast: Double?
    @State private var showsRecentSwitch = false

    var body: some View {
        VStack(spacing: 14) {
            if store.threads.isEmpty {
                welcome
            } else {
                // No title bar or toolbar row: the shelf shares the top with the window buttons.
                HStack(spacing: 0) {
                    // Clear of the window's close, minimize and zoom buttons; Hachi's corner sits below them.
                    HachiCorner()
                        .frame(width: 78)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 6 * zoom)
                    ShelfView()
                }
                .frame(height: 120 * zoom)
                PaneGrid()
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.zoom, zoom)
        .frame(minWidth: 640, minHeight: 480)
        .background(Backdrop())
        .overlay(alignment: .top) { zoomBadge }
        .overlay {
            if showsRecentSwitch, let recentSwitch = store.recentSwitch {
                RecentSwitchPanel(recentSwitch: recentSwitch)
                    .environment(\.zoom, zoom)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsShortcuts) { ShortcutsSheet() }
        .focusedSceneValue(\.showsShortcuts, $showsShortcuts)
        .alert(
            "Close “\(closing.map(store.name) ?? "")”?",
            isPresented: Binding { store.closeRequest != nil } set: { if !$0 { store.closeRequest = nil } },
            presenting: closing
        ) { thread in
            Button("Close Thread", role: .destructive) { store.close(thread.id) }
            Button("Cancel", role: .cancel) {}
        } message: { thread in
            Text(closeMessage(for: thread))
        }
        .onChange(of: zoom, initial: true) { old, zoom in
            // Half-point steps keep terminal cells on whole pixels at 2x.
            sessions?.fontSize = (TerminalSessions.baseFontSize * zoom * 2).rounded() / 2
            if old != zoom { withAnimation(.snappy) { zoomToast = zoom } }
        }
        .onAppear { RecentSwitchKeys.install(store: store) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            store.cancelRecentSwitch()
            store.isAppActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.isAppActive = true
        }
        // Like ⌘Tab: a quick ⌃Tab switches without flashing the list.
        .task(id: store.recentSwitch != nil) {
            showsRecentSwitch = false
            guard store.recentSwitch != nil, (try? await Task.sleep(for: .milliseconds(150))) != nil else { return }
            showsRecentSwitch = true
        }
        .task(id: zoomToast) {
            guard zoomToast != nil, (try? await Task.sleep(for: .seconds(1.2))) != nil else { return }
            withAnimation(.easeOut) { zoomToast = nil }
        }
    }

    private var closing: ShojiThread? {
        store.closeRequest.flatMap(store.thread)
    }

    private func closeMessage(for thread: ShojiThread) -> String {
        switch (store.activity(for: thread.id).agent, thread.command) {
        case (.claude?, _): "Claude is running here. The conversation stays in Claude's history (claude --resume)."
        case (_, let command?): "“\(command)” is still running and will be stopped."
        default: "Its shell and anything running in it will be stopped."
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            // Not Hachi: the mascot is reserved for needs-you cards (docs/design/hachi/README.md).
            Image(systemName: "terminal")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Palette.working)
                .frame(width: 84, height: 84)
                .glassEffect(.regular.tint(Palette.working.opacity(0.18)), in: .rect(cornerRadius: 22))
            VStack(spacing: 6) {
                Text("Welcome to Shoji")
                    .font(.system(size: 24, weight: .semibold))
                Text("Each thread is a shell: cd anywhere, run claude, codex or a dev server.\nThreads come back every time you open Shoji.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            Button("New Thread", systemImage: "plus") { store.newThread() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            Text("⌘N")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .foregroundStyle(Palette.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var zoomBadge: some View {
        if let zoomToast {
            Label {
                Text(zoomToast, format: .percent.precision(.fractionLength(0))).monospacedDigit()
            } icon: {
                Image(systemName: "textformat.size")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .padding(.top, 8)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .accessibilityLabel("Zoom \(Int((zoomToast * 100).rounded())) percent")
        }
    }
}

#Preview {
    MainView()
        .environment(Mock.store())
        .frame(width: 1360, height: 860)
}

#Preview("Welcome") {
    MainView()
        .environment(ThreadStore(threads: []))
        .frame(width: 1100, height: 700)
}
