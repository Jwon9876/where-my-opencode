import AppKit
import SwiftUI

@MainActor
struct MenuBarView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var sessionStore: SessionStore
    @StateObject private var viewModel: MenuBarViewModel

    private static let scrollBarGutterWidth: CGFloat = 18

    init(settingsStore: SettingsStore, sessionStore: SessionStore) {
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        _viewModel = StateObject(
            wrappedValue: MenuBarViewModel(
                settingsStore: settingsStore,
                sessionStore: sessionStore
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LiveSessionsSection(viewModel: viewModel)
                    RecentSection(viewModel: viewModel)
                    AllProjectsSection(viewModel: viewModel)
                }
                .padding(.top, 4)
                .padding(.trailing, Self.scrollBarGutterWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 380, height: 480)
        .onAppear {
            viewModel.scanRootAndRefreshLive()
        }
        .onChange(of: settingsStore.settings.rootFolderPath) {
            viewModel.scanRootAndRefreshLive()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            LocatorMark()

            VStack(alignment: .leading, spacing: 4) {
                Text("Where My OpenCode")
                    .font(.headline)

                Text(viewModel.rootFolderDisplayValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(RadarPalette.mistSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(RadarPalette.line, lineWidth: 1)
                }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let statusMessage = viewModel.status.message {
                statusLine(message: statusMessage, isError: viewModel.status.isError)
            }

            if let sessionErrorMessage = sessionStore.lastErrorMessage {
                statusLine(message: sessionErrorMessage, isError: true)
            }

            HStack {
                Button {
                } label: {
                    Label("Add Manual Project...", systemImage: "plus")
                }
                .buttonStyle(LocatorSecondaryButtonStyle())
                .disabled(true)

                Spacer()

                Button {
                    viewModel.scanRootAndRefreshLive()
                } label: {
                    Label("Rescan Root Folder", systemImage: "scope")
                }
                .buttonStyle(LocatorPrimaryButtonStyle())
                .disabled(!viewModel.hasRootFolder)
            }

            HStack {
                Spacer()

                SettingsLink {
                    Label("Settings...", systemImage: "gearshape")
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
        }
        .controlSize(.small)
        .tint(RadarPalette.signalGreen)
    }

    private func statusLine(message: String, isError: Bool) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isError ? Color.red : RadarPalette.signalGreen)
                .frame(width: 6, height: 6)

            Text(message)
                .font(.caption)
                .foregroundStyle(isError ? Color.red : RadarPalette.signalGreen)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill((isError ? Color.red : RadarPalette.signalGreen).opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke((isError ? Color.red : RadarPalette.signalGreen).opacity(0.2), lineWidth: 1)
                }
        }
    }
}

private struct LocatorMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(RadarPalette.line.opacity(0.9), lineWidth: 1)
                .frame(width: 38, height: 38)

            Circle()
                .trim(from: 0.08, to: 0.78)
                .stroke(RadarPalette.signalGreen, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .rotationEffect(.degrees(-38))
                .frame(width: 38, height: 38)

            Rectangle()
                .fill(RadarPalette.line.opacity(0.75))
                .frame(width: 26, height: 1)

            Rectangle()
                .fill(RadarPalette.line.opacity(0.75))
                .frame(width: 1, height: 26)

            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(RadarPalette.signalGreen)
                .frame(width: 16, height: 16)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

private struct LocatorPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isEnabled ? RadarPalette.onSignal : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(RadarPalette.signalGreen.opacity(isEnabled ? 0.6 : 0.16), lineWidth: 1)
                    }
            }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return RadarPalette.mistSurface
        }

        return RadarPalette.signalGreen.opacity(isPressed ? 0.72 : 1)
    }
}

private struct LocatorSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isEnabled ? RadarPalette.signalGreen : RadarPalette.disabledText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isEnabled ? RadarPalette.mistSurface : RadarPalette.disabledSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke((isEnabled ? RadarPalette.signalGreen : RadarPalette.line).opacity(0.35), lineWidth: 1)
                    }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
