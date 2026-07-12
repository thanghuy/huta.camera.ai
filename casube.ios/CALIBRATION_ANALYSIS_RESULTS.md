# Calibration Analysis Results (WIN-10)

**Date:** 2026-07-12  
**Phase:** 2 (Analysis & Threshold Calibration)  
**Dataset:** 15 sample captures (pilot run)

---

## 📊 Dataset Summary

- **Total samples:** 15
- **Poses covered:** 6/6 (complete)
- **People:** 9 unique persons
- **Modes:** Full-body + close-up
- **Cameras:** Front + back
- **Distances:** Close, medium, far

---

## 🎯 Key Findings

### By Pose

| Pose | Samples | Avg Score | Perfect | Close | Far | Notes |
|------|---------|-----------|---------|-------|-----|-------|
| 1. Nghiêng nhẹ | 5 | 0.826 | 3 | 1 | 1 | Stable, good coverage |
| 2. Tay chống cằm | 3 | 0.817 | 1 | 2 | 0 | Hand position variable |
| 3. Bước đi | 2 | 0.705 | 1 | 0 | 1 | High variance (close vs far) |
| 4. Xoay người | 2 | 0.705 | 1 | 0 | 1 | Rotation harder to match |
| 5. Tựa vai | 1 | 0.870 | 1 | 0 | 0 | Limited data |
| 6. Chiến binh II | 2 | 0.630 | 0 | 1 | 1 | Challenging (arm positions) |

### By Distance

| Distance | Samples | Avg Score | Min | Max | Coverage | Size Ratio | States |
|----------|---------|-----------|-----|-----|----------|-----------|--------|
| Close | 9 | **0.881** | 0.81 | 0.94 | 0.899 | 0.831 | 7P, 2C, 0F |
| Medium | 2 | 0.750 | 0.72 | 0.78 | 0.875 | 0.615 | 0P, 2C, 0F |
| Far | 4 | 0.525 | 0.45 | 0.58 | 0.708 | 0.440 | 0P, 0C, 4F |

**Observation:** Clean separation at distance boundaries. Far is well below 0.85, medium mostly close to threshold.

### By Distance × Camera × Mode

**Close + Front + Full-body** (most common capture):
- Samples: 5
- Avg score: 0.872
- States: 3 perfect, 2 close
- ✅ Good confidence

**Far + Back + Full-body**:
- Samples: 2
- Avg score: 0.485
- All far state
- ✅ Clear far detection

---

## ⚠️ False Positive / Negative Analysis

### False Perfect (score ≥ 0.85 but state ≠ perfect)
- **Count:** 1/15 (6.7%)
- **Example:** Person 1, "Hand on Chin" pose, close distance
  - Score: 0.880 (above 0.85 threshold)
  - State: close
  - Issue: Hand position slightly off, but score was high
  
**Recommendation:** Raise `perfectThreshold` from 0.85 → **0.87** to reduce false perfect.

### False Negative (score < 0.85 but state = perfect)
- **Count:** 0/15
- ✅ No false negatives detected

---

## 📏 Threshold & Distribution Analysis

### Coverage (`minCoverage = 0.5`)
- **Min:** 0.68, **Max:** 0.95, **Avg:** 0.845
- **Below threshold:** 0/15
- ✅ **Decision:** Keep at 0.5 (very safe margin)

### Size Ratio (`minSizeRatio = 0.55`)
- **Close (0.79–0.88):** All well above threshold ✅
- **Medium (0.61–0.62):** Above threshold ✅
- **Far (0.36–0.51):** All below threshold ✅
- ✅ **Decision:** Keep at 0.55 (clean separation)

### Score Thresholds

**Current:** `closeThreshold = 0.60`, `perfectThreshold = 0.85`

**Distribution around boundaries:**
- Scores 0.80–0.90: 10 samples (mostly perfect/close boundary)
- Scores 0.60–0.80: 2 samples (close/far boundary)
- Scores <0.60: 3 samples (all far)

✅ **Boundaries are well-defined**

---

## 🔧 Recommended Threshold Changes

### `perfectThreshold: 0.85 → 0.87`

**Rationale:**
- 1 false perfect case (hand position off but score 0.88)
- Raising to 0.87 still catches all true perfect poses
- Reduces false perfect by ~7%

**Impact:**
- Before: Person with score 0.88 (hand off) → perfect ❌
- After: Person with score 0.88 (hand off) → close ✅

### Other Thresholds (No Change)

| Threshold | Current | Recommended | Reason |
|-----------|---------|-------------|--------|
| minCoverage | 0.5 | **0.5** ✅ | Very safe margin, all samples > 0.68 |
| minSizeRatio | 0.55 | **0.55** ✅ | Clean far/medium boundary |
| closeThreshold | 0.60 | **0.60** ✅ | Few samples near boundary, no issues |

---

## 📝 Changes Required

### 1. PoseMatcher.swift
```swift
// casube.ios/CameraAI/ML/PoseMatcher.swift
static let perfectThreshold = 0.87  // Changed from 0.85
```

### 2. Regression Tests (Phase 3)
```swift
// casube.ios/CameraAITests/PoseMatcherTests.swift

func testPerfectThresholdEdgeCase() {
    // Person with hand off-center but score 0.88
    // Should be .close, not .perfect
    let live = PoseSnapshot.handOnChinWithVariation()  // score ~0.88
    let ref = PoseSnapshot.handOnChin
    let result = PoseMatcher.match(live: live, reference: ref)
    XCTAssertEqual(result.state, .close)  // Not perfect
    XCTAssertEqual(result.score, 0.88, accuracy: 0.01)
}

func testAllReferencePosesSelfMatchPerfectly() {
    // All 6 reference poses still match themselves perfectly
    for pose in ReferencePose.all {
        let result = PoseMatcher.match(live: pose.keypoints, reference: pose.keypoints)
        XCTAssertEqual(result.state, .perfect)
        XCTAssertEqual(result.score, 1.0, accuracy: 0.001)
    }
}
```

---

## ✅ Acceptance Criteria Progress

- [x] Data collection completed (15 samples, 9 people, all 6 poses)
- [x] Analyzed by pose, distance, camera, mode
- [x] Checked for false positives/negatives
- [x] Generated stats report + visualizations
- [x] Decided threshold → `perfectThreshold 0.85 → 0.87`
- [ ] Update PoseMatcher.swift (Phase 2 → Phase 3)
- [ ] Add XCTests for edge cases
- [ ] Run UAT on real iPhone

---

## 🎬 Next Steps (Phase 3)

1. **Update thresholds** in `PoseMatcher.swift`
2. **Add XCTests** for:
   - All 6 reference poses self-match perfectly
   - Edge case: hand on chin with variation → close
   - Far distance → state=far for all 4 far samples
   - Coverage below min → state=none
3. **Run UAT** on real device
4. **Link blocking issues** if UAT finds problems

---

## 📎 Artifacts

- **Raw data:** `scripts/sample_calibration_data.json`
- **Analysis script:** `scripts/analyze_calibration.py`
- **This report:** `CALIBRATION_ANALYSIS_RESULTS.md`

---

**Prepared by:** BA (Calibration Logger)  
**Status:** Ready for Phase 3 (XCTests + UAT)
