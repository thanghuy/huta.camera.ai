import SwiftUI
import CoreGraphics

/// Dev tool: Log live match results for calibration during capture
class CalibrationLogger: ObservableObject {
    static let shared = CalibrationLogger()
    
    @Published var dataset = CalibrationDataset()
    @Published var isLogging = false
    @Published var currentPoseId: Int = 1
    @Published var currentDistance: String = "medium"
    @Published var currentCamera: String = "front"
    @Published var currentMode: String = "full-body"
    @Published var currentPersonId: Int = 1
    @Published var notes: String = ""
    @Published var logEntries: [String] = []
    
    private let logFile = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first?.appendingPathComponent("calibration_log.jsonl")
    
    init() {
        loadExistingLog()
    }
    
    /// Call this after each pose match to record the result
    func logMatch(
        result: PoseMatchResult,
        poseId: Int,
        personId: Int,
        distance: String,
        camera: String,
        mode: String,
        notes: String = ""
    ) {
        guard isLogging else { return }
        
        let sample = CalibrationSample(
            personId: personId,
            coverage: result.coverage,
            score: result.score,
            sizeRatio: result.sizeRatio,
            state: result.state.rawValue,
            distance: distance,
            camera: camera,
            mode: mode,
            notes: notes,
            timestamp: Date()
        )
        
        dataset.addSample(sample, toPoseId: poseId)
        
        let entry = "[\(ISO8601DateFormatter().string(from: Date()))] " +
                    "Pose \(poseId) | Person \(personId) | " +
                    "\(distance) \(camera) \(mode) | " +
                    "Score: \(String(format: "%.3f", result.score)) | " +
                    "State: \(result.state.rawValue)"
        
        logEntries.append(entry)
        saveSample(sample, poseId: poseId)
        
        print(entry)
    }
    
    /// Save sample to JSONL file
    private func saveSample(_ sample: CalibrationSample, poseId: Int) {
        let data: [String: Any] = [
            "poseId": poseId,
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
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let logFile = logFile {
            
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = FileHandle(forWritingAtPath: logFile.path) {
                    fileHandle.seekToEndOfFile()
                    if let data = (jsonString + "\n").data(using: .utf8) {
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                }
            } else {
                try? (jsonString + "\n").write(toFile: logFile.path, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func loadExistingLog() {
        guard let logFile = logFile else { return }
        guard let contents = try? String(contentsOfFile: logFile.path, encoding: .utf8) else { return }
        
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            if let jsonData = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Reconstruct sample from JSON
                if let poseId = json["poseId"] as? Int,
                   let personId = json["personId"] as? Int,
                   let coverage = json["coverage"] as? Double,
                   let score = json["score"] as? Double,
                   let sizeRatio = json["sizeRatio"] as? Double,
                   let state = json["state"] as? String,
                   let distance = json["distance"] as? String,
                   let camera = json["camera"] as? String,
                   let mode = json["mode"] as? String,
                   let notes = json["notes"] as? String,
                   let timestamp = json["timestamp"] as? String {
                    
                    let dateFormatter = ISO8601DateFormatter()
                    let date = dateFormatter.date(from: timestamp) ?? Date()
                    
                    let sample = CalibrationSample(
                        personId: personId,
                        coverage: coverage,
                        score: score,
                        sizeRatio: sizeRatio,
                        state: state,
                        distance: distance,
                        camera: camera,
                        mode: mode,
                        notes: notes,
                        timestamp: date
                    )
                    
                    dataset.addSample(sample, toPoseId: poseId)
                }
            }
        }
    }
    
    /// Export all data as JSON for analysis
    func exportData() -> String? {
        return dataset.exportJSON()
    }
    
    /// Get summary for a specific pose
    func getSummary(poseId: Int) -> String? {
        return dataset.report(forPoseId: poseId)
    }
    
    /// Clear all logs
    func clearLogs() {
        dataset = CalibrationDataset()
        logEntries = []
        if let logFile = logFile {
            try? FileManager.default.removeItem(atPath: logFile.path)
        }
    }
}

/// SwiftUI view for calibration control panel (dev-only)
struct CalibrationControlPanel: View {
    @ObservedObject var logger = CalibrationLogger.shared
    @State private var showingSummary = false
    @State private var selectedPoseId = 1
    
    var body: some View {
        VStack(spacing: 12) {
            Text("📊 Calibration Logger")
                .font(.headline)
            
            // Toggle logging
            Toggle("Logging Enabled", isOn: $logger.isLogging)
                .tint(.blue)
            
            Divider()
            
            // Test parameters
            VStack(alignment: .leading, spacing: 8) {
                Text("Test Parameters").font(.subheadline).bold()
                
                HStack {
                    Text("Pose:").frame(width: 60)
                    Picker("", selection: $logger.currentPoseId) {
                        ForEach(1...6, id: \.self) { id in
                            Text("ID \(id)").tag(id)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Distance:").frame(width: 60)
                    Picker("", selection: $logger.currentDistance) {
                        Text("Close").tag("close")
                        Text("Medium").tag("medium")
                        Text("Far").tag("far")
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Camera:").frame(width: 60)
                    Picker("", selection: $logger.currentCamera) {
                        Text("Front").tag("front")
                        Text("Back").tag("back")
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Mode:").frame(width: 60)
                    Picker("", selection: $logger.currentMode) {
                        Text("Full").tag("full-body")
                        Text("Close").tag("close-up")
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack {
                    Text("Person:").frame(width: 60)
                    Stepper("\(logger.currentPersonId)", value: $logger.currentPersonId, in: 1...50)
                }
                
                TextField("Notes", text: $logger.notes)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            
            // Log count
            Text("Logged: \(logger.dataset.matrices.values.reduce(0) { $0 + $1.samples.count }) samples")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: { showingSummary.toggle() }) {
                    Text("📈 Summary")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: exportAndShare) {
                    Text("📤 Export")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { logger.clearLogs() }) {
                    Text("🗑️ Clear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .font(.caption2)
            
            if showingSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary - Pose \(selectedPoseId)")
                        .font(.caption).bold()
                    
                    if let summary = logger.getSummary(poseId: selectedPoseId) {
                        Text(summary)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(nil)
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func exportAndShare() {
        guard let json = logger.exportData() else { return }
        
        let fileName = "calibration_\(ISO8601DateFormatter().string(from: Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try? json.write(toFile: tempURL.path, atomically: true, encoding: .utf8)
        
        // Trigger share sheet or save to files
        print("📤 Exported to: \(tempURL.path)")
    }
}

#Preview {
    CalibrationControlPanel()
}
