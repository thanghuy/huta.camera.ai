import SwiftUI
import Photos
import PhotosUI
import UIKit

/// "Thư viện ảnh" bottom sheet — real recent photos from the device Photos library via
/// PhotoKit (WIN-12). Layout is unchanged from the original stub: 3-column grid, same
/// header/drag-handle chrome. Only the data source changed from `[Color]` to `[PHAsset]`.
struct PhotoLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CameraStore.self) private var store

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

    @State private var access: LibraryAccess = .notDetermined
    @State private var assets: [PHAsset] = []
    /// Index into `assets` of the photo currently under full-screen review, or `nil`
    /// when the review isn't showing. Index-based (not an `Identifiable` wrapper) so
    /// `PhotoReviewView` can page through neighbors without re-deriving position.
    @State private var reviewIndex: Int?
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
        // Swiping down (or tapping the close affordance) inside the review always
        // returns straight to the camera — there's no "back to grid" step, matching
        // the stock Camera app's photo-review ↔ camera relationship. `onDismiss` fires
        // only after the cover has finished animating away, so the sheet closes as a
        // second, sequenced step instead of both presentations tearing down at once
        // (which SwiftUI logs as an "already presenting" warning).
        .fullScreenCover(
            isPresented: Binding(
                get: { reviewIndex != nil },
                set: { if !$0 { reviewIndex = nil } }
            ),
            onDismiss: { store.isPhotoLibraryOpen = false }
        ) {
            if let reviewIndex {
                PhotoReviewView(assets: assets, initialIndex: reviewIndex) {
                    self.reviewIndex = nil
                }
            }
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
                        if let index = assets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
                            reviewIndex = index
                        }
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

/// Camera-app-style photo review: full-screen paging through `assets` starting at
/// `initialIndex`, pinch/double-tap zoom per page, swipe-down (or the chevron) to
/// dismiss straight back to the camera. No edit/share/delete toolbar — out of WIN-12
/// scope, the ticket only asks for view/swipe/zoom/dismiss.
private struct PhotoReviewView: View {
    let assets: [PHAsset]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int

    init(assets: [PHAsset], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.assets = assets
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(assets.indices, id: \.self) { index in
                ZoomablePhotoPage(
                    asset: assets[index],
                    // Only the current page and its immediate neighbors load full-res —
                    // TabView(.page) doesn't guarantee it keeps distant pages out of
                    // memory the way a Lazy*Stack does, and a library can be thousands
                    // of assets long, so this window is what actually bounds memory.
                    isNearCurrent: abs(index - currentIndex) <= 1,
                    onSwipeDownDismiss: onDismiss
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden(true)
        .overlay(alignment: .topLeading) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

/// One page of the review: loads its own full-res image, supports pinch-to-zoom with
/// pan while zoomed, double-tap to toggle zoom, and a vertical swipe-to-dismiss that's
/// only live while unzoomed (so it can't fight one-finger panning of a zoomed photo).
private struct ZoomablePhotoPage: View {
    let asset: PHAsset
    let isNearCurrent: Bool
    let onSwipeDownDismiss: () -> Void

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissDrag: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4
    private let doubleTapScale: CGFloat = 2.5
    private let dismissThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height + dismissDrag.height)
                        .opacity(dismissOpacity)
                        .gesture(magnificationGesture())
                        .simultaneousGesture(panGesture(in: geo.size))
                        .highPriorityGesture(swipeDownGesture)
                        .onTapGesture(count: 2) { toggleZoom() }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: "\(asset.localIdentifier)-\(isNearCurrent)") {
            if isNearCurrent {
                await loadFullImage()
            } else {
                image = nil
            }
        }
        .onChange(of: asset.localIdentifier) { resetZoom() }
    }

    private var dismissOpacity: CGFloat {
        guard dismissDrag.height > 0 else { return 1 }
        return max(0.4, 1 - dismissDrag.height / 600)
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if scale > minScale {
                scale = minScale
                lastScale = minScale
                offset = .zero
                lastOffset = .zero
            } else {
                scale = doubleTapScale
                lastScale = doubleTapScale
            }
        }
    }

    private func resetZoom() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
        dismissDrag = .zero
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(maxScale, max(minScale, lastScale * value))
            }
            .onEnded { _ in
                lastScale = scale
                if scale == minScale {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    /// One-finger pan, only meaningful once zoomed — clamped so the image can't be
    /// dragged past its own scaled bounds.
    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                let maxOffsetX = size.width * (scale - 1) / 2
                let maxOffsetY = size.height * (scale - 1) / 2
                offset = CGSize(
                    width: min(maxOffsetX, max(-maxOffsetX, lastOffset.width + value.translation.width)),
                    height: min(maxOffsetY, max(-maxOffsetY, lastOffset.height + value.translation.height))
                )
            }
            .onEnded { _ in
                guard scale > minScale else { return }
                lastOffset = offset
            }
    }

    /// Vertical drag that follows the finger and fades the backdrop, mirroring the
    /// stock Camera app's interactive dismiss. Bails out while zoomed so it never
    /// competes with `panGesture` for the same one-finger drag — checked inside the
    /// gesture itself (rather than by conditionally attaching the gesture) since
    /// `.highPriorityGesture` needs a concrete `Gesture`, not an optional one.
    private var swipeDownGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard scale <= minScale else { return }
                // Ignore mostly-horizontal drags so TabView's own paging gesture keeps
                // first claim on left/right swipes.
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dismissDrag = CGSize(width: 0, height: max(0, value.translation.height))
            }
            .onEnded { value in
                guard scale <= minScale else { return }
                if value.translation.height > dismissThreshold {
                    onSwipeDownDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissDrag = .zero
                    }
                }
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
