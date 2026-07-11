import SwiftUI

/// Top-center pill in the viewfinder: colored dot + "% khớp" label.
struct MatchBadge: View {
    var state: MatchState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.config.color)
                .frame(width: 6, height: 6)
            Text(state.config.label)
                .font(AppFont.medium(11))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .background(Tokens.pillGradient, in: RoundedRectangle(cornerRadius: 12))
    }
}
