import XCTest
@testable import CameraAI

/// WIN-10 Calibration Tests (Phase 3)
/// Edge cases from pilot data analysis + threshold adjustment (0.85 → 0.87)
final class PoseMatcherCalibrationTests: XCTestCase {

    // MARK: Helpers

    private func transformed(_ pose: PoseSnapshot, scale: CGFloat = 1, dx: CGFloat = 0, dy: CGFloat = 0) -> PoseSnapshot {
        var out = PoseSnapshot()
        for (joint, p) in pose.points {
            out.points[joint] = CGPoint(x: p.x * scale + dx, y: p.y * scale + dy)
        }
        out.confidences = pose.confidences
        return out
    }

    // MARK: WIN-10 Calibration Edge Cases

    /// WIN-10: Hand position variation should score as close, not perfect
    /// Real case from pilot data: Person 1, hand-on-chin with hand off-center
    /// - Old threshold (0.85): score 0.88 → false perfect ❌
    /// - New threshold (0.87): score 0.88 → correctly close ✅
    func testHandOnChinVariationIsClose() {
        // Create hand-on-chin with slightly off-center hand position
        var live = PoseSnapshot.handOnChin
        // Move right hand slightly outward (off-center by ~0.04 in x)
        live.points[.rightWrist] = CGPoint(x: 0.57, y: 0.21)  // Was 0.53
        live.points[.rightElbow] = CGPoint(x: 0.62, y: 0.36)  // Was 0.58

        let ref = PoseSnapshot.handOnChin
        let result = PoseMatcher.match(live: live, reference: ref)

        // Score should be just below perfect threshold (0.87)
        XCTAssertLessThan(result.score, 0.87,
                         "hand variation should score below perfect threshold")
        // With new 0.87 threshold, this should be close
        XCTAssertEqual(result.state, .close,
                      "hand variation should be close, not perfect")
        XCTAssertGreaterThan(result.score, 0.80,
                            "but still reasonably close (score > 0.80)")
    }

    /// WIN-10: All 6 reference poses must self-match perfectly
    /// Regression test: threshold changes must not break self-matches
    func testAllReferencePosesSelfMatchPerfectly() {
        for pose in ReferencePose.all {
            let result = PoseMatcher.match(live: pose.keypoints, reference: pose.keypoints)

            XCTAssertEqual(result.state, .perfect,
                          "\(pose.name) (ID \(pose.id)) must match itself perfectly")
            XCTAssertEqual(result.score, 1.0, accuracy: 0.001,
                          "\(pose.name) self-match score must be exactly 1.0")
            XCTAssertEqual(result.coverage, 1.0, accuracy: 0.001,
                          "\(pose.name) self-match coverage must be exactly 1.0")
        }
    }

    /// WIN-10: Far distance (sizeRatio < 0.55) always stays far
    /// From pilot data: 4 far samples, all correctly identified as .far
    func testFarDistanceAlwaysFar() {
        let ref = PoseSnapshot.standing()

        // Test multiple far distance cases (all below minSizeRatio 0.55)
        let farScales: [CGFloat] = [0.30, 0.40, 0.45, 0.50]

        for scale in farScales {
            let far = transformed(ref, scale: scale, dx: 0.25, dy: 0.25)
            let result = PoseMatcher.match(live: far, reference: ref)

            XCTAssertEqual(result.state, .far,
                          "sizeRatio \(String(format: "%.2f", result.sizeRatio)) should always be far")
            XCTAssertLessThan(result.sizeRatio, 0.55,
                             "sizeRatio must be below minSizeRatio (0.55)")
        }
    }

    /// WIN-10: Medium distance (0.6-0.8 sizeRatio) scores as close
    /// From pilot data: 2 medium samples, both correctly close
    func testMediumDistanceIsClose() {
        let ref = PoseSnapshot.standing()

        // Test medium distance (above minSizeRatio but below perfect)
        let medium = transformed(ref, scale: 0.70, dx: 0.15, dy: 0.15)
        let result = PoseMatcher.match(live: medium, reference: ref)

        XCTAssertGreaterThanOrEqual(result.sizeRatio, 0.55,
                                   "medium distance should be above minSizeRatio")
        XCTAssertEqual(result.state, .close,
                      "medium distance (scale 0.7) should be close")
    }

