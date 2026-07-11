import UIKit
import Photos

/// Crops a captured photo to the selected aspect ratio and saves it straight
/// to the photo library (add-only permission).
enum PhotoSaver {
    enum SaveError: Error {
        case notAuthorized
    }

    static func save(_ image: UIImage, croppedTo ratio: AspectRatio) async throws {
        let cropped = crop(image, to: ratio)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.notAuthorized
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: cropped)
        }
    }

    /// Center-crops to the ratio. Renders first to bake in EXIF orientation so
    /// CGImage cropping operates on upright pixels.
    static func crop(_ image: UIImage, to ratio: AspectRatio) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        let rect = ratio.cropRect(for: upright.size)
        guard let cg = upright.cgImage?.cropping(to: rect) else { return upright }
        return UIImage(cgImage: cg)
    }
}
