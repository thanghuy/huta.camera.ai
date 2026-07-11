import SwiftUI

/// The four 24×24 corner brackets inside the viewfinder, colored by match state.
struct CornerBrackets: View {
    var color: Color
    var inset: CGFloat = 10
    var size: CGFloat = 24
    var thickness: CGFloat = 3
    var cornerRadius: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ForEach(Corner.allCases, id: \.self) { corner in
                BracketShape(cornerRadius: cornerRadius)
                    .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(corner.rotation)
                    .position(corner.position(in: geo.size, inset: inset, size: size))
            }
        }
        .allowsHitTesting(false)
    }

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        var rotation: Angle {
            switch self {
            case .topLeft: .zero
            case .topRight: .degrees(90)
            case .bottomRight: .degrees(180)
            case .bottomLeft: .degrees(270)
            }
        }

        func position(in container: CGSize, inset: CGFloat, size: CGFloat) -> CGPoint {
            let half = size / 2
            switch self {
            case .topLeft: return CGPoint(x: inset + half, y: inset + half)
            case .topRight: return CGPoint(x: container.width - inset - half, y: inset + half)
            case .bottomLeft: return CGPoint(x: inset + half, y: container.height - inset - half)
            case .bottomRight: return CGPoint(x: container.width - inset - half, y: container.height - inset - half)
            }
        }
    }

    /// Top-left bracket: vertical + horizontal arm joined by a rounded outer corner.
    private struct BracketShape: Shape {
        var cornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            p.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                           control: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return p
        }
    }
}
