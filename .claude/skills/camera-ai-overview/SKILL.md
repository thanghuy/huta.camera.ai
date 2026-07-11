---
name: camera-ai-overview
description: >
  Project context for the Camera.AI React Native app (an AI pose-guided camera).
  Read this FIRST whenever you start working anywhere in this repo — before editing
  screens, camera components, the pose-matching ML pipeline, the zustand store, or the
  Expo config. Use it whenever the task mentions Camera.AI, pose matching, the pose
  library, the aspect-ratio selector, the viewfinder overlay, the onboarding screen,
  "% khớp"/match state, or any file under src/. It captures the scope, architecture,
  tech stack, conventions, and milestone status that are NOT obvious from reading a
  single file, so you don't re-derive decisions or reintroduce things that were
  deliberately cut. Consult it even if the request seems small.
---

# Camera.AI — Project Overview

Camera.AI is a Vietnamese-market camera app (Expo / React Native) that helps users
pose for photos. The user picks a reference pose; the app overlays a skeleton guide on
the live viewfinder, scores how well the live pose matches the reference in real time
(the "% khớp" / match score), and colors the frame border + shutter ring by match
quality. When the shot is taken it is cropped to the chosen aspect ratio and saved
straight to the device photo library.

The UI language is **Vietnamese** — keep all user-facing strings in Vietnamese.

## Current scope (IMPORTANT — deliberately narrowed)

The original Claude Design mockup had 7 frames, but the user cut the scope to **two
screens only**. Do not rebuild the cut screens unless explicitly asked.

**In scope:**
1. **Onboarding** — logo, tagline "Chụp đúng dáng, đẹp mọi khung hình", CTA "Bắt đầu".
2. **Camera** — live viewfinder + AI pose overlay, zoom / aspect-ratio / mode selectors,
   a **Pose Library** bottom sheet, shutter, flip-camera.
   - Shutter behavior: capture a real photo → crop to the selected aspect ratio →
     save directly to the photo library (`expo-media-library`) with haptic + a small
     "Đã lưu" toast. **There is no separate countdown / processing / result screen.**

**Cut (do NOT build unless asked):** auto-countdown screen, "AI đang xử lý" screen,
dedicated result screen, share / retake buttons.

**Group mode (`nhom`) is UI-only:** single-person pose matching (`nguoi`, `can`) gets
real AI scoring. Multi-person matching is out of scope for the MVP — the mode chip
exists but does not compute a real group match score.

## Tech stack

- **Expo SDK 57** (React Native 0.86, React 19.2), **expo-router** file-based routing,
  New Architecture. TypeScript, strict mode. React Compiler is enabled.
- **expo-dev-client** workflow — this app uses native modules (camera, and later the ML
  pipeline), so it runs via `npx expo run:ios` / `run:android`, **not** Expo Go, and
  **not** web (media-library has no web impl and throws on import).
- Reanimated 4.5 + its companion **`react-native-worklets`** package. Do NOT add
  `react-native-worklets-core` (the old runtime) — it conflicts and breaks the Android build.
- `zustand` (with `persist` for the aspect-ratio preference via AsyncStorage).
- `react-native-svg` for the silhouette/skeleton, **`expo-symbols` (Apple SF Symbols)**
  for all UI icons, `expo-image-manipulator` (crop), `expo-haptics`, `expo-linear-gradient`.

### Planned but NOT yet installed (M3+)
Real pose detection will use **react-native-vision-camera v5 (Nitro)** +
**react-native-fast-tflite** running **MoveNet Lightning (INT8)** in a frame processor,
with **@shopify/react-native-skia** for the overlay. There is a known compatibility risk
between fast-tflite and vision-camera v5 — verify it empirically before committing, and
ask the user for permission before downloading the .tflite model (the one download in the
whole plan). See the approved plan at `~/.claude/plans/linear-squishing-pnueli.md`.

## Directory map (`src/`)

