import SwiftUI

/// One pose card: yellow-gradient thumb + silhouette, name, "category · difficulty".
struct PoseCard: View {
    var pose: ReferencePose
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Tokens.cardThumbGradient
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.55),
                            .init(color: Tokens.ink.opacity(0.16), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    SilhouetteFigure(color: Tokens.ink, lineWidth: 10)
                        .frame(width: 48, height: 86)
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(pose.name)
                    .font(AppFont.medium(13.5))
                    .foregroundStyle(Tokens.ink)

                Text("\(pose.category.rawValue) · \(pose.difficulty)")
                    .font(AppFont.medium(11))
                    .foregroundStyle(Tokens.muted)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AnyShapeStyle(isSelected ? Tokens.cardSelectedGradient : Tokens.cardIdleGradient),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Tokens.yellow : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}