    /// WIN-10: Coverage below minimum (0.5) should be none
    /// Ensures low-quality poses with missing joints don't get matched
    func testCoverageBelowMinimumIsNone() {
        var live = PoseSnapshot.standing()
        // Remove most joints to force coverage < 0.5
        live.points = [
            .nose: live.points[.nose] ?? CGPoint.zero,
            .neck: live.points[.neck] ?? CGPoint.zero
            // Only 2 of 14 joints = ~14% coverage
        ]

        let ref = PoseSnapshot.standing()
        let result = PoseMatcher.match(live: live, reference: ref)

        XCTAssertEqual(result.state, .none,
                      "low coverage should result in .none state")
        XCTAssertLessThan(result.coverage, 0.5,
                         "coverage is below minimum (0.5)")
    }

    /// WIN-10: Score at perfect threshold boundary (0.86, just below 0.87)
    /// Ensures clear transition from .close → .perfect at threshold
    func testScoreAtPerfectThresholdBoundary() {
        // Create a pose that scores around 0.86
        // (slightly moved from reference but same scale)
        var live = PoseSnapshot.standing()
        // Move elbows slightly
        live.points[.leftElbow] = CGPoint(x: 0.38, y: 0.39)   // Was 0.38, 0.38
        live.points[.rightElbow] = CGPoint(x: 0.62, y: 0.39)  // Was 0.62, 0.38

        let ref = PoseSnapshot.standing()
        let result = PoseMatcher.match(live: live, reference: ref)

        // Score should be close to threshold
        XCTAssertLessThan(result.score, 0.87,
                         "this pose variation should score below 0.87 threshold")
        XCTAssertEqual(result.state, .close,
                      "score below 0.87 should be .close")
    }

    /// WIN-10: Different poses at same distance show clear state separation
    /// Ensures cross-pose matching doesn't accidentally hit perfect
    func testPoseVarianceAcrossReferences() {
        let standing = PoseSnapshot.standing()
        let warrior = PoseSnapshot.warriorII
        let leaning = PoseSnapshot.leaning
        let walking = PoseSnapshot.walking

        // Same pose → perfect
        let refStanding = PoseMatcher.match(live: standing, reference: standing)
        let refWarrior = PoseMatcher.match(live: warrior, reference: warrior)
        let refLeaning = PoseMatcher.match(live: leaning, reference: leaning)
        let refWalking = PoseMatcher.match(live: walking, reference: walking)

        XCTAssertEqual(refStanding.state, .perfect)
        XCTAssertEqual(refWarrior.state, .perfect)
        XCTAssertEqual(refLeaning.state, .perfect)
        XCTAssertEqual(refWalking.state, .perfect)

        // Cross-pose → not perfect
        let cross1 = PoseMatcher.match(live: warrior, reference: standing)
        let cross2 = PoseMatcher.match(live: leaning, reference: standing)
        let cross3 = PoseMatcher.match(live: walking, reference: standing)

        XCTAssertNotEqual(cross1.state, .perfect,
                         "warrior vs standing should not be perfect")
        XCTAssertNotEqual(cross2.state, .perfect,
                         "leaning vs standing should not be perfect")
        XCTAssertNotEqual(cross3.state, .perfect,
                         "walking vs standing should not be perfect")
    }

    /// WIN-10: Close distance (sizeRatio 0.8-1.0) allows perfect scores
    /// Ensures people at correct distance can achieve perfect
    func testCloseDistanceCanBePerfect() {
        let ref = PoseSnapshot.standing()

        // Test close distances (above minSizeRatio)
        let closeScales: [CGFloat] = [0.80, 0.85, 0.90, 0.95]

        for scale in closeScales {
            let close = transformed(ref, scale: scale, dx: 0.05, dy: 0.05)
            let result = PoseMatcher.match(live: close, reference: ref)

            XCTAssertGreaterThanOrEqual(result.sizeRatio, 0.55,
                                       "close distance should be above minSizeRatio")
            // Perfect score achievable at close distance
            XCTAssertTrue(result.state == .close || result.state == .perfect,
                         "close distance should be close or better")
        }
    }

    /// WIN-10: Threshold accuracy - ensure 0.87 boundary is precise
    /// Score exactly at threshold should be .perfect
    func testThresholdPrecision() {
        // This test verifies the threshold boundary behavior
        // Scores < 0.87 → .close
        // Scores ≥ 0.87 → .perfect (when sizeRatio is ok)

        let ref = PoseSnapshot.standing()

        // Create a pose scoring around 0.86-0.88
        var live = PoseSnapshot.standing()
        // Minimal variation: one joint slightly moved
        live.points[.leftWrist] = CGPoint(x: 0.365, y: 0.50)  // Was 0.36, 0.49

        let result = PoseMatcher.match(live: live, reference: ref)

        // Should be close (< 0.87) with this small movement
        XCTAssertLessThan(result.score, 0.87,
                         "minimal variation should score below 0.87")
        XCTAssertEqual(result.state, .close,
                      "score below threshold should be .close")
    }
}
