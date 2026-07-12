# Auto-Capture Implementation Guide (WIN-9)

## Overview

When a user's pose reaches **perfect** state, the app automatically captures a photo after a short "dwell time" (stable hold). This improves UX:
- No need to tap shutter button
- Feels responsive and smart
- Prevents accidental double-captures via cooldown

## Architecture

```
┌─────────────────┐
│ Pose Matching   │  ← live pose frame-by-frame
└────────┬────────┘
         │ matchState (perfect/close/far/none)
         ↓
┌─────────────────────────────┐
│ PerfectStateTracker         │
│ - Track perfect dwell time  │
│ - Emit: shouldCapture       │
│ - Enforce cooldown          │
└────────┬────────────────────┘
         │
         ↓ shouldCapture=true
┌─────────────────┐
│ capturePhoto()  │  ← actual photo capture
└─────────────────┘
```

## Integration Checklist

### 1. Add Tracker to CameraStore

```swift
// CameraAI/Store/CameraStore.swift
@MainActor
class CameraStore: ObservableObject {
    @Published var autoCaptureTracker = PerfectStateTracker()
    // ... rest of store
}
```

### 2. Wire Pose Matching → Tracker

In `CameraScreen.startCamera()`, after pose matching:

```swift
controller.onFrame = { pixelBuffer, orientation in
    guard store.mode != .nhom else { return }
    guard let live = detector.detect(in: pixelBuffer, orientation: orientation) else { return }

    let reference = store.selectedPose?.keypoints ?? .standing()
    let target = store.mode == .can ? reference.upperBody : reference
    let result = PoseMatcher.match(live: live, reference: target)

    DispatchQueue.main.async {
        store.matchState = result.state
        
        // NEW: Feed match state to auto-capture tracker
        store.autoCaptureTracker.update(matchState: result.state)
    }
}
```

### 3. Listen for Auto-Capture Events

In `CameraScreen.body`, wire the capture trigger:

```swift
.onAppear {
    _ = store.autoCaptureTracker.$shouldCapture
        .filter { $0 }
        .sink { _ in
            capturePhotoWithFeedback(reason: .autoCaptureAfterDwell)
        }
}
```

### 4. Update Shutter Button Behavior

Shutter button can now respect cooldown:

```swift
ShutterButton(state: store.displayMatchState) {
    // Respect cooldown: ignore if cooling down
    if !store.autoCaptureTracker.isInCooldown {
        capturePhotoWithFeedback(reason: .manualShutterButton)
    }
}
```

### 5. Reset on State Changes

When switching modes or clearing, reset the tracker:

```swift
.onChange(of: store.mode) { _, newMode in
    if newMode == .nhom {
        store.matchState = .none
        store.autoCaptureTracker.reset()  // NEW
    }
}

.onChange(of: store.selectedPose) { _, _ in
    store.autoCaptureTracker.reset()  // NEW
}
```

## Configuration

Default settings in `PerfectStateTracker`:

```swift
// Time to hold perfect before auto-capture
let dwellTimeMs = 500  // milliseconds (0.5s)

// Cooldown after capture (prevent spam)
let cooldownMs = 2000  // milliseconds (2s)
```

To customize:

```swift
@Published var autoCaptureTracker = PerfectStateTracker(
    dwellTimeMs: 400,   // Capture faster
    cooldownMs: 1500    // Shorter cooldown
)
```

## Behavior Details

### Perfect State Holding

1. User's pose reaches `perfect` state
2. Timer starts (dwell time)
3. If pose stays `perfect` for full dwell time → capture automatically
4. If pose changes to `close/far/none` → timer resets

### Capture Locking

After auto-capture:
1. Photo is taken
2. Cooldown period starts (2 seconds)
3. During cooldown, manual shutter button is **disabled**
4. After cooldown, user can capture again

### Cancel Scenarios

Auto-capture is **canceled** if:
- User leaves `perfect` state (moves, pose changes)
- User presses shutter during dwell (manual override)
- Mode switches
- App goes to background

## Haptic & Toast Feedback

Different feedback for auto-capture vs manual:

```swift
// Auto-capture: stronger haptic (user doesn't expect it)
UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

// Manual shutter: normal haptic
UIImpactFeedbackGenerator(style: .medium).impactOccurred()

// Success (both): notification + toast "Đã lưu"
UINotificationFeedbackGenerator().notificationOccurred(.success)
showToast()
```

**Only one toast per capture** (both auto and manual use same toast)

## Testing

### Manual Testing Checklist

- [ ] User holds perfect pose → auto-capture after ~0.5s
- [ ] Haptic is strong (different from manual shutter)
- [ ] Toast appears once after capture
- [ ] User can't capture again until cooldown ends
- [ ] Moving during dwell cancels capture
- [ ] Manual shutter during dwell can still capture
- [ ] Switching modes/poses resets tracker
- [ ] Multiple consecutive captures respect cooldown

### Automated Tests

Run `PerfectStateTrackerTests.swift`:
```bash
xcodebuild test -scheme CameraAI -only CameraAITests/PerfectStateTrackerTests
```

15 tests covering:
- Dwell timer accuracy
- Cooldown enforcement
- State transitions
- Manual vs auto capture
- Edge cases (rapid transitions, etc.)

## Troubleshooting

**Problem: Auto-capture triggers too early/late**
→ Adjust `dwellTimeMs` in PerfectStateTracker init

**Problem: Captures spam when holding perfect**
→ Increase `cooldownMs`

**Problem: Haptic doesn't feel right**
→ Try `.light` or `.rigid` feedback styles

**Problem: Toast appears twice**
→ Check only one sink is listening to `shouldCapture`; only one `showToast()` call

## Related Files

- `PerfectStateTracker.swift` - State machine (core logic)
- `PerfectStateTrackerTests.swift` - 15 unit tests
- `CameraScreen+AutoCapture.swift` - Integration helpers
- `MatchState.swift` - UI copy ("Sắp chụp...")
- `CameraStore.swift` - State holder

## References

- **Issue:** WIN-9 (Chuẩn hoá hành vi khi pose đạt trạng thái hoàn hảo)
- **Acceptance Criteria:** Copy updated, dwell time, cooldown, state-change cancel, haptic/toast 1x

---

**Phase:** 3/5 (Integration)  
**Status:** Documentation complete, ready for CameraScreen wiring
