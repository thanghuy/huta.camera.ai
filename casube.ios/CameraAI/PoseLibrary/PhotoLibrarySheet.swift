import SwiftUI

/// "Thư viện ảnh" bottom sheet — MVP stub grid matching the mockup's colored
/// thumbnails. Wiring real recent photos via PhotoKit is optional later polish.
struct PhotoLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    private let thumbColors: [Color] = [
        Color(hex: 0xD9CBB0), Color(hex: 0x8FA6A1), Color(hex: 0xC6B4D6),
        Color(hex: 0xB7C9E0), Color(hex: 0xE0B7A6), Color(hex: 0xA9C0A0),
        Color(hex: 0xD6C6E8), Color(hex: 0xC9D6A6), Color(hex: 0xB0C9D9),
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Tokens.hairline)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            HStack {
                Text("Thư viện ảnh")
                    .font(AppFont.medium(18))
                    .foregroundStyle(Tokens.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Tokens.ink)
                        .frame(width: 30, height: 30)
                        .background(Tokens.chipIdle, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(Array(thumbColors.enumerated()), id: \.offset) { _, color in
                        ZStack(alignment: .bottomTrailing) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color)
                                .aspectRatio(1, contentMode: .fit)
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .padding(.bottom, 22)
        .background(Color.white)
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }
}
