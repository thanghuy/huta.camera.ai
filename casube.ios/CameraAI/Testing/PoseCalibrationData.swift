import Foundation
import CoreGraphics

/// Individual test result: one person's match against one reference pose
struct CalibrationSample {
    let personId: Int              // 1-10+ unique person identifier
    let coverage: Double           // Fraction of reference joints detected (0…1)
    let score: Double              // Pose similarity score (0…1)
    let sizeRatio: Double          // Live person height / reference height
    let state: String              // "perfect", "close", "far", "none"
    let distance: String           // "close", "medium", "far"
    let camera: String             // "front", "back"
    let mode: String               // "full-body", "close-up"
    let notes: String              // Optional: hand/posture notes, lighting, etc.
    let timestamp: Date
}

/// Collection of all samples for one pose
struct PoseCalibrationMatrix {
    let poseId: Int                // 1-6, corresponding to ReferencePose
    let poseName: String           // e.g. "Standing", "Hand on Chin"
    var samples: [CalibrationSample] = []
    
    /// Returns summary stats for a specific distance/camera/mode
    func summary(distance: String, camera: String, mode: String) -> CalibrationSummary {
        let filtered = samples.filter { $0.distance == distance && $0.camera == camera && $0.mode == mode }
        
        let scores = filtered.map { $0.score }
        let coverages = filtered.map { $0.coverage }
        let sizeRatios = filtered.map { $0.sizeRatio }
        
        return CalibrationSummary(
            sampleCount: filtered.count,
            avgScore: scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count),
            minScore: scores.min() ?? 0,
            maxScore: scores.max() ?? 0,
            avgCoverage: coverages.isEmpty ? 0 : coverages.reduce(0, +) / Double(coverages.count),
            avgSizeRatio: sizeRatios.isEmpty ? 0 : sizeRatios.reduce(0, +) / Double(sizeRatios.count),
            perfectCount: filtered.filter { $0.state == "perfect" }.count,
            closeCount: filtered.filter { $0.state == "close" }.count,
            farCount: filtered.filter { $0.state == "far" }.count,
            noneCount: filtered.filter { $0.state == "none" }.count
        )
    }
    
    mutating func addSample(_ sample: CalibrationSample) {
        samples.append(sample)
    }
}

struct CalibrationSummary {
    let sampleCount: Int
    let avgScore: Double
    let minScore: Double
    let maxScore: Double
    let avgCoverage: Double
    let avgSizeRatio: Double
    let perfectCount: Int
    let closeCount: Int
    let farCount: Int
    let noneCount: Int
    
    func report() -> String {
        """
        Samples: \(sampleCount)
        Score:   avg=\(String(format: "%.3f", avgScore)) min=\(String(format: "%.3f", minScore)) max=\(String(format: "%.3f", maxScore))
        Coverage: avg=\(String(format: "%.3f", avgCoverage))
        Size Ratio: avg=\(String(format: "%.3f", avgSizeRatio))
        States: perfect=\(perfectCount) close=\(closeCount) far=\(farCount) none=\(noneCount)
        """
    }
}

/// Master calibration dataset for all 6 poses
class CalibrationDataset {
    var matrices: [Int: PoseCalibrationMatrix] = [:]
    
    init() {
        // Initialize empty matrices for 6 poses
        for pose in ReferencePose.all {
            matrices[pose.id] = PoseCalibrationMatrix(poseId: pose.id, poseName: pose.name)
        }
    }
    
    /// Test matrix dimensions:
    /// 6 poses × 2 modes (full-body, close-up) × 3 distances (close, medium, far) × 2 cameras (front, back)
    /// = 72 test conditions minimum
    /// × 10+ people each = 720+ samples ideal
    static let testMatrixDimensions = """
    ╔════════════════════════════════════════════╗
    ║   TEST MATRIX: 6 Poses × Conditions       ║
    ╠════════════════════════════════════════════╣
    ║ Poses (6):                                 ║
    ║   1. Nghiêng nhẹ (Slight tilt)            ║
    ║   2. Tay chống cằm (Hand on chin)         ║
    ║   3. Bước đi (Walking)                    ║
    ║   4. Xoay người (Turned)                  ║
    ║   5. Tựa vai (Leaning)                    ║
    ║   6. Chiến binh II (Warrior II)           ║
    ║                                            ║
    ║ Modes (2):                                 ║
    ║   • Full-body (CHỤP TOÀN THÂN)            ║
    ║   • Close-up (CHỤP CẬN)                   ║
    ║                                            ║
    ║ Distances (3):                             ║
    ║   • Close (0.5–1m, sizeRatio ~0.8–1.0)   ║
    ║   • Medium (1–2m, sizeRatio ~0.6–0.8)    ║
    ║   • Far (2–4m, sizeRatio ~0.3–0.6)       ║
    ║                                            ║
    ║ Cameras (2):                               ║
    ║   • Front camera (selfie)                 ║
    ║   • Back camera (landscape)               ║
    ║                                            ║
    ║ People: 10+ unique persons (with consent) ║
    ║                                            ║
    ║ Total test runs: 6 × 2 × 3 × 2 = 72 ✕ 10+ = 720+
    ╚════════════════════════════════════════════╝
    """
    
    func addSample(_ sample: CalibrationSample, toPoseId poseId: Int) {
        if var matrix = matrices[poseId] {
            matrix.addSample(sample)
            matrices[poseId] = matrix
        }
    }
    
    func report(forPoseId poseId: Int) -> String? {
        guard let matrix = matrices[poseId] else { return nil }
        var report = "=== Pose: \(matrix.poseName) ===\n"
        
        for distance in ["close", "medium", "far"] {
            for camera in ["front", "back"] {
                for mode in ["full-body", "close-up"] {
                    let summary = matrix.summary(distance: distance, camera: camera, mode: mode)
                    if summary.sampleCount > 0 {
                        report += "\n[\(mode)] [\(camera)] [\(distance)]:\n"
                        report += summary.report()
                    }
                }
            }
        }
        return report
    }
    
    /// Export as JSON for external analysis (spreadsheet, Python, etc.)
    func exportJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        var allSamples: [[String: Any]] = []
        for matrix in matrices.values {
            for sample in matrix.samples {
                allSamples.append([
                    "poseId": matrix.poseId,
                    "poseName": matrix.poseName,
                    "personId": sample.personId,
                    "coverage": sample.coverage,
                    "score": sample.score,
                    "sizeRatio": sample.sizeRatio,
                    "state": sample.state,
                    "distance": sample.distance,
                    "camera": sample.camera,
                    "mode": sample.mode,
                    "notes": sample.notes,
                    "timestamp": ISO8601DateFormatter().string(from: sample.timestamp)
                ])
            }
        }
        
        if let jsonData = try? JSONSerialization.data(
            withJSONObject: allSamples,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
}
