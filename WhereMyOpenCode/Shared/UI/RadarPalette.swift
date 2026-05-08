import AppKit
import SwiftUI

enum RadarPalette {
    static let signalGreen = adaptive(light: rgb(8, 122, 79), dark: rgb(46, 219, 138))
    static let amber = adaptive(light: rgb(154, 98, 0), dark: rgb(242, 184, 75))
    static let carbon = adaptive(light: rgb(17, 22, 20), dark: rgb(246, 250, 247))
    static let onSignal = adaptive(light: rgb(255, 255, 255), dark: rgb(17, 22, 20))
    static let mistSurface = adaptive(light: rgb(246, 250, 247), dark: rgb(18, 28, 24))
    static let rowSurface = adaptive(light: rgb(255, 255, 255), dark: rgb(16, 22, 19))
    static let line = adaptive(light: rgb(199, 216, 207), dark: rgb(58, 78, 69))
    static let disabledText = adaptive(light: rgb(116, 132, 124), dark: rgb(104, 122, 113))
    static let disabledSurface = adaptive(light: rgb(239, 246, 242), dark: rgb(15, 24, 20))

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                dark
            } else {
                light
            }
        })
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
        NSColor(
            srgbRed: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            alpha: 1
        )
    }
}
