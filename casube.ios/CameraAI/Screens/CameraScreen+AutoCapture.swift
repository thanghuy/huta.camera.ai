import SwiftUI

/// Extension for CameraScreen to handle auto-capture via PerfectStateTracker
/// 
/// Integrates PerfectStateTracker state machine into the camera pipeline:
/// - Track perfect state with dwell time
/// - Trigger auto-capture after perfect held stable
/// - Respect cooldown between captures
/// - Cancel if state changes away from perfect
extension CameraScreen {
    
    /// Setup auto-capture state machine
    /// Call once in CameraScreen.onAppear or init
    func setupAutoCaptureTracker() -> PerfectStateTracker {
        return PerfectStateTracker(dwellTimeMs: 500, cooldownMs: 2000)
    }
    
    /// Wire PerfectStateTracker into the pose-matching pipeline
    /// Call this after pose matching result is available
    ///
    /// Usage in CameraScreen.controller.onFrame:
    /// ```swift
    /// let result = PoseMatcher.match(live: live, reference: target)
    /// DispatchQueue.main.async {
    ///     store.matchState = result.state
    ///     autoCaptureTracker.update(matchState: result.state)
    /// }
    /// ```
    func wireAutoCaptureTracker(
        _ tracker: PerfectStateTracker,
        store: CameraStore
    ) {
        // Listen for auto-capture trigger
        _ = tracker.$shouldCapture
            .filter { $0 }
            .sink { _ in
                // Auto-capture triggered by dwell time
                self.capturePhotoWithFeedback(reason: .autoCaptureAfterDwell)
            }
    }
    
    /// Enhanced capture with context about why capture happened
    func capturePhotoWithFeedback(reason: CaptureTrigger) {
        switch reason {
        case .autoCaptureAfterDwell:
            // Auto-capture: stronger haptic
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .manualShutterButton:
            // Manual: normal haptic
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        
        let ratio = store.aspectRatio
        controller.capturePhoto { image in
            guard let image else { return }
            Task {
                do {
                    try await PhotoSaver.save(image, croppedTo: ratio)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.showToast()
                } catch {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
    
    enum CaptureTrigger {
        case autoCaptureAfterDwell
        case manualShutterButton
    }
}

// MARK: - CameraStore Integration

extension CameraStore {
    /// Auto-capture state tracker (part of camera stream state)
    /// Note: CameraStore should add this property:
    /// @Published var autoCaptureTracker = PerfectStateTracker()
    
    /// Reset auto-capture state when changing modes or clearing
    func resetAutoCapture() {
        // This should be called when:
        // - Mode changes (full-body → close-up)
        // - Clear button pressed
        // - Photo saved (ready for next)
        // autoCaptureTracker.reset()
    }
}
