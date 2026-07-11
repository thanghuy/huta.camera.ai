import Vision
import CoreVideo
import CoreGraphics

/// Vision glue: runs VNDetectHumanBodyPoseRequest on camera frames (throttled)
/// and converts the result into the pure PoseSnapshot the matcher consumes.
final class PoseDetector {
    /// Detection cadence — full frame rate is wasted on a UI that animates at 300ms.
    private let minInterval: TimeInterval = 0.12
    private var lastRun = Date.distantPast
    private let request = VNDetectHumanBodyPoseRequest()

    private static let jointMap: [VNHumanBodyPoseObservation.JointName: PoseJoint] = [
        .nose: .nose, .neck: .neck,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle,
    ]

    /// Returns nil when the frame is skipped by throttling; an empty snapshot
    /// means "ran but nobody detected".
    func detect(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> PoseSnapshot? {
        let now = Date()
        guard now.timeIntervalSince(lastRun) >= minInterval else { return nil }
        lastRun = now

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              let recognized = try? observation.recognizedPoints(.all) else {
            return PoseSnapshot()
        }

        var snapshot = PoseSnapshot()
        for (visionJoint, joint) in Self.jointMap {
            guard let point = recognized[visionJoint], point.confidence > 0 else { continue }
            // Vision is normalized with origin bottom-left; flip to top-left y-down.
            snapshot.points[joint] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            snapshot.confidences[joint] = Double(point.confidence)
        }
        return snapshot
    }
}
