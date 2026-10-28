import SwiftUI

/// App-wide zoom, browser style: one factor scales terminal text and the chrome around it.
enum Zoom {
    static let storageKey = "zoom"
    static let levels: [Double] = [0.75, 0.85, 1, 1.1, 1.25, 1.4, 1.6, 1.8, 2]

    /// The next level above (direction > 0) or below `current`, staying put at the ends.
    static func step(_ current: Double, by direction: Int) -> Double {
        let next = direction > 0 ? levels.first { $0 > current + 0.001 } : levels.last { $0 < current - 0.001 }
        return next ?? current
    }
}

extension EnvironmentValues {
    @Entry var zoom: CGFloat = 1
}
