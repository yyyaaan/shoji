import SwiftUI

/// Terminal text levels (⌘+ / ⌘−); a thread's `textSteps` offset it.
enum TextZoom {
    static let storageKey = "zoom"
    static let levels: [Double] = [0.5, 0.6, 0.75, 0.85, 1, 1.1, 1.25, 1.4, 1.6, 1.8, 2]

    /// The next level above (direction > 0) or below `current`, staying put at the ends.
    static func step(_ current: Double, by direction: Int) -> Double {
        let next = direction > 0 ? levels.first { $0 > current + 0.001 } : levels.last { $0 < current - 0.001 }
        return next ?? current
    }

    /// `steps` levels away from `global` (counted from the nearest level), staying within the ends.
    static func level(_ global: Double, steps: Int) -> Double {
        guard steps != 0, let nearest = levels.indices.min(by: { abs(levels[$0] - global) < abs(levels[$1] - global) }) else { return global }
        return levels[min(max(nearest + steps, 0), levels.count - 1)]
    }
}

/// View › Interface Size: the chrome only.
enum InterfaceSize: Double, CaseIterable, Identifiable {
    case small = 0.85, standard = 1, large = 1.15, extraLarge = 1.3

    static let storageKey = "interfaceSize"

    var id: Self { self }

    var name: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }
}

extension EnvironmentValues {
    /// The interface size; chrome metrics multiply by it.
    @Entry var zoom: CGFloat = 1
}
