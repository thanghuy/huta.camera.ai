import SwiftUI
import Combine

/// Extension showing how to wire auto-capture into CameraScreen
/// These changes should be integrated into CameraScreen.swift

extension CameraScreen {
    
    /// Setup auto-capture listener in body's .onAppear
    /// Add this to CameraScreen.body:
    /// ```swift
    /// .onAppear { setupAutoCapture() }
    /// ```
    func setupAutoCapture() {
        // Listen for auto-capture trigger from PerfectStateTracker
        _ = store.autoCaptureTracker.$shouldCapture
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.capturePhotoForAutoCapture()
            }
    }
    
    /// Modified capturePhoto() to accept trigger type
    /// Replace existing capturePhoto() with this:
    func capturePhotoForAutoCapture() {
        // Auto-capture: stronger haptic feedback
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        performPhotoCapture()
    }
    
    /// Modify ShutterButton callback to include cooldown check:
    /// Change in actionRow:
    /// ```swift
    /// ShutterButton(state: store.displayMatchState) {
    ///     // Check cooldown before allowing manual capture
    ///     if !store.autoCaptureTracker.isInCooldown {
    ///         capturePhotoManual()
    ///     }
    /// }
    /// ```
    func capturePhotoManual() {
        // Manual capture: normal haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        performPhotoCapture()
    }
    
    /// Actual photo capture logic (shared by both auto and manual)
    private func performPhotoCapture() {
        let ratio = store.aspectRatio
        controller.capturePhoto { image in
            guard let image else { return }
            Task {
                do {
                    try await PhotoSaver.save(image, croppedTo: ratio)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showToast()
                } catch {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
    
    /// Modify startCamera() to wire match state updates to tracker:
    /// Replace the .onFrame closure with:
    /// ```swift
    /// controller.onFrame = { pixelBuffer, orientation in
    ///     guard store.mode != .nhom else { return }
    ///     guard let live = detector.detect(in: pixelBuffer, orientation: orientation) else { return }
    ///
    ///     let reference = store.selectedPose?.keypoints ?? .standing()
    ///     let target = store.mode == .can ? reference.upperBody : reference
    ///     let result = PoseMatcher.match(live: live, reference: target)
    ///
    ///     DispatchQueue.main.async {
    ///         store.matchState = result.state
    ///         // NEW: Feed state to auto-capture tracker
    ///         store.updateAutoCaptureState(matchState: result.state)
    ///     }
    /// }
    /// ```
    
    /// Add this onChange modifier in body:
    /// ```swift
    /// .onChange(of: store.mode) { _, newMode in
    ///     if newMode == .nhom {
    ///         store.matchState = .none
    ///     }
    ///     // NEW: Reset auto-capture when mode changes
    ///     store.resetAutoCapture()
    /// }
    /// ```
}

// MARK: - Summary of CameraScreen Changes for WIN-9

/*
 CHANGES NEEDED IN CameraScreen.swift:
 
 1. In body, add after .sheet modifiers:
    .onAppear { setupAutoCapture() }
 
 2. In body, modify onChange for store.mode:
    .onChange(of: store.mode) { _, newMode in
        if newMode == .nhom { store.matchState = .none }
        store.resetAutoCapture()  // NEW
    }
 
 3. In startCamera(), modify controller.onFrame closure:
    DispatchQueue.main.async {
        store.matchState = result.state
        store.updateAutoCaptureState(matchState: result.state)  // NEW
    }
 
 4. Rename existing capturePhoto() to capturePhotoManual()
    
 5. Update ShutterButton closure:
    ShutterButton(state: store.displayMatchState) {
        if !store.autoCaptureTracker.isInCooldown {
            capturePhotoManual()  // Changed from capturePhoto()
        }
    }
 
 6. Remove old capturePhoto() - use performPhotoCapture() (shared logic)
    
 7. Add new setupAutoCapture() method from extension above
 
 HAPTIC FEEDBACK:
 - Auto-capture: UIImpactFeedbackGenerator(style: .heavy)
 - Manual shutter: UIImpactFeedbackGenerator(style: .medium)
 - Success: UINotificationFeedbackGenerator() [kept same]
 
 SIDE EFFECTS:
 - Perfect pose → dwell 500ms → auto-capture
 - Capture starts 2s cooldown
 - During cooldown, manual shutter is disabled
 - Leaving perfect state cancels pending auto-capture
 - Mode/pose change resets tracker
 */
