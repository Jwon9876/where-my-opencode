import SwiftUI

struct LocatorMark: View {
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
