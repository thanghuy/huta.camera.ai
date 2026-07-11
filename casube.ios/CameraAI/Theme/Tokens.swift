import SwiftUI

/// Brand tokens ported verbatim from `design-reference/Camera.AI - standalone.html`.
/// Every color/gradient in the app comes from here — do not hardcode brand colors elsewhere.
enum Tokens {
    // MARK: Core palette
    static let yellow = Color(hex: 0xFFC72C)
    static let ink = Color(hex: 0x1A1A16)
    static let cream = Color(hex: 0xF4F1E8)
    static let muted = Color(hex: 0x8A8372)
    static let deepYellow = Color(hex: 0xF0AE00)

    // MARK: Camera screen surfaces
    static let cameraBackground = Color(hex: 0x0B0B0C)
    static let viewfinderInner = Color(hex: 0x151513)
    static let menuBackground = Color(hex: 0x1E1E1C)
    static let chipIdle = Color(hex: 0xF1EEE4)
    static let hairline = Color(hex: 0xE3DFD2)

    // MARK: Match-state palette (grey / red / yellow / green + light variants)
    static let matchNone = Color(hex: 0x9A9488)
    static let matchNoneLight = Color(hex: 0xC9C3B6)
    static let matchFar = Color(hex: 0xE2574C)
    static let matchFarLight = Color(hex: 0xF4958C)
    static let matchClose = Color(hex: 0xFFC72C)
    static let matchCloseLight = Color(hex: 0xFFE59B)
    static let matchPerfect = Color(hex: 0x3FB873)
    static let matchPerfectLight = Color(hex: 0x8FE3AE)

    // MARK: Gradients
    /// Onboarding hero: linear-gradient(160deg, #FFC72C, #F0AE00)
    static let heroGradient = LinearGradient(
        colors: [yellow, deepYellow],
        startPoint: UnitPoint(x: 0.33, y: 0),
        endPoint: UnitPoint(x: 0.67, y: 1)
    )
    /// Dark CTA: linear-gradient(135deg, #2A2A24, #0E0E0C)
    static let ctaGradient = LinearGradient(
        colors: [Color(hex: 0x2A2A24), Color(hex: 0x0E0E0C)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Translucent dark pill behind badges/hints.
    static let pillGradient = LinearGradient(
        colors: [Color(hex: 0x32302A).opacity(0.72), Color(hex: 0x0A0A08).opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Pose card thumbnail: linear-gradient(155deg, #FFF3D0, #FFDA7A, #F0AE00)
    static let cardThumbGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xFFF3D0), location: 0),
            .init(color: Color(hex: 0xFFDA7A), location: 0.55),
            .init(color: deepYellow, location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Idle pose card background.
    static let cardIdleGradient = LinearGradient(
        colors: [Color(hex: 0xF9F7F0), Color(hex: 0xF1EEE4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Selected pose card background.
    static let cardSelectedGradient = LinearGradient(
        colors: [Color(hex: 0xFFF7DE), Color(hex: 0xFFE8AE)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Photo-library thumb button.
    static let photoButtonGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x58544D), location: 0),
            .init(color: Color(hex: 0x302E28), location: 0.6),
            .init(color: Color(hex: 0x1A1916), location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Frosted light-on-dark button fill.
    static let glassGradient = LinearGradient(
        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    /// Color from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
