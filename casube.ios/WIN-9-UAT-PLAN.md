# WIN-9 UAT Plan: Auto-Capture on Perfect Pose

**Feature:** Automatically capture photo when user's pose reaches & holds "perfect" state for 500ms

**Devices:** iPhone (real device, all iOS 15+)  
**Cameras:** Front (selfie) + Back (landscape)  
**Poses:** All 6 reference poses  
**Duration:** ~30-45 minutes

---

## 📋 UAT Checklist

### Phase 1: Basic Auto-Capture Flow

**Scenario 1.1: Perfect Pose → Auto-Capture**
- [ ] User strikes a perfect pose (e.g., standing upright)
- [ ] Wait for match state to reach "perfect"
- [ ] **Expected:** Shutter animates + photo saves automatically after ~0.5s
- [ ] **Verify:** Photo appears in device library
- [ ] **Haptic:** Heavy vibration (different from manual shutter)
- [ ] **Toast:** "Đã lưu" appears once, not repeated

**Scenario 1.2: Copy is Accurate**
- [ ] When perfect: hint text reads "Đã khớp! Sắp chụp..."
- [ ] **Verify:** No false promise like "tự động chụp..." when feature not active
- [ ] Text appears in yellow/accent color

**Scenario 1.3: Dwell Time Works**
- [ ] Strike perfect pose
- [ ] **Count seconds:** Auto-capture should happen ~0.5s after perfect reached
- [ ] If faster than 0.3s or slower than 0.7s → **FAIL** (dwell not configured right)
- [ ] **Expected:** ~500ms (0.5 seconds)

### Phase 2: Cooldown Behavior

**Scenario 2.1: Cooldown After Auto-Capture**
- [ ] Auto-capture happens
- [ ] Immediately re-strike perfect pose
- [ ] **Expected:** No second photo captured
- [ ] **Wait:** ~2 seconds
- [ ] **Expected:** Next perfect pose triggers capture again
- [ ] **Verify:** Cooldown is ~2 seconds, not more/less

**Scenario 2.2: Manual Shutter During Cooldown**
- [ ] After auto-capture, cooldown is active
- [ ] Try to tap shutter button manually
- [ ] **Expected:** Tap is ignored (button disabled or no capture)
- [ ] **Wait:** Cooldown expires (~2s)
- [ ] Tap shutter button again
- [ ] **Expected:** Photo captures with normal haptic feedback

**Scenario 2.3: Haptic Feedback Differs**
- [ ] Auto-capture: Heavy vibration (strong)
- [ ] Manual shutter: Medium vibration (normal)
- [ ] **Verify:** Users can feel the difference

### Phase 3: State Transitions & Cancellation

**Scenario 3.1: Leaving Perfect Cancels Pending**
- [ ] Strike perfect pose
- [ ] **Wait:** 0.2s (halfway through dwell)
- [ ] Move to "close" state (lean slightly)
- [ ] **Expected:** Auto-capture does NOT happen (was canceled)
- [ ] **Wait:** 1+ seconds
- [ ] **Verify:** No photo was saved

**Scenario 3.2: Perfect → Close → Perfect = Full Dwell**
- [ ] Strike perfect pose
- [ ] **Wait:** 0.2s
- [ ] Move to close (interrupt)
- [ ] **Wait:** 0.1s
- [ ] Back to perfect
- [ ] **Wait:** Total 1.5s from last perfect transition
- [ ] **Expected:** Auto-capture happens after another full 0.5s from re-entering perfect
- [ ] **Verify:** Dwell timer resets, not cumulative

**Scenario 3.3: Mode Switch Resets**
- [ ] Auto-capture mode: perfect pose → halfway dwell
- [ ] Switch to different pose library or crop mode
- [ ] **Expected:** Dwell timer resets
- [ ] **Verify:** If dwell was canceled, no capture happens

### Phase 4: Multiple Cameras

**Scenario 4.1: Front Camera Auto-Capture**
- [ ] Switch to front camera (selfie)
- [ ] Strike perfect pose
- [ ] **Expected:** Auto-capture works same as back camera
- [ ] Photo quality, timing, haptic all consistent

**Scenario 4.2: Back Camera Auto-Capture**
- [ ] Switch to back camera (landscape/wide)
- [ ] Strike perfect pose
- [ ] **Expected:** Auto-capture works same as front camera
- [ ] Dwell time, cooldown, haptic consistent

### Phase 5: Different Poses

**Test each of the 6 reference poses:**

