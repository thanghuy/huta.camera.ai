import SwiftUI

/// Frame 01 — logo hero + tagline + CTA "Bắt đầu".
struct OnboardingScreen: View {
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Tokens.heroGradient
                SilhouetteFigure(color: Tokens.ink, lineWidth: 6)
                    .frame(width: 140, height: 252)
                    .opacity(0.95)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 12) {
                Text("CAMERA.AI")
                    .font(AppFont.medium(12))
                    .kerning(1.0)
                    .foregroundStyle(Tokens.deepYellow)

                Text("Chụp đúng dáng, đẹp mọi khung hình")
                    .font(AppFont.medium(30))
                    .lineSpacing(30 * 0.15)
                    .foregroundStyle(Tokens.ink)

                Text("Chọn một tư thế mẫu, khung xương AI sẽ dẫn bạn căn đúng vị trí trước khi bấm chụp.")
                    .font(AppFont.regular(15))
                    .lineSpacing(15 * 0.5)
                    .foregroundStyle(Tokens.muted)
                    .padding(.top, 2)

                Button(action: onStart) {
                    Text("Bắt đầu")
                        .font(AppFont.medium(16))
                        .foregroundStyle(Tokens.yellow)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Tokens.ctaGradient, in: RoundedRectangle(cornerRadius: 27))
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(EdgeInsets(top: 32, leading: 28, bottom: 12, trailing: 28))
            .background(Color.white)
        }
        .background(Color.white)
    }
}

#Preview {
    OnboardingScreen(onStart: {})
}
