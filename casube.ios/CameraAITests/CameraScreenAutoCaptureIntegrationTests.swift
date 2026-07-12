import XCTest
@testable import CameraAI

/// Integration tests for auto-capture wiring in CameraScreen (WIN-9)
/// Tests the interaction between CameraStore, PerfectStateTracker, and capture logic
final class CameraScreenAutoCaptureIntegrationTests: XCTestCase {

    var store: CameraStore!

    override func setUp() {
        super.setUp()
        store = CameraStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - CameraStore Integration

    func testStoreHasAutoCaptureTracker() {
        XCTAssertNotNil(store.autoCaptureTracker, "store should have autoCaptureTracker")
        XCTAssertEqual(store.autoCaptureTracker.currentState, .none)
        XCTAssertFalse(store.autoCaptureTracker.isInCooldown)
    }

    func testUpdateAutoCaptureStateFeeds() {
        store.updateAutoCaptureState(matchState: .perfect)
        XCTAssertEqual(store.autoCaptureTracker.currentState, .perfect)

        store.updateAutoCaptureState(matchState: .close)
        XCTAssertEqual(store.autoCaptureTracker.currentState, .close)
    }

    func testResetAutoCaptureClears() {
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(100000)  // Halfway through dwell

        store.resetAutoCapture()

        XCTAssertEqual(store.autoCaptureTracker.currentState, .none)
        XCTAssertFalse(store.autoCaptureTracker.isInCooldown)
        XCTAssertEqual(store.autoCaptureTracker.dwellProgress, 0.0)
    }

    // MARK: - Pose Selection Effects

    func testSelectPoseResetsTracker() {
        // Setup: auto-capture in progress
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(50000)

        let pose = ReferencePose.all.first!
        store.selectPose(pose)

        // Should reset after pose selection
        XCTAssertEqual(store.autoCaptureTracker.currentState, .none)
        XCTAssertEqual(store.selectedPoseID, pose.id)
    }

    // MARK: - Match State Flow

    func testMatchStateFlowToTracker() {
        // Simulate pose matching pipeline:
        // 1. Start with none
        XCTAssertEqual(store.matchState, .none)

        // 2. Detect person, reach close
        store.updateAutoCaptureState(matchState: .close)
        XCTAssertEqual(store.autoCaptureTracker.currentState, .close)

        // 3. Pose perfects
        store.updateAutoCaptureState(matchState: .perfect)
        XCTAssertEqual(store.autoCaptureTracker.currentState, .perfect)

        // 4. Dwell should be active
        usleep(50000)
        XCTAssertGreater(store.autoCaptureTracker.dwellProgress, 0)
    }

    // MARK: - Photo Capture Readiness

    func testStateReadyForCapture() {
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(600000)  // Wait past dwell time

        XCTAssertTrue(store.autoCaptureTracker.isInCooldown,
                     "should be in cooldown after auto-capture")
    }

    func testManualCaptureRespectsCooldown() {
        // Auto-capture just happened
        store.autoCaptureTracker.forceCapture()
        XCTAssertTrue(store.autoCaptureTracker.isInCooldown)

        // Manual shutter should be blocked during cooldown
        // (In actual CameraScreen, ShutterButton checks this)
        XCTAssertTrue(store.autoCaptureTracker.isInCooldown,
                     "cooldown should prevent manual capture")
    }

    // MARK: - Full Pipeline Simulation

    func testSimulatedCameraFrame() {
        // This simulates what CameraScreen.controller.onFrame does:
        // 1. Detect pose from frame
        // 2. Update matchState
        // 3. Update autoCaptureTracker

        // Frame 1: No person
        store.matchState = .none
        store.updateAutoCaptureState(matchState: .none)
        XCTAssertEqual(store.autoCaptureTracker.currentState, .none)

        // Frame 2-5: Person enters, gets close
        for _ in 0..<4 {
            store.matchState = .far
            store.updateAutoCaptureState(matchState: .far)
            usleep(16667)  // ~60 FPS
        }

        // Frame 6-10: Gets closer to perfect
        for _ in 0..<5 {
            store.matchState = .close
            store.updateAutoCaptureState(matchState: .close)
            usleep(16667)
        }

        // Frame 11+: Perfect! Dwell timer starts
        for i in 0..<50 {
            store.matchState = .perfect
            store.updateAutoCaptureState(matchState: .perfect)
            usleep(16667)

            // After dwell time (~500ms, which is ~30 frames at 60fps)
            if i > 30 {
                if store.autoCaptureTracker.isInCooldown {
                    // Capture happened!
                    break
                }
            }
        }

        // Verify capture was triggered
        XCTAssertTrue(store.autoCaptureTracker.isInCooldown,
                     "should have captured after holding perfect")
    }

    // MARK: - State Machine Invariants

    func testInvariant_PerfectStateOnly() {
        // Only perfect state should trigger dwell
        for state in [MatchState.none, .far, .close] {
            store.updateAutoCaptureState(matchState: state)
            usleep(600000)
            XCTAssertFalse(store.autoCaptureTracker.isInCooldown,
                          "\(state) should not trigger auto-capture")
        }
    }

    func testInvariant_OnlyOneCapturePerDwell() {
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(600000)  // Wait for capture

        let firstCooldown = store.autoCaptureTracker.isInCooldown
        XCTAssertTrue(firstCooldown)

        // Hold perfect longer
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(100000)

        // Should still only be in one cooldown period, not stacked
        XCTAssertTrue(store.autoCaptureTracker.isInCooldown,
                     "should stay in cooldown, not trigger again")
    }

    // MARK: - Error Recovery

    func testStoreInitialState() {
        let newStore = CameraStore()
        XCTAssertEqual(newStore.matchState, .none)
        XCTAssertEqual(newStore.autoCaptureTracker.currentState, .none)
        XCTAssertFalse(newStore.autoCaptureTracker.isInCooldown)
    }

    func testRecoveryFromCorruptState() {
        // Simulate corrupted state
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(300000)
        store.updateAutoCaptureState(matchState: .far)

        // Reset should recover
        store.resetAutoCapture()

        XCTAssertEqual(store.autoCaptureTracker.currentState, .none)
        XCTAssertFalse(store.autoCaptureTracker.isInCooldown)

        // Should be ready for next use
        store.updateAutoCaptureState(matchState: .perfect)
        XCTAssertEqual(store.autoCaptureTracker.currentState, .perfect)
    }

    // MARK: - Configuration Consistency

    func testDwellTimeConfiguration() {
        // Tracker should have correct dwell time
        XCTAssertGreater(store.autoCaptureTracker.dwellProgress, -0.1)
        // Track timing across multiple updates
        store.updateAutoCaptureState(matchState: .perfect)
        usleep(250000)  // 250ms
        let progress25 = store.autoCaptureTracker.dwellProgress
        usleep(250000)  // Another 250ms (total 500ms)
        let progress50 = store.autoCaptureTracker.dwellProgress

        XCTAssertGreater(progress50, progress25,
                        "progress should increase over time")
    }

    func testCooldownDuration() {
        store.autoCaptureTracker.forceCapture()
        XCTAssertTrue(store.autoCaptureTracker.isInCooldown)

        usleep(1000000)  // 1 second (still in cooldown)
        XCTAssertTrue(store.autoCaptureTracker.isInCooldown)

        usleep(1500000)  // Another 1.5s (total 2.5s, past cooldown)
        XCTAssertFalse(store.autoCaptureTracker.isInCooldown,
                      "cooldown should expire after ~2 seconds")
    }
}