- [ ] **Pose 1 - Nghiêng nhẹ (Slight Tilt):** Auto-capture at perfect
- [ ] **Pose 2 - Tay chống cằm (Hand on Chin):** Auto-capture at perfect
- [ ] **Pose 3 - Bước đi (Walking):** Auto-capture at perfect
- [ ] **Pose 4 - Xoay người (Turned):** Auto-capture at perfect
- [ ] **Pose 5 - Tựa vai (Leaning):** Auto-capture at perfect
- [ ] **Pose 6 - Chiến binh II (Warrior II):** Auto-capture at perfect

**Expected:** All poses trigger auto-capture consistently

### Phase 6: Edge Cases & Stress

**Scenario 6.1: Rapid Perfect Transitions**
- [ ] Quickly cycle through perfect/close/perfect/close
- [ ] **Expected:** Only one capture per stable perfect hold
- [ ] **Verify:** No double-captures on rapid state changes

**Scenario 6.2: Hold Perfect for 3+ Seconds**
- [ ] Enter perfect state
- [ ] Hold for 3+ seconds
- [ ] **Expected:** One auto-capture after ~0.5s
- [ ] **Verify:** No repeated captures just because holding perfect

**Scenario 6.3: Perfect at Different Distances**
- [ ] Close distance (face fills frame): auto-capture works
- [ ] Medium distance (full body visible): auto-capture works
- [ ] Far distance (should not be perfect): not tested (far state won't trigger)
- [ ] **Expected:** Consistent behavior

**Scenario 6.4: Lighting Variations**
- [ ] Bright outdoor light: auto-capture works
- [ ] Indoor dim light: auto-capture works
- [ ] Mixed/shadow: auto-capture works
- [ ] **Expected:** Match quality consistent, timing unaffected

### Phase 7: UI/UX Polish

**Scenario 7.1: Shutter Button State**
- [ ] During normal match: shutter button is active
- [ ] During cooldown: shutter button appears disabled/grayed
- [ ] **Expected:** Clear visual feedback (optional, if implemented)

**Scenario 7.2: Match State Display**
- [ ] "97% khớp" with yellow color when perfect
- [ ] Corners/brackets animate/pulse indicating perfect match
- [ ] **Expected:** Smooth animations, no glitches

**Scenario 7.3: Toast Notification**
- [ ] After auto-capture, "Đã lưu" toast appears for ~1.6s
- [ ] Toast appears **only once** per capture (not repeated)
- [ ] **Expected:** No duplicate toasts, clean UX

### Phase 8: Background & Lifecycle

**Scenario 8.1: App Goes Background During Dwell**
- [ ] Perfect pose → halfway dwell
- [ ] Tap home (app goes background)
- [ ] **Expected:** Dwell canceled, no capture
- [ ] Reopen app
- [ ] **Expected:** Auto-capture tracker reset, ready for next use

**Scenario 8.2: App Resumes**
- [ ] Strike perfect pose before backgrounding
- [ ] Go background + resume quickly
- [ ] **Expected:** Tracker is reset (no stale dwell state)
- [ ] Can capture again normally

---

## 🎯 Test Matrix

| Camera | Pose | Auto-Capture | Cooldown | Haptic | Dwell |
|--------|------|--------------|----------|--------|-------|
| Front  | 1    | ✅           | ✅       | ✅     | ✅    |
| Front  | 2    | ✅           | ✅       | ✅     | ✅    |
| Front  | 3    | ✅           | ✅       | ✅     | ✅    |
| Back   | 4    | ✅           | ✅       | ✅     | ✅    |
| Back   | 5    | ✅           | ✅       | ✅     | ✅    |
| Back   | 6    | ✅           | ✅       | ✅     | ✅    |

---

## 🐛 Issue Reporting Template

If any test fails, report as:

```
**Test Case:** [Scenario number, e.g., 2.1]
**Device:** [iPhone model, iOS version]
**Pose:** [Which pose, if applicable]
**Camera:** [Front/Back]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happened]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
...

**Logs:**
[Console output, if any errors]

**Blocking:** [Yes/No - blocks release?]
```

---

## ✅ Sign-Off

**Tester:** [Name]  
**Date:** [YYYY-MM-DD]  
**Device:** [iPhone model + iOS version]  
**Result:** ☐ PASS ☐ FAIL  
**Known Issues:** [List any non-blocking issues found]

---

## 📝 Notes

- Test each pose at least once with front camera
- Test at least 2 poses with back camera (variation)
- Timing: dwell should be consistent (±100ms is acceptable)
- Haptic: should be noticeably different (heavy vs medium)
- Toast: exactly once per capture (both auto and manual)
- No crashes, hangs, or UI glitches during testing

---

**Ready to test? Let's go! 🚀**
