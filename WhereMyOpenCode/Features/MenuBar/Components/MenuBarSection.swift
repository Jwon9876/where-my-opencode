import SwiftUI

struct MenuBarSection<Content: View>: View {
    let title: String
    let signalKind: MenuBarSignalKind
    let signalValue: String?
    let content: Content

    init(
        title: String,
        signalKind: MenuBarSignalKind,
        signalValue: String?,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.signalKind = signalKind
        self.signalValue = signalValue
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RadarSectionTitle(title: title)

                Spacer()

                if let signalValue {
                    SectionSignalLabel(kind: signalKind, value: signalValue)
                }
            }

            content
        }
    }
}

private struct SectionSignalLabel: View {
    let kind: MenuBarSignalKind
    let value: String

    var body: some View {
        Text("\(kind.countPrefix) \(value)")
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(kind.accent)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(RadarPalette.mistSurface)
                    .overlay {
                        Capsule()
                            .stroke(kind.accent.opacity(0.28), lineWidth: 1)
                    }
            }
    }
}

private struct RadarSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(RadarPalette.carbon)
    }
}
