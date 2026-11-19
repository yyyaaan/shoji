import Foundation
import UniformTypeIdentifiers

/// A card being dragged, as Shoji's own text payload, so text dragged in from elsewhere is ignored.
extension UTType {
    /// Declared in Info.plist; never offered to other apps.
    static let shojiThread = UTType(exportedAs: "fi.yan.shoji.thread")
}

enum CardDrag {
    static func item(for id: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.shojiThread.identifier, visibility: .ownProcess) { completion in
            completion(Data(id.uuidString.utf8), nil)
            return nil
        }
        return provider
    }

    /// Reads the dragged card's thread and hands it over on the main actor. False when nothing could be read.
    static func load(_ providers: [NSItemProvider], then action: @escaping @MainActor (UUID) -> Void) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.shojiThread.identifier) { data, _ in
            guard let data, let id = UUID(uuidString: String(decoding: data, as: UTF8.self)) else { return }
            Task { @MainActor in action(id) }
        }
        return true
    }
}
