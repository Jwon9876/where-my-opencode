import SwiftUI

struct MenuBarHeader: View {
    let rootFolderDisplayValue: String

    var body: some View {
        HStack(spacing: 12) {
            LocatorMark()

            VStack(alignment: .leading, spacing: 4) {
                Text("Where My OpenCode")
                    .font(.headline)

                Text(rootFolderDisplayValue)
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
}
