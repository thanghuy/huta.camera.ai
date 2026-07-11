import SwiftUI

/// Top-right aspect-ratio button (current ratio + chevron) and its popup menu.
/// Follows the camera-aspect-ratio-feature spec: 4:3 / 16:9 / 1:1, selected row
/// highlighted yellow, preview box animates to the chosen ratio.
struct AspectRatioButton: View {
    @Binding var aspectRatio: AspectRatio
    @Binding var isMenuOpen: Bool

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isMenuOpen.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(aspectRatio.rawValue)
                    .font(AppFont.medium(12))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isMenuOpen ? 180 : 0))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct AspectRatioMenu: View {
    @Binding var aspectRatio: AspectRatio
    @Binding var isMenuOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(AspectRatio.allCases) { ratio in
                Button {
                    aspectRatio = ratio
                    withAnimation(.easeOut(duration: 0.15)) { isMenuOpen = false }
                } label: {
                    Text(ratio.rawValue)
                        .font(AppFont.medium(13))
                        .foregroundStyle(aspectRatio == ratio ? Tokens.ink : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 14)
                        .background(
                            aspectRatio == ratio ? Tokens.yellow : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(minWidth: 76)
        .background(Tokens.menuBackground, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
    }
}
