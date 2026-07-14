---
name: casube-photo-library-gallery
description: Use when wiring the "Thư viện ảnh" gallery sheet (CameraAI/PoseLibrary/PhotoLibrarySheet.swift) to real Photos library data via PhotoKit — replacing placeholder thumbnails, requesting read access (PHPhotoLibrary, PHAsset, PHAuthorizationStatus), handling full/limited/denied/restricted/empty states, loading thumbnails with PHCachingImageManager, or wiring "Chọn thêm ảnh" (presentLimitedLibraryPicker). Also use when reviewing a WIN-12-style PhotoKit gallery implementation for correctness.
---

# PhotoKit gallery (WIN-12)

## Overview

WIN-12 is **implemented** (commit `da76fb9`, branch `sprint-1/win-12`):
`PhotoLibrarySheet.swift` was a stub — a 3-column `LazyVGrid` of hardcoded `Color`
rectangles — and now sources real `PHAsset` thumbnails from the device's Photos
library, with the original 3-column layout untouched. The only *other* Photos
permission in the app is `.addOnly` (`PhotoSaver.swift`, save-after-capture) — the
read grant this feature requests is **separate and additional** to that one, not a
replacement.

Linear can lag the repo: as of 2026-07-14 the WIN-12 issue still shows status "In
Progress" even though every acceptance criterion below is met in code. Verify against
`git log -- casube.ios/CameraAI/PoseLibrary/PhotoLibrarySheet.swift` and the current
file content, not the ticket status, before treating this as unstarted work.

## Permission model

- `PHAccessLevel` only has **two** cases: `.addOnly` and `.readWrite` — there is no
  `.readOnly` level, despite what the ticket text implies. To browse/display the
  library at all (even though this feature never edits or deletes anything) you must
  request `PHPhotoLibrary.authorizationStatus(for: .readWrite)` /
  `requestAuthorization(for: .readWrite)`. This is confirmed against the SDK header
  (`PHPhotoLibrary.h`) — don't try `.readOnly`, it won't compile.
- Add `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` (Vietnamese) to **both** Debug and
  Release configs in `project.pbxproj`, alongside the existing
  `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` — don't replace the add-only key,
  the capture-save flow still needs it.
- Model **5** states, not 4 — `PHAuthorizationStatus` also has `.restricted` (parental
  controls / MDM), which the ticket's language glosses over. Treat it the same as
  `.denied` (no Settings recovery is possible for `.restricted`, so the CTA can still
  point at Settings — it's a no-op there, which is the standard system behavior).
- Only call `requestAuthorization` from `.notDetermined`; for every other status just
  branch the view.

## Denied / restricted UI — reuse the existing pattern

`CameraScreen.swift` (~line 138) already has the app's permission-denied idiom for the
camera: icon + Vietnamese title/subtitle + yellow capsule "Mở Cài đặt" button opening
`UIApplication.openSettingsURLString`. The shipped `deniedState` in
`PhotoLibrarySheet.swift` copies this shape almost verbatim, including the same
`Tokens.yellow` capsule button — the only thing that changes is the *surrounding*
chrome: `CameraScreen`'s denied view sits on its full-screen dark background, while the
sheet's denied view sits inside the sheet's white background with `Tokens.ink`/
`Tokens.muted` text. Don't reinterpret "swap the styling" as swapping the yellow button
too; the ticket's "đồng bộ pattern" note means visual/copy consistency with
`CameraScreen`, not a from-scratch denied-state design. (WIN-11, the ticket this note
originally referenced for a shared pattern, is still status "Todo" with no code as of
2026-07-14 — re-check before assuming it has since landed something to reuse instead.)

## Fetching and thumbnails

```swift
let options = PHFetchOptions()
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
```

- Use `PHCachingImageManager`, and **pair `startCachingImages` with
  `stopCachingImages`** for the range of visible/prefetched assets as the grid scrolls
  (e.g. on `LazyVGrid` item `.onAppear`/`.onDisappear`, or a coarser windowed update).
  Starting without ever stopping defeats the point of a *caching* manager — it grows
  unbounded instead of shedding off-screen assets.
- Per-cell thumbnail requests: prefer `.task(id: asset.localIdentifier) { ... }` inside
  the cell view over a manual completion handler. SwiftUI cancels `.task` automatically
  when the view is recycled/removed, which sidesteps the classic PhotoKit grid bug where
  a stale `requestImage` completion for a reused cell paints the wrong photo. If you use
  a manual completion handler instead, you must track and cancel the previous
  `PHImageRequestID` yourself before issuing a new one for the same cell.
- Request options: `deliveryMode = .opportunistic`, `isSynchronous = false`, target size
  in pixels sized to the actual grid cell (not `PHImageManagerMaximumSize` — that's for
  the full-size viewer only).

## Full-size view (tap a thumbnail)

- A plain `Image` in a sheet/full-screen cover is enough (ticket explicitly says no
  QuickLook/zoom polish needed).
- Request with `targetSize: PHImageManagerMaximumSize` **and
  `options.isNetworkAccessAllowed = true`**. Without this flag, assets that are
  iCloud-optimized (no full-res data on-device — the common default) can return a
  low-res image or `nil` instead of the full photo. Pair with the request's progress
  handler if you want a spinner during the iCloud download.

## Limited access

- Show the granted photos in the same grid (fetch/thumbnail logic is identical — PHKit
  only returns the permitted assets).
- "Chọn thêm ảnh" calls `PHPhotoLibrary.shared().presentLimitedLibraryPicker(from:)`,
  which needs a concrete presenting `UIViewController` — it is **not**
  `PHPickerViewController`. The method itself is declared in the
  `PHPhotoLibrary(PhotosUISupport)` category, in **`PhotosUI/PHPhotoLibrary+PhotosUISupport.h`**
  — confirmed against the SDK header — so the file **needs `import PhotosUI`** (in
  addition to `import Photos`), or it won't resolve. In SwiftUI, resolve the presenter
  from the active scene, e.g.:

```swift
if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
   let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController {
    PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
}
```

## Empty states

- Full/limited access but zero assets: centered "Chưa có ảnh nào" text, same
  typography as the rest of the sheet — no illustration needed per scope.

## Common mistakes

| Mistake | Why it matters |
|---|---|
| Requesting `PHAccessLevel.readOnly` | Doesn't exist — only `.addOnly`/`.readWrite`; won't compile. Use `.readWrite` to read; the "over-broad permission" concern in the ticket is about not requesting extra *edit/delete* capability, not about avoiding this enum case |
| Only 4 states (skip `.restricted`) | Parental-control/MDM users hit an unhandled case |
| `startCachingImages` with no matching `stopCachingImages` | Cache grows unbounded, defeats `PHCachingImageManager`'s purpose |
| Setting `@State` from a `PHImageManager`/`PHCachingImageManager` result handler without hopping to main | Handler fires off-thread; follow the codebase's existing `DispatchQueue.main.async { ... }` convention (see `CameraScreen.startCamera()`) |
| Full-size request missing `isNetworkAccessAllowed` | iCloud-optimized photos come back blank/low-res |
| Calling `presentLimitedLibraryPicker` with only `import Photos` | It's declared in `PhotosUI`'s `PHPhotoLibrary+PhotosUISupport.h` category — missing `import PhotosUI` fails to compile ("no member") |
| Confusing `presentLimitedLibraryPicker` with `PHPickerViewController` | Wrong picker — one manages the limited grant, the other is a general image picker requiring no permission at all |
