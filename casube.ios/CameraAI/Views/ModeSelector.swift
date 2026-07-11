import SwiftUI

/// Bottom mode chips (CHỤP NGƯỜI / CHỤP CẬN / CHỤP NHÓM) + pose-library button.
struct ModeSelector: View {
    @Binding var mode: CameraMode
    var openLibrary: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CameraMode.allCases) { m in
                Button {
                    mode = m
                } label: {
                    Text(m.label)
                        .font(AppFont.medium(12))
                        .kerning(0.24)
                        .lineLimit(1)
                        .foregroundStyle(mode == m ? Tokens.ink : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            mode == m ? Tokens.yellow : Color.clear,
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: openLibrary) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Tokens.yellow)
                    .frame(width: 38, height: 38)
                    .background(Tokens.glassGradient, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
