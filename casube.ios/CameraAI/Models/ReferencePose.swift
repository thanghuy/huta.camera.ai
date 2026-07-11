import CoreGraphics

enum PoseCategory: String, CaseIterable, Identifiable {
    case chanDung = "Chân dung"
    case toanThan = "Toàn thân"
    case doi = "Đôi"
    case yoga = "Yoga"

    var id: String { rawValue }
}

struct ReferencePose: Identifiable {
    let id: Int
    let name: String
    let category: PoseCategory
    let difficulty: String
    /// Normalized reference keypoints for the matcher (seed values, refined over time).
    let keypoints: PoseSnapshot
}

extension ReferencePose {
    /// The 6 seed poses from the design. Keypoints are hand-authored plausible
    /// skeletons in normalized frame coordinates (0…1, y down).
    static let all: [ReferencePose] = [
        ReferencePose(id: 1, name: "Nghiêng nhẹ", category: .chanDung, difficulty: "Dễ",
                      keypoints: .standing(headOffset: CGPoint(x: 0.03, y: 0.005))),
        ReferencePose(id: 2, name: "Tay chống cằm", category: .chanDung, difficulty: "Dễ",
                      keypoints: .handOnChin),
        ReferencePose(id: 3, name: "Bước đi", category: .toanThan, difficulty: "Vừa",
                      keypoints: .walking),
        ReferencePose(id: 4, name: "Xoay người", category: .toanThan, difficulty: "Vừa",
                      keypoints: .turned),
        ReferencePose(id: 5, name: "Tựa vai", category: .doi, difficulty: "Dễ",
                      keypoints: .leaning),
        ReferencePose(id: 6, name: "Chiến binh II", category: .yoga, difficulty: "Khó",
                      keypoints: .warriorII),
    ]

    static func pose(withID id: Int?) -> ReferencePose? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

extension PoseSnapshot {
    /// Upper-body subset used in CHỤP CẬN (close-up) mode.
    var upperBody: PoseSnapshot {
        let upper: Set<PoseJoint> = [.nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow]
        var s = PoseSnapshot()
        s.points = points.filter { upper.contains($0.key) }
        s.confidences = confidences.filter { upper.contains($0.key) }
        return s
    }

    /// Neutral standing skeleton (person centered, ~66% of frame height).
    static func standing(headOffset: CGPoint = .zero) -> PoseSnapshot {
        var s = PoseSnapshot()
        s.points = [
            .nose: CGPoint(x: 0.5 + headOffset.x, y: 0.18 + headOffset.y),
            .neck: CGPoint(x: 0.5, y: 0.26),
            .leftShoulder: CGPoint(x: 0.42, y: 0.27),
            .rightShoulder: CGPoint(x: 0.58, y: 0.27),
            .leftElbow: CGPoint(x: 0.38, y: 0.38),
            .rightElbow: CGPoint(x: 0.62, y: 0.38),
            .leftWrist: CGPoint(x: 0.36, y: 0.49),
            .rightWrist: CGPoint(x: 0.64, y: 0.49),
            .leftHip: CGPoint(x: 0.45, y: 0.52),
            .rightHip: CGPoint(x: 0.55, y: 0.52),
            .leftKnee: CGPoint(x: 0.44, y: 0.68),
            .rightKnee: CGPoint(x: 0.56, y: 0.68),
            .leftAnkle: CGPoint(x: 0.44, y: 0.84),
            .rightAnkle: CGPoint(x: 0.56, y: 0.84),
        ]
        return s
    }

    static var handOnChin: PoseSnapshot {
        var s = standing()
        s.points[.rightElbow] = CGPoint(x: 0.58, y: 0.36)
        s.points[.rightWrist] = CGPoint(x: 0.53, y: 0.21)
        return s
    }

    static var walking: PoseSnapshot {
        var s = standing()
        s.points[.leftKnee] = CGPoint(x: 0.40, y: 0.66)
        s.points[.leftAnkle] = CGPoint(x: 0.36, y: 0.82)
        s.points[.rightKnee] = CGPoint(x: 0.58, y: 0.69)
        s.points[.rightAnkle] = CGPoint(x: 0.62, y: 0.83)
        s.points[.leftWrist] = CGPoint(x: 0.42, y: 0.44)
        s.points[.rightWrist] = CGPoint(x: 0.60, y: 0.53)
        return s
    }

    static var turned: PoseSnapshot {
        var s = standing()
        s.points[.leftShoulder] = CGPoint(x: 0.46, y: 0.27)
        s.points[.rightShoulder] = CGPoint(x: 0.54, y: 0.27)
        s.points[.leftHip] = CGPoint(x: 0.47, y: 0.52)
        s.points[.rightHip] = CGPoint(x: 0.53, y: 0.52)
        s.points[.nose] = CGPoint(x: 0.47, y: 0.18)
        return s
    }

    static var leaning: PoseSnapshot {
        var s = standing()
        s.points[.nose] = CGPoint(x: 0.44, y: 0.19)
        s.points[.neck] = CGPoint(x: 0.47, y: 0.27)
        s.points[.leftShoulder] = CGPoint(x: 0.39, y: 0.28)
        s.points[.rightShoulder] = CGPoint(x: 0.55, y: 0.27)
        return s
    }

    static var warriorII: PoseSnapshot {
        var s = standing()
        s.points[.leftElbow] = CGPoint(x: 0.30, y: 0.29)
        s.points[.rightElbow] = CGPoint(x: 0.70, y: 0.29)
        s.points[.leftWrist] = CGPoint(x: 0.18, y: 0.30)
        s.points[.rightWrist] = CGPoint(x: 0.82, y: 0.30)
        s.points[.leftKnee] = CGPoint(x: 0.34, y: 0.70)
        s.points[.leftAnkle] = CGPoint(x: 0.30, y: 0.85)
        s.points[.rightKnee] = CGPoint(x: 0.64, y: 0.70)
        s.points[.rightAnkle] = CGPoint(x: 0.72, y: 0.85)
        return s
    }
}
