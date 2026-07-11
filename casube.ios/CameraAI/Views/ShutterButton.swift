import SwiftUI

/// 76pt shutter: conic ring colored by match state around a white disc.
/// Pulses when the match is perfect.
struct ShutterButton: View {
    var state: MatchState
    var action: () -> Void
    @State private var pulsing = false

    var body: some View {
        let config = state.config
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [config.color, config.light, config.color],
                            center: .center,
                            angle: .degrees(180)
                        )
                    )
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(.white)
                    .frame(width: 58, height: 58)
            }
            .opacity(pulsing ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: state)
        .onChange(of: state == .perfect, initial: true) { _, isPerfect in
            if isPerfect {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { pulsing = false }
            }
        }
    }
}
