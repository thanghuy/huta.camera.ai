import CoreGraphics

/// Capture modes. `nhom` (group) is UI-only — no real multi-person scoring in the MVP.
enum CameraMode: String, CaseIterable, Identifiable {
    case nguoi, can, nhom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nguoi: "CHỤP NGƯỜI"
        case .can: "CHỤP CẬN"
        case .nhom: "CHỤP NHÓM"
        }
    }

    /// Silhouette layout per mode, mirroring the mockup FRAMES table.
    var figureViewBox: CGRect {
        switch self {
        case .nguoi, .nhom: CGRect(x: 0, y: 0, width: 200, height: 360)
        case .can: CGRect(x: 45, y: 0, width: 110, height: 165) // face crop
        }
    }

    var figureSize: CGSize {
        switch self {
        case .nguoi: CGSize(width: 165, height: 297)
        case .can: CGSize(width: 168, height: 252)
        case .nhom: CGSize(width: 62, height: 112)
        }
    }

    var figureCount: Int { self == .nhom ? 3 : 1 }
    var figureGap: CGFloat { self == .nhom ? 14 : 0 }
}
