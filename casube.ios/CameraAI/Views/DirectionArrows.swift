import SwiftUI

/// Directional guide arrows inside the viewfinder.
/// - `.edges` (none/far): four arrows at the frame edges.
/// - `.side` (close): one pulsing right-pointing arrow at the left edge
///   ("Dịch chuyển sang phải một chút").
struct DirectionArrows: View {
    var state: MatchState
    @State private var pulsing = false

    var body: some View {
        let config = state.config
        ZStack {
            switch config.arrows {
            case .edges:
                GeometryReader { geo in
                    arrow(config.color)
                        .position(x: geo.size.width / 2, y: 54)
                    arrow(config.color)
                        .rotationEffect(.degrees(90))
                        .position(x: 24, y: geo.size.height / 2)
                    arrow(config.color)
                        .rotationEffect(.degrees(-90))
                        .position(x: geo.size.width - 24, y: geo.size.height / 2)
                    arrow(config.color)
                        .rotationEffect(.degrees(180))
                        .position(x: geo.size.width / 2, y: geo.size.height - 54)
                }
            case .side:
                GeometryReader { geo in
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(config.color)
                        .opacity(pulsing ? 0.35 : 1)
                        .position(x: 26, y: geo.size.height / 2)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                pulsing = true
                            }
                        }
                        .onDisappear { pulsing = false }
                }
            case .none:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }

    private func arrow(_ color: Color) -> some View {
        Image(systemName: "arrow.left")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(color)
    }
}
