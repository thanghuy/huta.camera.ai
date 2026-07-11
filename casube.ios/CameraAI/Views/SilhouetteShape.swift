import SwiftUI

/// The brand stick-figure silhouette, transcribed from the mockup's SVG paths
/// (native coordinate space 200×360). Used on onboarding, in the viewfinder
/// overlay, and on pose cards. `viewBox` crops the figure like an SVG viewBox
/// (e.g. the face crop in CHỤP CẬN mode) — clip at the call site.
struct SilhouetteShape: Shape {
    var viewBox: CGRect = CGRect(x: 0, y: 0, width: 200, height: 360)

    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Head: circle cx=100 cy=45 r=34
        p.addEllipse(in: CGRect(x: 66, y: 11, width: 68, height: 68))

        // Torso + arms
        p.move(to: CGPoint(x: 118, y: 80))
        p.addCurve(to: CGPoint(x: 148, y: 116), control1: CGPoint(x: 132, y: 84), control2: CGPoint(x: 144, y: 96))
        p.addCurve(to: CGPoint(x: 148, y: 156), control1: CGPoint(x: 151, y: 132), control2: CGPoint(x: 151, y: 146))
        p.addCurve(to: CGPoint(x: 134, y: 159), control1: CGPoint(x: 146, y: 162), control2: CGPoint(x: 140, y: 163))
        p.addLine(to: CGPoint(x: 130, y: 175))
        p.addLine(to: CGPoint(x: 130, y: 236))
        p.addLine(to: CGPoint(x: 70, y: 236))
        p.addLine(to: CGPoint(x: 70, y: 175))
        p.addLine(to: CGPoint(x: 66, y: 159))
        p.addCurve(to: CGPoint(x: 52, y: 156), control1: CGPoint(x: 60, y: 163), control2: CGPoint(x: 54, y: 162))
        p.addCurve(to: CGPoint(x: 52, y: 116), control1: CGPoint(x: 49, y: 146), control2: CGPoint(x: 49, y: 132))
        p.addCurve(to: CGPoint(x: 82, y: 80), control1: CGPoint(x: 56, y: 96), control2: CGPoint(x: 68, y: 84))
        p.addCurve(to: CGPoint(x: 100, y: 76), control1: CGPoint(x: 88, y: 77), control2: CGPoint(x: 94, y: 76))
        p.addCurve(to: CGPoint(x: 118, y: 80), control1: CGPoint(x: 106, y: 77), control2: CGPoint(x: 112, y: 77))
        p.closeSubpath()

        // Right leg
        p.move(to: CGPoint(x: 104, y: 236))
        p.addLine(to: CGPoint(x: 124, y: 236))
        p.addLine(to: CGPoint(x: 124, y: 330))
        p.addLine(to: CGPoint(x: 134, y: 330))
        p.addLine(to: CGPoint(x: 134, y: 344))
        p.addLine(to: CGPoint(x: 112, y: 344))
        p.addLine(to: CGPoint(x: 112, y: 236))
        p.closeSubpath()

        // Left leg
        p.move(to: CGPoint(x: 96, y: 236))
        p.addLine(to: CGPoint(x: 76, y: 236))
        p.addLine(to: CGPoint(x: 76, y: 330))
        p.addLine(to: CGPoint(x: 66, y: 330))
        p.addLine(to: CGPoint(x: 66, y: 344))
        p.addLine(to: CGPoint(x: 88, y: 344))
        p.addLine(to: CGPoint(x: 88, y: 236))
        p.closeSubpath()

        // Map viewBox → rect (aspect-fit, centered, like SVG xMidYMid meet).
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let offsetX = rect.midX - viewBox.midX * scale
        let offsetY = rect.midY - viewBox.midY * scale
        let transform = CGAffineTransform(translationX: offsetX, y: offsetY).scaledBy(x: scale, y: scale)
        return p.applying(transform)
    }
}

/// Convenience stroked silhouette view.
struct SilhouetteFigure: View {
    var color: Color
    var lineWidth: CGFloat = 4
    var viewBox: CGRect = CGRect(x: 0, y: 0, width: 200, height: 360)

    var body: some View {
        SilhouetteShape(viewBox: viewBox)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .clipped()
    }
}
