import SwiftUI

struct StatusLine: View {
    let message: String
    let isError: Bool

    private var color: Color {
        isError ? .red : RadarPalette.signalGreen
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(message)
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                }
        }
    }
}
