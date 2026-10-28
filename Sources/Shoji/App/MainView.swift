import SwiftUI

struct MainView: View {
    @Environment(ThreadStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 14) {
            ShelfView()
            PaneGrid()
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .background(Backdrop())
        .preferredColorScheme(.dark)
        .toolbar {
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
    }
}

#Preview {
    MainView()
        .environment(Mock.store())
        .frame(width: 1360, height: 860)
}
