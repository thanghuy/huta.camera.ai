import CoreGraphics

// PURE pose-matching logic. No UIKit / AVFoundation / Vision imports — this file
// is the main automated-test surface (see CameraAITests/PoseMatcherTests.swift).
// PoseDetector converts Vision output into these types before calling in.

/// Body joints tracked by the matcher (subset shared by Vision's body-pose request).
enum PoseJoint: String, CaseIterable {
    case nose, neck
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

/// A detected or reference pose in normalized frame coordinates
/// (x, y in 0…1, origin top-left, y pointing down).
struct PoseSnapshot: Equatable {
    var points: [PoseJoint: CGPoint] = [:]
    var confidences: [PoseJoint: Double] = [:]

    func confidence(of joint: PoseJoint) -> Double {
        confidences[joint] ?? (points[joint] != nil ? 1 : 0)
    }
}

struct PoseMatchResult: Equatable {
    /// 0…1 similarity after normalization.
    let score: Double
    /// Fraction of reference joints confidently detected live.
    let coverage: Double
    /// Live-person height relative to the reference (1 = fills frame like reference).
    let sizeRatio: Double
    let state: MatchState
}

/// Translation- and scale-invariant pose similarity.
enum PoseMatcher {
    static let minJointConfidence = 0.3
    static let minCoverage = 0.5
    /// Live person must be at least this fraction of the reference size,
    /// otherwise the state is capped at `.far` ("Tiến gần hơn để lấp đầy khung").
    static let minSizeRatio = 0.55
    static let closeThreshold = 0.60
    static let perfectThreshold = 0.85

    static func match(live: PoseSnapshot, reference: PoseSnapshot) -> PoseMatchResult {
        let refJoints = reference.points.keys
        guard !refJoints.isEmpty else {
            return PoseMatchResult(score: 0, coverage: 0, sizeRatio: 0, state: .none)
        }

        let visible = refJoints.filter { joint in
            live.points[joint] != nil && live.confidence(of: joint) >= minJointConfidence
        }
        let coverage = Double(visible.count) / Double(refJoints.count)
        guard coverage >= minCoverage,
              let liveNorm = normalize(live, joints: Set(visible)),
              let refNorm = normalize(reference, joints: Set(visible)) else {
            return PoseMatchResult(score: 0, coverage: coverage, sizeRatio: 0, state: .none)
        }

        // Mean per-joint similarity in torso-length units.
        var total = 0.0
        for joint in visible {
            guard let a = liveNorm.points[joint], let b = refNorm.points[joint] else { continue }
            let d = hypot(a.x - b.x, a.y - b.y)
            total += max(0, 1 - Double(d) / 1.5)
        }
        let score = total / Double(visible.count)

        let sizeRatio = extent(of: live, joints: Set(visible)) / max(extent(of: reference, joints: Set(visible)), 0.0001)

        let state: MatchState
        if sizeRatio < minSizeRatio {
            state = .far
        } else if score >= perfectThreshold {
            state = .perfect
        } else if score >= closeThreshold {
            state = .close
        } else {
            state = .far
        }
        return PoseMatchResult(score: score, coverage: coverage, sizeRatio: sizeRatio, state: state)
    }

    // MARK: - Normalization

    /// Translates the pose so its anchor (hip center, else centroid) is at the
    /// origin and scales by torso length (neck→hip center, else bbox diagonal).
    private static func normalize(_ pose: PoseSnapshot, joints: Set<PoseJoint>) -> PoseSnapshot? {
        let pts = pose.points.filter { joints.contains($0.key) }
        guard pts.count >= 2 else { return nil }

        let anchor: CGPoint
        if let lh = pts[.leftHip], let rh = pts[.rightHip] {
            anchor = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
        } else {
            let sum = pts.values.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            anchor = CGPoint(x: sum.x / CGFloat(pts.count), y: sum.y / CGFloat(pts.count))
        }

        var scale: CGFloat = 0
        if let neck = pts[.neck], let lh = pts[.leftHip], let rh = pts[.rightHip] {
            let hipCenter = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            scale = hypot(neck.x - hipCenter.x, neck.y - hipCenter.y)
        }
        if scale < 0.0001 {
            let xs = pts.values.map(\.x), ys = pts.values.map(\.y)
            scale = hypot((xs.max()! - xs.min()!), (ys.max()! - ys.min()!)) / 2
        }
        guard scale > 0.0001 else { return nil }

        var result = PoseSnapshot()
        for (joint, p) in pts {
            result.points[joint] = CGPoint(x: (p.x - anchor.x) / scale, y: (p.y - anchor.y) / scale)
        }
        return result
    }

    /// Vertical extent (height) of the visible joints in frame coordinates.
    private static func extent(of pose: PoseSnapshot, joints: Set<PoseJoint>) -> Double {
        let ys = pose.points.filter { joints.contains($0.key) }.values.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return Double(maxY - minY)
    }
}
