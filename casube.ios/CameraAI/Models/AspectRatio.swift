import CoreGraphics

/// Photo aspect ratio. Drives both the viewfinder preview box and the post-capture
/// crop. Persisted across launches (see CameraStore).
enum AspectRatio: String, CaseIterable, Identifiable {
    case r4_3 = "4:3"
    case r16_9 = "16:9"
    case r1_1 = "1:1"

    var id: String { rawValue }

    /// Portrait width/height ratio of the preview box (4:3 photo → 3/4 box, etc.).
    var previewRatio: CGFloat {
        switch self {
        case .r4_3: 3.0 / 4.0
        case .r16_9: 9.0 / 16.0
        case .r1_1: 1.0
        }
    }

    /// Centered crop rect for a captured image of `size`, honoring this ratio.
    /// Works for both portrait and landscape source buffers by matching the
    /// long/short side to the ratio's long/short side.
    func cropRect(for size: CGSize) -> CGRect {
        let longOverShort: CGFloat
        switch self {
        case .r4_3: longOverShort = 4.0 / 3.0
        case .r16_9: longOverShort = 16.0 / 9.0
        case .r1_1: longOverShort = 1.0
        }
        let isPortrait = size.height >= size.width
        let target = isPortrait
            ? CGSize(width: 1, height: longOverShort)
            : CGSize(width: longOverShort, height: 1)

        let scale = min(size.width / target.width, size.height / target.height)
        let cropSize = CGSize(width: target.width * scale, height: target.height * scale)
        return CGRect(
            x: (size.width - cropSize.width) / 2,
            y: (size.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )
    }
}
