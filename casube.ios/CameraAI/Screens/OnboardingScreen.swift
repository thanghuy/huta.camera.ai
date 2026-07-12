import SwiftUI

/// View vẽ 3 vòng tròn đồng tâm đại diện cho ống kính camera từ thiết kế Figma mới
struct ConcentricCircles: View {
    var body: some View {
        ZStack {
            // Vòng ngoài cùng (2:3): viền nét đứt (stroke) và nền trắng đục mờ (opacity 8%)
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 88, height: 88)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )

            // Vòng tròn giữa (2:4): màu trắng đặc
            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)

            // Vòng tròn trong cùng (2:5): màu đen đặc
            Circle()
                .fill(Color.black)
                .frame(width: 18, height: 18)
        }
    }
}

/// Màn hình Onboarding được thiết kế lại theo đúng theme tối Figma
struct OnboardingScreen: View {
    var onStart: () -> Void

    // Gradient nền tối từ Figma: linear-gradient chạy từ #1A1A21 (stop 0) đến #0A0A0A (stop 1)
    private let backgroundGradient = LinearGradient(
        colors: [Color(hex: 0x1A1A21), Color(hex: 0x0A0A0A)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Nền tối gradient chiếm toàn bộ màn hình
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Phần đồ họa trung tâm: Ống kính camera đồng tâm từ Figma
                ConcentricCircles()
                    .padding(.bottom, 28)

                // Nhóm text tiêu đề và mô tả
                VStack(spacing: 12) {
                    Text("Camera.AI")
                        .font(AppFont.bold(30))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)

                    Text("Chụp đúng dáng, đẹp mọi khung hình")
                        .font(AppFont.medium(16))
                        .foregroundStyle(Color.white.opacity(0.92)) // Trắng 92% theo Figma JSON
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("Chọn một dáng mẫu, làm theo hướng dẫn trực tiếp trong khung ngắm và chụp ảnh đẹp chỉ trong vài giây.")
                        .font(AppFont.regular(14))
                        .lineSpacing(14 * 0.25)
                        .foregroundStyle(Color(hex: 0xB8B8BD)) // Màu #B8B8BD theo Figma JSON
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                Spacer()
                Spacer()

                // Nút CTA "Bắt đầu" có màu nền trắng hoàn toàn và text màu đen đặc
                Button(action: onStart) {
                    Text("Bắt đầu")
                        .font(AppFont.semibold(17))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    OnboardingScreen(onStart: {})
}
