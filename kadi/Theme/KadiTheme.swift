//
//  KadiTheme.swift
//  kadi
//

import SwiftUI

enum KadiTheme {
    enum Colors {
        static let background     = Color(hex: 0x0B1F17)
        static let tableFelt       = Color(hex: 0x14533B)
        static let tableFeltDark   = Color(hex: 0x0E3A28)
        static let surface          = Color(hex: 0x1B2B24)
        static let surfaceElevated  = Color(hex: 0x24372F)

        static let accent      = Color(hex: 0xD4AF37)
        static let accentMuted = Color(hex: 0x9C842B)

        static let suitRed   = Color(hex: 0xE0473F)
        static let suitBlack = Color(hex: 0x1A1A1A)

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let textDisabled  = Color.white.opacity(0.35)

        static let success = Color(hex: 0x4CAF50)
        static let danger  = Color(hex: 0xE0473F)
        static let warning = Color(hex: 0xE0A93F)

        static let cardFace   = Color(hex: 0xFAF7F0)
        static let cardBack   = Color(hex: 0x1F4A3A)
        static let cardBorder = Color.black.opacity(0.15)
    }

    enum Typography {
        static let largeTitle    = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title         = Font.system(size: 26, weight: .bold, design: .rounded)
        static let headline      = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let body          = Font.system(size: 16, weight: .regular)
        static let callout       = Font.system(size: 14, weight: .medium)
        static let caption       = Font.system(size: 12, weight: .regular)
        static let cardRank      = Font.system(size: 20, weight: .bold, design: .rounded)
        static let cardRankSmall = Font.system(size: 13, weight: .bold, design: .rounded)
        static let buttonLabel   = Font.system(size: 17, weight: .semibold, design: .rounded)
    }

    enum Layout {
        static let cornerRadius: CGFloat = 14
        static let cardCornerRadius: CGFloat = 8
        static let cardWidth: CGFloat = 64
        static let cardHeight: CGFloat = 92
        static let cardWidthSmall: CGFloat = 44
        static let cardHeightSmall: CGFloat = 64
        static let spacingS: CGFloat = 8
        static let spacingM: CGFloat = 16
        static let spacingL: CGFloat = 24
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Colors.background, Colors.tableFeltDark],
                        startPoint: .top, endPoint: .bottom)
    }

    static var tableFeltGradient: RadialGradient {
        RadialGradient(colors: [Colors.tableFelt, Colors.tableFeltDark],
                        center: .center, startRadius: 10, endRadius: 400)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
