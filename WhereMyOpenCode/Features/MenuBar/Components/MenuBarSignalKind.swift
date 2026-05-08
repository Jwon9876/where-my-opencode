import SwiftUI

enum MenuBarSignalKind: Equatable {
    case live
    case recent
    case project

    var accent: Color {
        switch self {
        case .live:
            RadarPalette.signalGreen
        case .recent:
            RadarPalette.amber
        case .project:
            RadarPalette.signalGreen.opacity(0.64)
        }
    }

    var railColor: Color {
        switch self {
        case .live, .recent:
            accent
        case .project:
            RadarPalette.line
        }
    }

    var countPrefix: String {
        switch self {
        case .live:
            "LIVE"
        case .recent:
            "RECENT"
        case .project:
            "SCAN"
        }
    }
}
