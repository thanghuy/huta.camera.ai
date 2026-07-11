import XCTest
@testable import CameraAI

/// Tests for the pure pose-matching core — the main automated-test surface.
/// No camera/device needed.
final class PoseMatcherTests: XCTestCase {

    // MARK: Helpers

    private func transformed(_ pose: PoseSnapshot, scale: CGFloat = 1, dx: CGFloat = 0, dy: CGFloat = 0) -> PoseSnapshot {
        var out = PoseSnapshot()
        for (joint, p) in pose.points {
            out.points[joint] = CGPoint(x: p.x * scale + dx, y: p.y * scale + dy)
        }
        out.confidences = pose.confidences
        return out
    }

    // MARK: Basic states

    func testIdenticalPoseIsPerfect() {
        let ref = PoseSnapshot.standing()
        let result = PoseMatcher.match(live: ref, reference: ref)
        XCTAssertEqual(result.state, .perfect)
        XCTAssertEqual(result.score, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.coverage, 1.0, accuracy: 0.001)
    }

    func testEmptyLivePoseIsNone() {
        let result = PoseMatcher.match(live: PoseSnapshot(), reference: .standing())
        XCTAssertEqual(result.state, .none)
        XCTAssertEqual(result.coverage, 0)
    }

    func testEmptyReferenceIsNone() {
        let result = PoseMatcher.match(live: .standing(), reference: PoseSnapshot())
        XCTAssertEqual(result.state, .none)
    }

    func testLowConfidenceJointsAreIgnored() {
        var live = PoseSnapshot.standing()
        for joint in live.points.keys {
            live.confidences[joint] = 0.1 // all below minJointConfidence
        }
        let result = PoseMatcher.match(live: live, reference: .standing())
        XCTAssertEqual(result.state, .none)
    }

    // MARK: Invariance

    func testTranslationInvariance() {
        let ref = PoseSnapshot.standing()
        let moved = transformed(ref, dx: 0.15, dy: -0.08)
        let result = PoseMatcher.match(live: moved, reference: ref)
        XCTAssertEqual(result.state, .perfect)
        XCTAssertEqual(result.score, 1.0, accuracy: 0.001)
    }

    func testUniformScaleGivesSameShapeScore() {
        // Same pose 80% of reference size: shape score stays perfect,
        // sizeRatio reflects the shrink.
        let ref = PoseSnapshot.standing()
        let smaller = transformed(ref, scale: 0.8, dx: 0.1, dy: 0.1)
        let result = PoseMatcher.match(live: smaller, reference: ref)
        XCTAssertEqual(result.score, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.sizeRatio, 0.8, accuracy: 0.01)
        XCTAssertEqual(result.state, .perfect)
    }

    // MARK: Distance → far

    func testTinyPersonInFrameIsFar() {
        // Perfect shape but only 30% of the reference size → too far away.
        let ref = PoseSnapshot.standing()
        let tiny = transformed(ref, scale: 0.3, dx: 0.35, dy: 0.35)
        let result = PoseMatcher.match(live: tiny, reference: ref)
        XCTAssertEqual(result.state, .far)
        XCTAssertLessThan(result.sizeRatio, PoseMatcher.minSizeRatio)
    }

    // MARK: Pose differences

    func testDifferentPoseScoresLowerThanSamePose() {
        let standing = PoseSnapshot.standing()
        let warrior = PoseSnapshot.warriorII
        let same = PoseMatcher.match(live: standing, reference: standing)
        let different = PoseMatcher.match(live: warrior, reference: standing)
        XCTAssertGreaterThan(same.score, different.score)
        XCTAssertNotEqual(different.state, .perfect)
    }

    func testSlightVariationIsCloseOrBetter() {
        // Hand-on-chin only moves one arm off the standing base.
        let result = PoseMatcher.match(live: .handOnChin, reference: .standing())
        XCTAssertTrue(result.state == .close || result.state == .perfect,
                      "one-arm variation should stay close, got \(result.state)")
    }

    // MARK: Reference data sanity

    func testAllSeedPosesSelfMatchPerfectly() {
        for pose in ReferencePose.all {
            let result = PoseMatcher.match(live: pose.keypoints, reference: pose.keypoints)
            XCTAssertEqual(result.state, .perfect, "\(pose.name) should match itself")
        }
    }

    func testUpperBodySubsetMatchesInCloseUpMode() {
        let ref = PoseSnapshot.standing().upperBody
        // Live sees the full body; matcher only compares reference joints.
        let result = PoseMatcher.match(live: .standing(), reference: ref)
        XCTAssertEqual(result.state, .perfect)
    }

    // MARK: Crop math (aspect ratio drives capture crop)

    func testCropRectForPortraitPhoto() {
        let size = CGSize(width: 3024, height: 4032) // 3:4 sensor
        let rect43 = AspectRatio.r4_3.cropRect(for: size)
        XCTAssertEqual(rect43, CGRect(origin: .zero, size: size)) // already 3:4

        let rect11 = AspectRatio.r1_1.cropRect(for: size)
        XCTAssertEqual(rect11.width, 3024, accuracy: 0.5)
        XCTAssertEqual(rect11.height, 3024, accuracy: 0.5)
        XCTAssertEqual(rect11.midY, size.height / 2, accuracy: 0.5)

        let rect169 = AspectRatio.r16_9.cropRect(for: size)
        XCTAssertEqual(rect169.height / rect169.width, 16.0 / 9.0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(rect169.width, size.width)
    }

    func testCropRectForLandscapePhoto() {
        let size = CGSize(width: 4032, height: 3024)
        let rect169 = AspectRatio.r16_9.cropRect(for: size)
        XCTAssertEqual(rect169.width / rect169.height, 16.0 / 9.0, accuracy: 0.001)
        XCTAssertEqual(rect169.midX, size.width / 2, accuracy: 0.5)
    }
}
