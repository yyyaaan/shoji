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
            ShelfView()
            PaneGrid()
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .environment(\.zoom, zoom)
        .frame(minWidth: 640, minHeight: 480)
        .background(Backdrop())
        .overlay(alignment: .top) { zoomBadge }
        .preferredColorScheme(.dark)
        .toolbar {
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
