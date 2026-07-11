import SwiftUI
import CoreText

/// Inter is the design font (bundled as OTF resources, registered at launch —
/// no UIAppFonts Info.plist entry needed). Falls back to the system font if
/// registration ever fails.
enum AppFont {
    private static let faces = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]
    private static var registered = false

    static func registerFonts() {
        guard !registered else { return }
        registered = true
        for face in faces {
            guard let url = Bundle.main.url(forResource: face, withExtension: "otf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func regular(_ size: CGFloat) -> Font { .custom("Inter-Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("Inter-Medium", size: size) }
    static func semibold(_ size: CGFloat) -> Font { .custom("Inter-SemiBold", size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Inter-Bold", size: size) }
}
