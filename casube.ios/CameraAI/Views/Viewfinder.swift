import SwiftUI

/// The viewfinder box: preview content + grid + rule-of-thirds + scanline +
/// match-colored border, brackets, badge, arrows, silhouette guide, and hint.
/// Everything match-colored keys off the single `state` value.
struct Viewfinder<Preview: View>: View {
    var state: MatchState
    var mode: CameraMode
    var aspectRatio: AspectRatio
    @ViewBuilder var preview: Preview

    var body: some View {
        let config = state.config
        ZStack {
            preview

            gridOverlay
            thirdsOverlay
            Scanline()

            // Silhouette guide (1 figure, or 3 small ones in group mode)
            HStack(spacing: mode.figureGap) {
                ForEach(0..<mode.figureCount, id: \.self) { _ in
                    SilhouetteFigure(color: config.color, lineWidth: 4, viewBox: mode.figureViewBox)
                        .frame(width: mode.figureSize.width, height: mode.figureSize.height)
                }
            }
            .opacity(state == .perfect ? 0.18 : 1)

            CornerBrackets(color: config.color)
            DirectionArrows(state: state)

            VStack {
                MatchBadge(state: state)
                    .padding(.top, 14)
                Spacer()
                Text(config.hint)
                    .font(AppFont.medium(12))
                    .foregroundStyle(config.color)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 14)
                    .background(Tokens.pillGradient, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 14)
            }
        }
        .aspectRatio(aspectRatio.previewRatio, contentMode: .fit)
        .background(Tokens.viewfinderInner)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    config.color,
                    style: StrokeStyle(lineWidth: 2, dash: config.dashedBorder ? [7, 5] : [])
                )
        }
        .animation(.easeInOut(duration: 0.3), value: state)
        .animation(.easeInOut(duration: 0.3), value: aspectRatio)
    }

    /// Faint 40pt grid (repeating-linear-gradient in the mockup).
    private var gridOverlay: some View {
        Canvas { context, size in
            let step: CGFloat = 40
            var path = Path()
            var x: CGFloat = step
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = step
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    /// Rule-of-thirds lines.
    private var thirdsOverlay: some View {
        Canvas { context, size in
            var path = Path()
            for f in [1.0 / 3.0, 2.0 / 3.0] {
                path.move(to: CGPoint(x: size.width * f, y: 0))
                path.addLine(to: CGPoint(x: size.width * f, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height * f))
                path.addLine(to: CGPoint(x: size.width, y: size.height * f))
            }
            context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
