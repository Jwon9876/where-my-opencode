import SwiftUI

@MainActor
struct OpenCodeRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    let signalKind: MenuBarSignalKind
    let title: String
    let subtitle: String
    let mainHelpText: String
    let newSessionProject: Project?
    let mainAction: () -> Void
    let newSessionAction: (Project) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: mainAction) {
                rowContent
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(mainHelpText)

            if let newSessionProject {
                Button {
                    newSessionAction(newSessionProject)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(signalKind.accent)
                        .frame(width: 26, height: 26)
                        .background(signalKind.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(signalKind.accent.opacity(0.22), lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(MenuBarRowActionPolicy.openNewSessionHelpText)
                .accessibilityLabel(MenuBarRowActionPolicy.openNewSessionHelpText)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .padding(.trailing, newSessionProject == nil ? 8 : 4)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(RadarPalette.rowSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(signalKind.accent.opacity(signalKind == .live ? 0.09 : 0.045))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadarPalette.line, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(signalKind.railColor.opacity(signalKind == .live ? 0.9 : 0.62))
                .frame(width: 2)
                .padding(.vertical, 8)
        }
        .onAppear {
            updatePulse()
        }
        .onChange(of: reduceMotion) {
            updatePulse()
        }
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            SignalNode(kind: signalKind, isPulsing: signalKind == .live && isPulsing && !reduceMotion)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func updatePulse() {
        isPulsing = false

        guard signalKind == .live, !reduceMotion else {
            return
        }

        Task { @MainActor in
            isPulsing = true
        }
    }
}

private struct SignalNode: View {
    let kind: MenuBarSignalKind
    let isPulsing: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(RadarPalette.line.opacity(0.72))
                .frame(width: 1, height: 34)

            node
        }
        .frame(width: 30, height: 34)
    }

    @ViewBuilder
    private var node: some View {
        switch kind {
        case .live:
            ZStack {
                Circle()
                    .stroke(RadarPalette.signalGreen.opacity(isPulsing ? 0 : 0.38), lineWidth: 1)
                    .frame(width: isPulsing ? 32 : 15, height: isPulsing ? 32 : 15)
                    .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: isPulsing)

                Circle()
                    .stroke(RadarPalette.line.opacity(0.9), lineWidth: 1)
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(RadarPalette.signalGreen)
                    .frame(width: 8, height: 8)
            }
        case .recent:
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.82)
                    .stroke(RadarPalette.amber, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-118))
                    .frame(width: 22, height: 22)

                Circle()
                    .fill(RadarPalette.amber)
                    .frame(width: 4, height: 4)
                    .offset(x: 4, y: -3)
            }
        case .project:
            ZStack {
                Circle()
                    .stroke(RadarPalette.line, lineWidth: 1)
                    .frame(width: 22, height: 22)

                Rectangle()
                    .fill(RadarPalette.line)
                    .frame(width: 12, height: 1)

                Rectangle()
                    .fill(RadarPalette.line)
                    .frame(width: 1, height: 12)

                Circle()
                    .fill(RadarPalette.signalGreen.opacity(0.65))
                    .frame(width: 4, height: 4)
            }
        }
    }
}
