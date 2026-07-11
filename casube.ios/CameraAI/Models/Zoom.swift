import CoreGraphics

/// Zoom chips. `displayFactor` is the optical-style multiplier shown to the user;
/// CameraController translates it to AVCaptureDevice.videoZoomFactor (which is
/// relative to the widest lens on virtual multi-cam devices).
enum Zoom: String, CaseIterable, Identifiable {
    case x0_5 = "0.5x"
    case x1 = "1x"
    case x2 = "2x"
    case x3 = "3x"
    case x5 = "5x"

    var id: String { rawValue }

    var displayFactor: CGFloat {
        switch self {
        case .x0_5: 0.5
        case .x1: 1
        case .x2: 2
        case .x3: 3
        case .x5: 5
        }
    }
}
