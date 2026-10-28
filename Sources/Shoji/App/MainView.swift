import SwiftUI

struct MainView: View {
    @Environment(ThreadStore.self) private var store
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @AppStorage(Zoom.storageKey) private var zoom = 1.0
    @State private var showsShortcuts = false
    @State private var zoomToast: Double?

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 14) {
            if store.threads.isEmpty {
                welcome
            } else {
                ShelfView()
                PaneGrid()
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
        }
        .environment(\.zoom, zoom)
        .frame(minWidth: 640, minHeight: 480)
        .background(Backdrop())
        .overlay(alignment: .top) { zoomBadge }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Thread", systemImage: "plus") { store.newThread() }
                    .help("New Thread (⌘N)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Keyboard Shortcuts", systemImage: "keyboard") { showsShortcuts = true }
                    .help("Keyboard Shortcuts (⌘/)")
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("Layout", selection: $store.layout.mode) {
                    Label("Single pane", systemImage: "rectangle").tag(PaneLayout.Mode.single)
                    Label("Two columns", systemImage: "rectangle.split.2x1").tag(PaneLayout.Mode.twoColumns)
                    Label("Grid of four", systemImage: "rectangle.split.2x2").tag(PaneLayout.Mode.grid)
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
            }
        }
        .sheet(isPresented: $showsShortcuts) { ShortcutsSheet() }
        .focusedSceneValue(\.showsShortcuts, $showsShortcuts)
        .alert(
            "Close “\(closing?.displayTitle ?? "")”?",
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
