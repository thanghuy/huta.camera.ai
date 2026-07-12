# Pose Matcher Calibration Guide (WIN-10)

## 📋 Overview

This guide walks through collecting real-world data to calibrate pose-matching thresholds and reference keypoints.

**Goal:** Reduce false positives (false perfect) and false negatives (false far) before release.

---

## 🎯 Test Matrix

### Dimensions

```
6 Poses × 2 Modes × 3 Distances × 2 Cameras × 10+ People = 720+ samples
```

### Poses (ID 1–6)

| ID | Name | Category | Difficulty |
|----|------|----------|------------|
| 1 | Nghiêng nhẹ (Slight Tilt) | Portrait | Easy |
| 2 | Tay chống cằm (Hand on Chin) | Portrait | Easy |
| 3 | Bước đi (Walking) | Full-body | Medium |
| 4 | Xoay người (Turned) | Full-body | Medium |
| 5 | Tựa vai (Leaning) | Pair | Easy |
| 6 | Chiến binh II (Warrior II) | Yoga | Hard |

### Modes

- **Full-body (CHỤP TOÀN THÂN):** Show person head-to-toe in frame
- **Close-up (CHỤP CẬN):** Show face + upper body only

### Distances

| Distance | Approx. Range | Expected sizeRatio |
|----------|---------------|-------------------|
| Close | 0.5–1.0m | 0.8–1.0 |
| Medium | 1.0–2.0m | 0.6–0.8 |
| Far | 2.0–4.0m | 0.3–0.6 |

### Cameras

- **Front:** Selfie mode (front-facing camera)
- **Back:** Landscape (rear camera)

---

## 📱 Using the Calibration Logger

### Enable Dev Panel

1. **In code:** Integrate `CalibrationControlPanel()` into the app's dev menu (or behind a debug flag)
2. **On device:** Launch the app, navigate to **Settings → Dev → Calibration**

### Workflow Per Test

1. **Configure test parameters:**
   - Select **Pose** (1–6)
   - Select **Distance** (close/medium/far)
   - Select **Camera** (front/back)
   - Select **Mode** (full-body/close-up)
   - Enter **Person ID** (1–10+)

2. **Enable logging:** Toggle "Logging Enabled" ON

3. **Capture pose:**
   - Position person according to mode (full-body or close-up)
   - Stand at target distance
   - Use selected camera
   - Capture frame

4. **Logger auto-records:**
   - Coverage, score, sizeRatio, state
   - All parameters, timestamp, notes
   - Data saved to `Documents/calibration_log.jsonl`

5. **Repeat** for all combinations

---

## 📊 Data Collection Checklist

- [ ] **10+ unique people** (with consent; document consent for privacy compliance)
- [ ] **Each pose:** 2 (mode) × 3 (distance) × 2 (camera) = 6 captures per person per pose
- [ ] **Total per person:** 6 poses × 6 = 36 captures
- [ ] **Total dataset:** 10 people × 36 = 360+ samples (more is better)
- [ ] **Lighting:** Vary natural & indoor; note in optional "notes" field
- [ ] **Device:** Consistent iPhone model (or test multiple)
- [ ] **Consent:** Written OK from all participants; store separately (privacy)

---

## 📈 Analysis (Phase 2)

### Export Data

1. Open **Calibration Control Panel**
2. Tap **📤 Export**
3. Save JSON file with timestamp

### Load into Python/Excel

```python
import json
import pandas as pd

with open("calibration_2026-07-12T21:45:00Z.json") as f:
    data = json.load(f)

df = pd.DataFrame(data)

# Group by (pose, distance, camera, mode) and compute stats
stats = df.groupby(['poseId', 'distance', 'camera', 'mode']).agg({
    'score': ['mean', 'std', 'min', 'max'],
    'coverage': 'mean',
    'sizeRatio': 'mean',
    'state': lambda x: (x == 'perfect').sum()
})

print(stats)
```

### Key Metrics to Analyze

**For each (pose, distance, camera, mode) combination:**

