import SwiftUI

/// The yellow scanline sweeping down the viewfinder on a 2.6s loop.
struct Scanline: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Tokens.yellow, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
            .offset(y: -2 + (geo.size.height + 4) * progress)
            .opacity(0.5)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}
