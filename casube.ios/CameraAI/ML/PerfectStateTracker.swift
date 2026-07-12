import Foundation
import Combine

/// Tracks perfect pose state with dwell time and cooldown for auto-capture
/// 
/// State machine that manages:
/// - Dwell time: how long perfect state must be maintained before triggering capture
/// - Cooldown: prevents capture spam; wait N seconds before allowing next capture
/// - Cancellation: perfect → non-perfect clears pending capture
/// - One-shot: only emit capture event once per dwell period
///
/// Usage:
/// ```swift
/// let tracker = PerfectStateTracker(dwellTimeMs: 500, cooldownMs: 2000)
/// 
/// // Feed match state updates
/// tracker.update(matchState: .perfect)
/// tracker.update(matchState: .perfect)  // Still perfect, timer ticking
/// tracker.update(matchState: .close)    // Not perfect anymore, cancel
/// 
/// // Listen for capture signal
/// tracker.$shouldCapture
///   .filter { $0 }
///   .sink { _ in capturePhoto() }
///   .store(in: &cancellables)
/// ```
@MainActor
class PerfectStateTracker: ObservableObject {
    // MARK: - Configuration
    
    /// Milliseconds to hold perfect state before triggering capture
    private let dwellTimeMs: Int
    
    /// Milliseconds to wait after capture before allowing next capture
    private let cooldownMs: Int
    
    // MARK: - State
    
    /// Current match state (perfect/close/far/none)
    @Published var currentState: MatchState = .none
    
    /// Should trigger capture now?
    @Published var shouldCapture: Bool = false
    
    /// Is currently in cooldown? (prevents rapid captures)
    @Published var isInCooldown: Bool = false
    
    /// Time remaining in current dwell (0…100, for UI progress indicators)
    @Published var dwellProgress: Double = 0.0
    
    // MARK: - Internal State
    
    private var dwellTimer: Timer?
    private var cooldownTimer: Timer?
    private var perfectStartTime: Date?
    private var lastCaptureTime: Date?
    private var isPendingCapture = false
    
    // MARK: - Init
    
    /// Initialize tracker with dwell and cooldown times
    /// - Parameters:
    ///   - dwellTimeMs: Time to hold perfect (default 500ms)
    ///   - cooldownMs: Time to wait between captures (default 2000ms)
    init(dwellTimeMs: Int = 500, cooldownMs: Int = 2000) {
        self.dwellTimeMs = dwellTimeMs
        self.cooldownMs = cooldownMs
    }
    
    // MARK: - Public Interface
    
    /// Update with new match state
    /// Call this every frame when pose matching result changes
    func update(matchState: MatchState) {
        // If state changed, clear any in-progress dwell
        if matchState != currentState {
            currentState = matchState
            
            // If no longer perfect, cancel pending capture
            if matchState != .perfect {
                cancelPendingCapture()
            } else {
                // Became perfect again, start fresh dwell
                startDwellTimer()
            }
        }
    }
    
    /// Force capture immediately (for manual shutter button)
    /// Respects cooldown
    func forceCapture() {
        if isInCooldown {
            return  // Cooldown active, ignore
        }
        
        shouldCapture = true
        startCooldown()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.shouldCapture = false
        }
    }
    
    /// Reset all state (e.g., switching modes or canceling)
    func reset() {
        cancelPendingCapture()
        stopCooldown()
        currentState = .none
        shouldCapture = false
        dwellProgress = 0.0
        lastCaptureTime = nil
    }
    
    // MARK: - Private Timers
    
    private func startDwellTimer() {
        // Cancel existing dwell timer
        dwellTimer?.invalidate()
        
        perfectStartTime = Date()
        isPendingCapture = false
        dwellProgress = 0.0
        
        let updateInterval = 16  // ~60 FPS
        let totalSteps = dwellTimeMs / updateInterval
        var currentStep = 0
        
        dwellTimer = Timer.scheduledTimer(withTimeInterval: Double(updateInterval) / 1000.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            currentStep += 1
            self.dwellProgress = Double(currentStep) / Double(totalSteps)
            
            // Check if dwell time is up
            if currentStep * updateInterval >= self.dwellTimeMs {
                timer.invalidate()
                self.dwellTimer = nil
                
                // Only trigger if still in perfect state
                if self.currentState == .perfect && !self.isInCooldown {
                    self.triggerCapture()
                }
            }
        }
    }
    
    private func cancelPendingCapture() {
        dwellTimer?.invalidate()
        dwellTimer = nil
        isPendingCapture = false
        dwellProgress = 0.0
        perfectStartTime = nil
    }
    
    private func triggerCapture() {
        isPendingCapture = true
        shouldCapture = true
        startCooldown()
        
        // Reset should capture after a frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.shouldCapture = false
        }
    }
    
    private func startCooldown() {
        lastCaptureTime = Date()
        isInCooldown = true
        
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: Double(cooldownMs) / 1000.0, repeats: false) { [weak self] _ in
            self?.isInCooldown = false
        }
    }
    
    private func stopCooldown() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        isInCooldown = false
    }
    
    deinit {
        dwellTimer?.invalidate()
        cooldownTimer?.invalidate()
    }
}

// MARK: - Debug Helpers

extension PerfectStateTracker {
    /// Returns human-readable debug info
    func debugInfo() -> String {
        let cooldownStatus = isInCooldown ? "cooldown active" : "ready"
        let dwellStatus = isPendingCapture ? "pending capture" : "idle"
        return "State: \(currentState.rawValue) | \(cooldownStatus) | \(dwellStatus) | dwell: \(Int(dwellProgress * 100))%"
    }
}
