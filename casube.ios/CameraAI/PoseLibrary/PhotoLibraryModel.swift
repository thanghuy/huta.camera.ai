import UIKit
import Photos
import Observation

/// Backs `PhotoLibrarySheet`: requests read access, fetches every image asset
/// newest-first, and vends thumbnails on demand through a caching image manager.
@Observable
@MainActor
final class PhotoLibraryModel {
    enum LoadState {
        case idle
        case loading
        case loaded
        case denied
    }

    private(set) var loadState: LoadState = .idle
    /// Read authorization as reported by PhotoKit.
    private(set) var status: PHAuthorizationStatus = .notDetermined
    /// Fetched image assets, newest first. Indexed by the grid.
    private(set) var assets: [PHAsset] = []

    /// True while access is granted only to a user-picked subset of photos.
    var isLimited: Bool { status == .limited }
    var assetCount: Int { assets.count }

    private var fetchResult: PHFetchResult<PHAsset>?
    private let imageManager = PHCachingImageManager()

    /// Kicks off authorization + fetch. Safe to call repeatedly (e.g. from
    /// `.task`); re-runs only re-evaluate the current status.
    func load() async {
        loadState = .loading
        let requested = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        status = requested
        switch requested {
        case .authorized, .limited:
            fetchAssets()
            loadState = .loaded
        case .denied, .restricted, .notDetermined:
            assets = []
            loadState = .denied
        @unknown default:
            assets = []
            loadState = .denied
        }
    }

    private func fetchAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        fetchResult = result
        var collected: [PHAsset] = []
        collected.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in collected.append(asset) }
        assets = collected
    }

    /// Loads a thumbnail for `asset` sized for a square grid cell. `pointSize`
    /// is the cell's edge in points; the manager scales to pixels internally.
    /// The completion may fire more than once (opportunistic low-res then full).
    func requestThumbnail(
        for asset: PHAsset,
        pointSize: CGFloat,
        completion: @escaping (UIImage?) -> Void
    ) {
        let scale = UIScreen.main.scale
        let target = CGSize(width: pointSize * scale, height: pointSize * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        imageManager.requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}