1. **Score distribution:**
   - Avg, min, max, std dev
   - Are "perfect" and "close" states well-separated?

2. **False positives (false perfect):**
   - How many non-perfect poses score ≥ 0.85?
   - Should threshold be higher?

3. **False negatives (false far):**
   - How many perfect poses score < 0.85?
   - Adjust threshold down?

4. **Coverage:**
   - Is `minCoverage = 0.5` reasonable?
   - Any poses with < 50% coverage?

5. **Size ratio:**
   - Are "far" captures all < 0.55?
   - Is `minSizeRatio = 0.55` right?

---

## 🔧 Threshold Adjustment (Phase 2)

After analysis, update constants in `PoseMatcher.swift`:

```swift
static let minCoverage = 0.5       // ← Adjust if coverage is consistently high/low
static let minSizeRatio = 0.55     // ← Adjust if far/medium boundary is off
static let closeThreshold = 0.60   // ← Adjust if perfect/close boundary is wrong
static let perfectThreshold = 0.85 // ← Adjust if false perfect/negative is high
```

**Decision log:**

| Current Value | Analysis Finding | New Value | Reason |
|---------------|------------------|-----------|--------|
| 0.85 | X% false perfect at this threshold | 0.87 | Raise to reduce false perfect |
| 0.60 | Y% false far at this threshold | 0.58 | Lower to capture more valid states |

---

## ✅ Reference Keypoints Refinement (Phase 2)

If analysis shows consistent bias:

1. **Plot keypoints** from high-scoring live poses
2. **Identify drift:** Are shoulders always slightly off? Wrists too high?
3. **Update `ReferencePose.swift`:**
   ```swift
   static var standing(headOffset: CGPoint = .zero) -> PoseSnapshot {
       // Adjust point positions based on real-world data
       s.points[.rightShoulder] = CGPoint(x: 0.58, y: 0.27) // Was 0.27, now 0.26
   }
   ```

---

## 🧪 XCTest Coverage (Phase 3)

Add regression tests for discovered edge cases:

```swift
// casube.ios/CameraAITests/PoseMatcherTests.swift

func testFarDistanceDataWith10People() {
    // Load real calibration data: 10 people × far distance
    // Assert all sizeRatio < 0.55
    // Assert state == .far
}

func testPerfectPoseNearThresholdBoundary() {
    // Create pose with score just below perfectThreshold
    // Verify it scores as .close, not .perfect
}
```

---

## 📋 Acceptance Criteria (WIN-10)

- [x] Test matrix structure defined (`CalibrationSample`, `PoseCalibrationMatrix`)
- [x] Logger UI for on-device data collection
- [ ] Collect 360+ samples from 10+ people
- [ ] Analyze data → generate stats report
- [ ] Document threshold decisions → why changed?
- [ ] Update `PoseMatcher.swift` with new thresholds
- [ ] Update `ReferencePose.swift` with refined keypoints
- [ ] 6 reference poses self-match perfectly (regression test)
- [ ] XCTests for edge cases + real data scenarios
- [ ] Run UAT on iPhone (front/back camera)

---

## 📁 Artifacts

| File | Purpose |
|------|---------|
| `CameraAI/Testing/PoseCalibrationData.swift` | Data structures |
| `CameraAI/Testing/CalibrationLogger.swift` | Logger + UI |
| `calibration_log.jsonl` | Device storage (exported on app) |
| `calibration_YYYY-MM-DD_HH-MM-SS.json` | Exported dataset |
| `CALIBRATION_ANALYSIS.md` | Phase 2 analysis report (TBD) |
| `CameraAITests/PoseMatcherTests.swift` | Phase 3 regression tests |

---

## 🎬 Next Steps

1. **Phase 1 ✅** Build structures + logger UI
2. **Phase 2 📊** Collect data + analyze + adjust thresholds
3. **Phase 3 🧪** Write XCTests + commit threshold changes
4. **Phase 4 ✔️** UAT on real iPhone

---

**Issues / Questions?** Link to WIN-10 comment thread.
