import SwiftUI
import Photos

/// "Thư viện ảnh" bottom sheet — shows every photo from the iPhone library via
/// PhotoKit. Display-only for now: tapping a thumbnail does nothing yet (no
/// selection consumer exists).
struct PhotoLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = PhotoLibraryModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    /// Approximate square cell edge in points, for thumbnail target sizing.
    private var cellPointSize: CGFloat {
        let horizontalInsets: CGFloat = 20 * 2
        let interItemSpacing: CGFloat = 8 * 2
        let available = UIScreen.main.bounds.width - horizontalInsets - interItemSpacing
        return max(80, available / 3)
    }

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

            content
        }
        .padding(.bottom, 22)
        .background(Color.white)
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .idle, .loading:
            Spacer(minLength: 0)
            ProgressView()
                .tint(Tokens.muted)
            Spacer(minLength: 0)
        case .denied:
            deniedState
        case .loaded:
            if model.assets.isEmpty {
                Spacer(minLength: 0)
                Text("Chưa có ảnh nào trong thư viện.")
                    .font(AppFont.regular(13))
                    .foregroundStyle(Tokens.muted)
                Spacer(minLength: 0)
            } else {
                grid
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(model.assets, id: \.localIdentifier) { asset in
                    PhotoThumbnail(
                        asset: asset,
                        pointSize: cellPointSize,
                        model: model
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(Tokens.muted)
            Text("Camera.AI cần quyền truy cập thư viện ảnh")
                .font(AppFont.medium(14))
                .foregroundStyle(Tokens.ink)
            Text("Vào Cài đặt để cấp quyền thư viện ảnh cho ứng dụng.")
                .font(AppFont.regular(12))
                .foregroundStyle(Tokens.muted)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Mở Cài đặt")
                    .font(AppFont.medium(13))
                    .foregroundStyle(Tokens.ink)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 18)
                    .background(Tokens.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(24)
    }
}

/// Single grid cell that asynchronously loads its thumbnail from PhotoKit,
/// showing a neutral placeholder until the image arrives.
private struct PhotoThumbnail: View {
    let asset: PHAsset
    let pointSize: CGFloat
    let model: PhotoLibraryModel

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Tokens.chipIdle)
                .aspectRatio(1, contentMode: .fit)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(Tokens.muted.opacity(0.6))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: asset.localIdentifier) {
            model.requestThumbnail(for: asset, pointSize: pointSize) { loaded in
                if let loaded { image = loaded }
            }
        }
    }
}
