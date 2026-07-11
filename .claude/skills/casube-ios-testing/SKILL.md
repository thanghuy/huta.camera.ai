---
name: casube-ios-testing
description: How to build, test, and verify the native iOS Camera.AI app (SwiftUI, under casube.ios/). Use this skill whenever the task involves running or writing tests for the iOS app, verifying a Swift/SwiftUI change works, running xcodebuild, checking the build, smoke-testing on the iOS simulator, taking simulator screenshots, or validating camera/pose behavior — even if the user just says "chạy test", "kiểm tra app", "verify thay đổi", or "app còn build được không". Also use it before claiming any iOS change is done, and alongside casube-camera-ai-overview when editing code under casube.ios/.
---

# Testing the Camera.AI iOS app

Everything below applies to the Xcode project at `casube.ios/CameraAI.xcodeproj`
(app target `CameraAI`, test target `CameraAITests`, shared scheme `CameraAI`).

## Environment setup (required — commands fail without this)

On this machine `xcode-select` points at CommandLineTools, not Xcode, so bare
`xcodebuild` fails with "requires Xcode". Prefix every xcodebuild/simctl command:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Use a disposable derived-data path (it's gitignored) so builds don't fight over
the shared Xcode cache — especially when multiple agents/build jobs may run:

```bash
DD=/tmp/cameraai-dd-$$   # or a scratchpad path
```

## Build and unit tests

```bash
cd /Users/huythang/Desktop/Camera/casube.ios

# Pick a simulator (no code signing needed). Names/OS versions drift, so query:
xcodebuild -scheme CameraAI -showdestinations 2>/dev/null | grep "iOS Simulator" | head
# then use its id:
DEST='id=<simulator-udid>'          # e.g. an iPhone 17 Pro entry
# 'platform=iOS Simulator,name=iPhone 17 Pro' also works if you omit OS=.

# Build (must stay clean):
xcodebuild -scheme CameraAI -destination "$DEST" -derivedDataPath "$DD" build 2>&1 \
  | grep -E "error|warning: |BUILD" | head -30

# Unit tests (PoseMatcherTests — matcher states/invariance + AspectRatio crop math):
xcodebuild -scheme CameraAI -destination "$DEST" -derivedDataPath "$DD" test 2>&1 \
  | grep -E "Test Case|Test Suite|error|failed|TEST" | tail -40
```

Expect `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`. The first build takes a
couple of minutes; later ones are fast. An "appintentsmetadataprocessor" warning
is normal noise.

## Writing new tests

- Tests live in `casube.ios/CameraAITests/` and use XCTest with
  `@testable import CameraAI`. New `.swift` files there are picked up
  automatically (filesystem-synchronized groups — never edit the pbxproj).
- The prime test surface is pure logic: `PoseMatcher`, `PoseSnapshot`,
  `AspectRatio.cropRect`, `MatchState` config. Keep `ML/PoseMatcher.swift` free
  of UIKit/Vision imports so this stays device-independent.
- Follow the existing style in `PoseMatcherTests.swift`: descriptive
  `testXxx` names, `XCTAssertEqual(_:accuracy:)` for floating point, small
  helpers for building/transforming `PoseSnapshot`s.
- Camera/Vision/UI behavior is NOT unit-testable here (no camera on
  simulators; no XCUITest target). Verify those via the smoke test + device
  checklist below instead of forcing brittle tests.

## Simulator smoke test (visual verification)

Use this to prove UI changes render correctly — never ask the user to check
what you can screenshot yourself:

```bash
SIM=<simulator-udid>
xcrun simctl boot $SIM 2>/dev/null            # ok if already booted
xcodebuild -scheme CameraAI -destination "id=$SIM" -derivedDataPath "$DD" build 2>&1 | grep BUILD
xcrun simctl install $SIM "$DD/Build/Products/Debug-iphonesimulator/CameraAI.app"
xcrun simctl privacy $SIM grant camera com.casube.cameraai   # skip the permission alert
xcrun simctl launch $SIM com.casube.cameraai --camera        # DEBUG arg: jump straight to camera screen
sleep 3
xcrun simctl io $SIM screenshot /path/to/shot.png
```

Then **Read the screenshot** and check it against the design
(`design-reference/Camera.AI - standalone.html`, or the casube-camera-ai-overview
skill's spec). Launch without `--camera` for the onboarding screen. Relaunch
between screens with `xcrun simctl terminate $SIM com.casube.cameraai` first.

Expected simulator quirks (not bugs):
- No camera hardware → preview is dark and match state stays "Không nhận diện".
- The DEBUG-only dev switch strip (bottom) lets states be eyeballed on device,
  but simctl can't tap; force states in code only for throwaway verification.

## What can only be verified on a real device

Give the user a concrete checklist instead of guessing — camera + Vision never
run on the simulator. Baseline checklist (trim to what changed):

1. Onboarding hiển thị đúng; "Bắt đầu" đẩy sang camera; prompt quyền camera tiếng Việt.
2. Preview live đúng theo từng tỉ lệ 4:3/16:9/1:1; tỉ lệ persist sau relaunch.
3. Zoom chips (0.5x cần máy có ultra-wide), flip camera hoạt động.
4. Chụp → ảnh crop đúng tỉ lệ trong Photos + haptic + toast "Đã lưu".
5. Thư viện dáng: lọc danh mục, chọn dáng highlight và đóng sheet.
6. Đứng vào/ra khung: match state none→far→close→perfect, mọi thành phần màu
   (viền, brackets, badge, mũi tên, hint, vòng shutter) đồng bộ.

The user runs from Xcode (needs their signing team; `DEVELOPMENT_TEAM` is
deliberately unset).

## Troubleshooting

- "xcodebuild requires Xcode" → the `DEVELOPER_DIR` export above is missing.
- "requested device could not be found" → OS version in the destination string
  is stale; re-query with `-showdestinations` and use `id=`.
- Concurrent builds erroring on locks → separate `-derivedDataPath` per job.
- Test target needs the app as host (`TEST_HOST`) — run tests via the scheme
  (as above), not by building the xctest bundle alone.