```
app/                     expo-router routes (thin wrappers only)
  _layout.tsx            Stack, headerShown:false, hides splash
  index.tsx              → OnboardingScreen
  camera.tsx             → CameraScreen
screens/
  OnboardingScreen.tsx   route "/", pushes "/camera"
  CameraScreen.tsx       permissions gate + camera chrome + capture/crop/save
components/
  camera/                Viewfinder, PoseOverlay, MatchBadge, ZoomSelector,
                         AspectRatioMenu, ModeSelector, ShutterButton, MatchStateDevSwitch
  poseLibrary/           PoseLibrarySheet (bottom-sheet modal), PoseCard
  ui/                    Chip, IconButton (shared primitives)
ml/
  referencePoses.ts      6 reference poses (keypoints still null — filled in M2)
  poseMatcher.ts         (M2, not yet created) pure similarity algo — unit-testable
  poseDetector.ts        (M3, not yet created) vision-camera + tflite worklet glue
store/
  useCameraStore.ts      zustand: mode, zoom, aspectRatio (persisted), library state,
                         mockMatchState (M1 placeholder, replaced by real AI in M4)
theme/tokens.ts          YELLOW #FFC72C, INK #1A1A16, CREAM #F4F1E8, MatchColors, CardGradient
types/pose.ts            Keypoints, MatchState, CameraMode, Zoom, AspectRatio, ReferencePose
```

Design reference (the original mockup) lives at `design-reference/Camera.AI - standalone.html`.

## Conventions to follow

- **Match state is a 4-value union** (`types/pose.ts`): `'none' | 'far' | 'close' | 'perfect'`,
  mapped to percentages 0/35/78/97 and to colors in `theme/tokens.ts` `MatchColors`
  (grey / red / yellow / green). Every match-driven visual (border, badge, shutter ring,
  arrows, hint text) keys off this single value — keep them consistent when you change one.
- **During M1 the match value is mocked** via `store.mockMatchState`, toggled by
  `MatchStateDevSwitch` (a `__DEV__`-only strip in the Camera screen). When the real
  pipeline lands (M4), replace this source — not the components that read it.
- **Colors/spacing come from `theme/tokens.ts`.** Don't hardcode the brand yellow/ink
  elsewhere; import the tokens.
- **Icons come from Apple's SF Symbols** via `expo-symbols` (`SymbolView`) — use the
  native SF Symbol name (e.g. `camera.fill`, `bolt.fill`, `arrow.triangle.2.circlepath`).
  Do NOT reach for `@expo/vector-icons`/Ionicons. SF Symbols are iOS-only, so any icon
  used on Android needs a fallback glyph (`fallback` prop / SVG); note it when you add one.
- **Aspect ratio** is one of `'4:3' | '16:9' | '1:1'`, persisted, and drives both the
  animated preview box (`Viewfinder`) and the post-capture crop (`CameraScreen`). The
  aspect-ratio switcher (icon top-right → popup) follows the `camera-aspect-ratio-feature`
  skill spec — reuse that skill when touching it.
- **expo-camera `zoom` prop is a 0–1 fraction** of max digital zoom, not an optical
  multiplier — the `0.5x…5x` chips map to approximate fractions in `CameraScreen`
  (`ZOOM_VALUE`). This is intentionally approximate; note it if you refine it.
- Keep `ml/poseMatcher.ts` a **pure function** (no RN/native imports) so it stays
  Jest-testable without a device — this is the main automated-test surface.

## Milestone status

- **M0 Scaffold** — done (Expo 57, dev-client, deps, folder structure, permissions in app.json).
- **M1 Static UI + mocked match data** — done (both screens, all camera chrome, pose
  library, capture→crop→save, dev match-state switch). Typecheck + lint clean.
- **M2 poseMatcher + reference data + Jest** — not started (keypoints in referencePoses.ts
  are still `null`).
- **M3 native camera + ML spike (vision-camera v5 + tflite)** — not started.
- **M4 wire real AI into UI** — not started.
- **M5 capture/save polish** — capture+save already wired in M1; remaining polish pending.

## Verifying changes

- `npx tsc --noEmit` and `npx expo lint` must stay clean (they currently are).
- Camera + ML behavior **cannot** be verified in a browser/preview or by the assistant
  here (no simulator configured) — the user runs `npx expo run:ios` / `run:android` on a
  real device/simulator and checks behavior manually. Give them a concrete checklist.
- Pure logic (once `poseMatcher.ts` exists) is verifiable via Jest without a device.
