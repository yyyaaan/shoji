import SwiftUI

/// The window's top-right column, at the same spot in Threads and the Hub: the lantern, the stones, the bamboo.
struct CornerControls: View {
    @Environment(\.zoom) private var zoom

    var body: some View {
        VStack(spacing: 2 * zoom) {
            HubButton()
            FolderMenu()
            QuickTerminalButton()
        }
        // Puts the lantern on the window buttons' line.
        .padding(.top, 5 * zoom)
    }
}

/// The lantern: to the Hub and back.
struct HubButton: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom

    var body: some View {
        Button { store.showsHub.toggle() } label: {
            Image(.zenLantern)
                .resizable()
                .scaledToFit()
                .frame(width: 20 * zoom, height: 20 * zoom)
                .foregroundStyle(store.showsHub ? Palette.text : .white.opacity(0.55))
                .frame(width: 34 * zoom, height: 34 * zoom)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(store.showsHub ? "Back to Threads (Esc)" : "Hub (⇧⌘H)")
        .accessibilityLabel("Hub")
        .accessibilityAddTraits(store.showsHub ? .isSelected : [])
    }
}

/// The bamboo: the ⌘K quick terminal, for the mouse.
struct QuickTerminalButton: View {
    @Environment(TerminalSessions.self) private var sessions: TerminalSessions?
    @Environment(\.zoom) private var zoom

    var body: some View {
        Button { sessions?.togglePopup() } label: {
            Image(.zenBamboo)
                .resizable()
                .scaledToFit()
                .frame(width: 20 * zoom, height: 20 * zoom)
                .foregroundStyle(sessions?.popup != nil ? Palette.text : .white.opacity(0.55))
                .frame(width: 34 * zoom, height: 34 * zoom)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Quick Terminal (⌘K)")
        .accessibilityLabel("Quick Terminal")
    }
}

/// The stones: a new thread in one of the folders inside a folder you choose, which the menu also changes.
struct FolderMenu: View {
    @Environment(ThreadStore.self) private var store
    @Environment(\.zoom) private var zoom
    @AppStorage("folderMenuParent") private var parent = "~"
    @State private var folders: [String] = []

    var body: some View {
        Menu {
            Section(parent) {
                ForEach(folders, id: \.self) { name in
                    Button(name) { store.newThread(folder: (parent as NSString).appendingPathComponent(name)) }
                }
                if folders.isEmpty {
                    Text("No folders here")
                }
            }
            Divider()
            Button("Choose Folder to List…", action: choose)
        } label: {
            Image(.zenStones)
                .resizable()
                .scaledToFit()
                .frame(width: 20 * zoom, height: 20 * zoom)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 34 * zoom, height: 34 * zoom)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("New thread in a folder of \(parent)")
        .accessibilityLabel("New Thread in a Folder")
        // Read when it might open rather than on every redraw.
        .onAppear(perform: list)
        .onHover { if $0 { list() } }
        .onChange(of: parent, list)
    }

    private func list() {
        let url = URL(filePath: (parent as NSString).expandingTildeInPath, directoryHint: .isDirectory)
        let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey], options: .skipsHiddenFiles)) ?? []
        let found = items
            .filter {
                let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
                return values?.isDirectory == true && values?.isPackage != true
            }
            .map(\.lastPathComponent)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        if found != folders { folders = found }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(filePath: (parent as NSString).expandingTildeInPath, directoryHint: .isDirectory)
        panel.message = "The stones will list the folders inside the one you choose."
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        parent = ((url.path(percentEncoded: false) as NSString).standardizingPath as NSString).abbreviatingWithTildeInPath
    }
}

#Preview {
    CornerControls()
        .padding(24)
        .environment(Mock.store())
        .background(Backdrop())
}
