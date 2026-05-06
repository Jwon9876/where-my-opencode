import SwiftUI

@MainActor
struct OpenCodeRow: View {
    let iconName: String
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
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
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
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 20)

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
}
