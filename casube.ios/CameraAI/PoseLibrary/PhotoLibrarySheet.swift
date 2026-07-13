import SwiftUI
import Photos
import PhotosUI
import UIKit

/// "Thư viện ảnh" bottom sheet — real recent photos from the device Photos library via
/// PhotoKit (WIN-12). Layout is unchanged from the original stub: 3-column grid, same
/// header/drag-handle chrome. Only the data source changed from `[Color]` to `[PHAsset]`.
struct PhotoLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Mirrors `PHAuthorizationStatus` (`.readOnly` level) 1:1, including `.restricted`
    /// (parental controls/MDM) which the ticket's "4 states" language omits — it needs
    /// the same "no access" UI as `.denied`.
    private enum LibraryAccess {
        case notDetermined, authorized, limited, denied, restricted

        init(_ status: PHAuthorizationStatus) {
            switch status {
            case .notDetermined: self = .notDetermined
            case .authorized: self = .authorized
            case .limited: self = .limited
            case .restricted: self = .restricted
            case .denied: self = .denied
            @unknown default: self = .denied
            }
        }
    }

    private struct GalleryPhoto: Identifiable {
        let asset: PHAsset
        var id: String { asset.localIdentifier }
    }

    @State private var access: LibraryAccess = .notDetermined
    @State private var assets: [PHAsset] = []
    @State private var viewingPhoto: GalleryPhoto?
    @State private var imageManager = PHCachingImageManager()

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
        .task { await start() }
        .onDisappear { imageManager.stopCachingImagesForAllAssets() }
        .fullScreenCover(item: $viewingPhoto) { photo in
            PhotoFullScreenView(asset: photo.asset)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch access {
        case .notDetermined:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .authorized, .limited:
            if assets.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    if access == .limited {
                        limitedAccessBanner
                    }
                    grid
                }
            }
        case .denied, .restricted:
            deniedState
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    AssetThumbnailCell(
                        asset: asset,
                        imageManager: imageManager,
                        targetSize: thumbnailTargetSize
                    ) {
                        viewingPhoto = GalleryPhoto(asset: asset)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private var limitedAccessBanner: some View {
        Button {
            presentLimitedLibraryPicker()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text("Chọn thêm ảnh")
            }
            .font(AppFont.medium(13))
            .foregroundStyle(Tokens.ink)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
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
                openSettings()
            } label: {
                Text("Mở Cài đặt")
                    .font(AppFont.medium(13))
                    .foregroundStyle(Tokens.ink)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 18)
                    .background(Tokens.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 26))
                .foregroundStyle(Tokens.muted)
            Text("Chưa có ảnh nào")
                .font(AppFont.medium(13))
                .foregroundStyle(Tokens.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - PhotoKit

    /// Grid cell size in pixels — 3 columns, 20pt outer padding, 8pt spacing, scaled for
    /// the device's screen density (PHImageManager targetSize is in pixels, not points).
    private var thumbnailTargetSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let cellWidth = (screenWidth - 40 - 16) / 3
        let scale = UIScreen.main.scale
        return CGSize(width: cellWidth * scale, height: cellWidth * scale)
    }

    private func start() async {
        // PHAccessLevel only has `.addOnly`/`.readWrite` — there is no separate
        // read-only level. `.readWrite` is the level you request even to just browse
        // the library; it does not grant edit/delete beyond what Photos already asks
        // the user to confirm per-action.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            access = LibraryAccess(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
        } else {
            access = LibraryAccess(status)
        }
        guard access == .authorized || access == .limited else { return }
        await loadAssets()
    }

    private func loadAssets() async {
        assets = await Task.detached(priority: .userInitiated) { () -> [PHAsset] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(with: .image, options: options)
            var items: [PHAsset] = []
            items.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in items.append(asset) }
            return items
        }.value
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func presentLimitedLibraryPicker() {
        // Not PHPickerViewController — this is the system sheet that manages the
        // user's existing limited selection, and needs a concrete presenting VC.
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }
}

/// One grid cell: loads its own thumbnail, tied to the asset's identity so SwiftUI
/// cancels the in-flight request automatically if the cell is torn down — no stale
/// completion can paint a different asset's cell (each asset gets its own persistent
/// view/state via `ForEach(assets, id: \.localIdentifier)`, unlike UIKit cell reuse).
private struct AssetThumbnailCell: View {
    let asset: PHAsset
    let imageManager: PHCachingImageManager
    let targetSize: CGSize
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Tokens.chipIdle
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
        .onAppear {
            imageManager.startCachingImages(
                for: [asset], targetSize: targetSize, contentMode: .aspectFill, options: nil
            )
        }
        .onDisappear {
            imageManager.stopCachingImages(
                for: [asset], targetSize: targetSize, contentMode: .aspectFill, options: nil
            )
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.isNetworkAccessAllowed = false

        // No manual PHImageRequestID cancellation needed: this cell is keyed to a
        // stable asset identity via `ForEach(assets, id: \.localIdentifier)` (unlike
        // UIKit cell reuse), and `.task(id:)` already cancels this async work when the
        // cell is torn down — see the skill's "stale completion" note.
        await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { result, info in
                // PHImageManager's handler fires off the main thread.
                DispatchQueue.main.async {
                    if let result { image = result }
                }
                // Opportunistic delivery can call back twice (low-res, then final) —
                // only resume the continuation once, on the non-degraded delivery.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded, !didResume {
                    didResume = true
                    continuation.resume()
                }
            }
        }
    }
}

/// Simple full-size viewer — no QuickLook/zoom polish per ticket scope.
private struct PhotoFullScreenView: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .task(id: asset.localIdentifier) {
            await loadFullImage()
        }
    }

    private func loadFullImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        // Most libraries are iCloud-optimized (no on-device full-res by default) —
        // without this, cloud-only assets come back nil/low-res instead of full-size.
        options.isNetworkAccessAllowed = true

        await withCheckedContinuation { continuation in
            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { result, info in
                DispatchQueue.main.async {
                    if let result { image = result }
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded, !didResume {
                    didResume = true
                    continuation.resume()
                }
            }
        }
    }
}
