import SwiftUI
import Observation

/// App-wide camera UI state (the zustand equivalent). Aspect ratio persists
/// across launches via UserDefaults.
@Observable
final class CameraStore {
    private static let aspectRatioKey = "cameraai.aspectRatio"

    var mode: CameraMode = .nguoi
    var zoom: Zoom = .x1
    var aspectRatio: AspectRatio {
        didSet { UserDefaults.standard.set(aspectRatio.rawValue, forKey: Self.aspectRatioKey) }
    }

    var selectedPoseID: Int? = nil
    /// nil = "Tất cả"
    var libraryCategory: PoseCategory? = nil
    var isPoseLibraryOpen = false
    var isPhotoLibraryOpen = false
    var isAspectMenuOpen = false
    var showSavedToast = false

    /// Live match state. M1: set by the DEBUG dev switch. M4: written by
    /// PoseDetector (the dev switch then acts as a manual override).
    var matchState: MatchState = .none
    #if DEBUG
    /// When set, overrides the AI-driven match state (dev switch).
    var manualMatchState: MatchState? = nil
    #endif

    /// The single value every match-driven visual reads.
    var displayMatchState: MatchState {
        #if DEBUG
        if let manualMatchState { return manualMatchState }
        #endif
        return matchState
    }

    var selectedPose: ReferencePose? { ReferencePose.pose(withID: selectedPoseID) }

    var filteredPoses: [ReferencePose] {
        guard let libraryCategory else { return ReferencePose.all }
        return ReferencePose.all.filter { $0.category == libraryCategory }
    }

    /// Auto-capture state tracker (WIN-9)
    /// Tracks perfect pose dwell time & cooldown for automatic photo capture
    private(set) var autoCaptureTracker = PerfectStateTracker(dwellTimeMs: 500, cooldownMs: 2000)

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.aspectRatioKey),
           let saved = AspectRatio(rawValue: raw) {
            aspectRatio = saved
        } else {
            aspectRatio = .r4_3
        }
    }

    func selectPose(_ pose: ReferencePose) {
        selectedPoseID = pose.id
        isPoseLibraryOpen = false
        resetAutoCapture()  // Reset tracker when pose changes
    }

    /// Reset auto-capture state (called on pose/mode changes)
    func resetAutoCapture() {
        autoCaptureTracker.reset()
    }

    /// Update auto-capture tracker with current match state
    /// Call this after every pose matching update
    func updateAutoCaptureState(matchState: MatchState) {
        autoCaptureTracker.update(matchState: matchState)
    }
}
