import SwiftUI

/// Small "Đã lưu" confirmation shown after a photo is saved to the library.
struct SavedToast: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.yellow)
            Text("Đã lưu")
                .font(AppFont.medium(13))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 16)
        .background(Tokens.pillGradient, in: Capsule())
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
