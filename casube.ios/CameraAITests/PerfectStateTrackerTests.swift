import XCTest
@testable import CameraAI

/// Tests for PerfectStateTracker auto-capture state machine (WIN-9)
final class PerfectStateTrackerTests: XCTestCase {

    var tracker: PerfectStateTracker!

    override func setUp() {
        super.setUp()
        // Use short timings for tests (100ms dwell, 200ms cooldown)
        tracker = PerfectStateTracker(dwellTimeMs: 100, cooldownMs: 200)
    }

    override func tearDown() {
        tracker.reset()
        tracker = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitialState() {
        XCTAssertEqual(tracker.currentState, .none)
        XCTAssertFalse(tracker.shouldCapture)
        XCTAssertFalse(tracker.isInCooldown)
        XCTAssertEqual(tracker.dwellProgress, 0.0)
    }

    // MARK: - Perfect State Tracking

    func testBecomingPerfectStartsDwell() {
        tracker.update(matchState: .perfect)
        XCTAssertEqual(tracker.currentState, .perfect)
        // Dwell timer should be active (progress starts increasing)
        let initialProgress = tracker.dwellProgress
        
        // Wait a bit and check progress
        usleep(50000)  // 50ms
        tracker.update(matchState: .perfect)
        
        // Progress should have increased (but not completed yet)
        XCTAssertGreater(tracker.dwellProgress, initialProgress)
        XCTAssertLess(tracker.dwellProgress, 1.0)
    }

    func testLeavingPerfectCancelsDwell() {
        tracker.update(matchState: .perfect)
        usleep(30000)  // Partially through dwell
        
        tracker.update(matchState: .close)
        
        XCTAssertEqual(tracker.currentState, .close)
        XCTAssertFalse(tracker.shouldCapture, "should not capture when leaving perfect")
        XCTAssertEqual(tracker.dwellProgress, 0.0, "dwell progress should reset")
    }

    // MARK: - Auto-Capture Trigger

    func testDwellCompletionTriggerCapture() {
        let expectation = XCTestExpectation(description: "Capture triggered after dwell")
        var captureTriggered = false
        
        let cancellable = tracker.$shouldCapture
            .filter { $0 }
            .sink { _ in
                captureTriggered = true
                expectation.fulfill()
            }
        
        tracker.update(matchState: .perfect)
        
        // Wait for dwell to complete (100ms + buffer)
        wait(for: [expectation], timeout: 0.5)
        
        XCTAssertTrue(captureTriggered, "capture should trigger after dwell completes")
        XCTAssertTrue(tracker.isInCooldown, "cooldown should start after capture")
        
        _ = cancellable
    }

    func testCooldownPreventsRapidCapture() {
        tracker.update(matchState: .perfect)
        
        // Wait for first capture
        usleep(150000)  // 150ms
        
        XCTAssertTrue(tracker.isInCooldown, "should be in cooldown after capture")
        
        // Try to trigger again immediately
        tracker.update(matchState: .perfect)
        usleep(50000)
        tracker.update(matchState: .perfect)
        
        // Should NOT trigger second capture while in cooldown
        let shouldCaptureCount = tracker.shouldCapture ? 1 : 0
        XCTAssertEqual(shouldCaptureCount, 0, "should not trigger capture during cooldown")
    }

    func testCooldownTimesOut() {
        tracker.forceCapture()
        XCTAssertTrue(tracker.isInCooldown)
        
        // Wait for cooldown to expire (200ms + buffer)
        usleep(250000)  // 250ms
        
        XCTAssertFalse(tracker.isInCooldown, "cooldown should expire")
    }

    // MARK: - Manual Capture

    func testForceCaptureTriggers() {
        tracker.forceCapture()
        
        XCTAssertTrue(tracker.shouldCapture, "force capture should set shouldCapture flag")
        XCTAssertTrue(tracker.isInCooldown, "force capture should start cooldown")
    }

    func testForceCaptureDuringCooldownIgnored() {
        tracker.forceCapture()
        XCTAssertTrue(tracker.isInCooldown)
        
        let shouldCaptureCount = tracker.shouldCapture ? 1 : 0
        tracker.forceCapture()
        
        // Should not trigger additional capture
        XCTAssertEqual(shouldCaptureCount, 0, "force capture during cooldown should be ignored")
    }

    func testManualShutterRespectsCooldown() {
        // Scenario: Auto-capture triggered, then user taps shutter
        tracker.update(matchState: .perfect)
        usleep(150000)  // Wait for auto-capture
        
        XCTAssertTrue(tracker.isInCooldown)
        
        // User tries to tap shutter
        tracker.forceCapture()
        
        // Should be ignored
        XCTAssertTrue(tracker.isInCooldown, "manual shutter should respect cooldown")
    }

    // MARK: - State Transitions

    func testPerfectThenCloseCancelsPending() {
        tracker.update(matchState: .perfect)
        usleep(50000)  // Halfway through dwell
        
        tracker.update(matchState: .close)
        
        // Wait longer than original dwell would take
        usleep(100000)  // 100ms more
        
        // Should NOT have triggered capture
        XCTAssertFalse(tracker.isInCooldown, "capture should not trigger if perfect interrupted")
    }

    func testPerfectFarPerfectDwellRestarts() {
        tracker.update(matchState: .perfect)
        usleep(50000)
        
        tracker.update(matchState: .far)
        usleep(10000)
        
        tracker.update(matchState: .perfect)
        // Dwell should restart from scratch
        
        usleep(150000)  // Wait longer than full dwell
        
        XCTAssertTrue(tracker.isInCooldown, "should complete full dwell after re-entering perfect")
    }

    // MARK: - Reset

    func testResetClearsState() {
        tracker.update(matchState: .perfect)
        usleep(50000)
        
        tracker.reset()
        
        XCTAssertEqual(tracker.currentState, .none)
        XCTAssertFalse(tracker.shouldCapture)
        XCTAssertFalse(tracker.isInCooldown)
        XCTAssertEqual(tracker.dwellProgress, 0.0)
    }

    func testResetCancelsPendingCapture() {
        tracker.update(matchState: .perfect)
        usleep(50000)  // Partial dwell
        
        tracker.reset()
        
        usleep(100000)  // Wait past original dwell time
        
        // Should not trigger
        XCTAssertFalse(tracker.isInCooldown, "reset should cancel pending capture")
    }

    // MARK: - Edge Cases

    func testDwellProgressAccuracy() {
        tracker.update(matchState: .perfect)
        
        usleep(50000)  // 50% through 100ms dwell
        tracker.update(matchState: .perfect)
        
        let progress50 = tracker.dwellProgress
        XCTAssertGreater(progress50, 0.4, "50% through dwell should be ~0.5")
        XCTAssertLess(progress50, 0.6)
    }

    func testMultiplePerfectStateUpdatesWork() {
        // Continuously send perfect state (simulating 60 FPS pose matching)
        for _ in 0..<10 {
            tracker.update(matchState: .perfect)
            usleep(16666)  // ~60 FPS frame interval
        }
        
        // Should still be in dwell or completed
        XCTAssertTrue(tracker.currentState == .perfect)
    }

    func testDebugInfoReturnsString() {
        let debugInfo = tracker.debugInfo()
        XCTAssertTrue(debugInfo.contains("State:"))
        XCTAssertTrue(debugInfo.contains("dwell:"))
    }

    // MARK: - Real-World Scenarios

    func testScenarioGoodPose() {
        // User holds perfect pose for 200ms → auto-capture
        tracker.update(matchState: .perfect)
        usleep(200000)
        
        XCTAssertTrue(tracker.isInCooldown, "should have captured")
        
        // User keeps pose but can't capture again until cooldown ends
        tracker.update(matchState: .perfect)
        tracker.forceCapture()
        XCTAssertTrue(tracker.isInCooldown)
    }

    func testScenarioShaky() {
        // User's pose jumps around: perfect → close → perfect → far → perfect
        tracker.update(matchState: .perfect)
        usleep(30000)
        
        tracker.update(matchState: .close)
        usleep(20000)
        
        tracker.update(matchState: .perfect)
        usleep(30000)
        
        tracker.update(matchState: .far)
        usleep(10000)
        
        tracker.update(matchState: .perfect)
        usleep(100000)  // Wait for full dwell from last perfect
        
        // Should eventually capture
        XCTAssertTrue(tracker.isInCooldown, "should capture after stable perfect")
    }
}
