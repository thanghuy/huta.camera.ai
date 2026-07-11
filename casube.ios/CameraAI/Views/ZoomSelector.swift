import SwiftUI

/// Horizontal zoom chips (0.5x…5x).
struct ZoomSelector: View {
    @Binding var zoom: Zoom

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Zoom.allCases) { z in
                Button {
                    zoom = z
                } label: {
                    Text(z.rawValue)
                        .font(AppFont.medium(12))
                        .foregroundStyle(zoom == z ? Tokens.ink : .white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            zoom == z ? Tokens.yellow : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }
}
