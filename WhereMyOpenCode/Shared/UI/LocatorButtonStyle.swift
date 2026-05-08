import SwiftUI

struct LocatorButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    @Environment(\.isEnabled) private var isEnabled

    private let role: Role

    init(_ role: Role) {
        self.role = role
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(strokeColor, lineWidth: 1)
                    }
            }
            .opacity(role == .secondary && configuration.isPressed ? 0.82 : 1)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            isEnabled ? RadarPalette.onSignal : Color.secondary
        case .secondary:
            isEnabled ? RadarPalette.signalGreen : RadarPalette.disabledText
        }
    }

    private var strokeColor: Color {
        switch role {
        case .primary:
            RadarPalette.signalGreen.opacity(isEnabled ? 0.6 : 0.16)
        case .secondary:
            (isEnabled ? RadarPalette.signalGreen : RadarPalette.line).opacity(0.35)
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch role {
        case .primary:
            guard isEnabled else {
                return RadarPalette.mistSurface
            }

            return RadarPalette.signalGreen.opacity(isPressed ? 0.72 : 1)
        case .secondary:
            return isEnabled ? RadarPalette.mistSurface : RadarPalette.disabledSurface
        }
    }
}
