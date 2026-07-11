import SwiftUI
import UIKit

/// Frame 04 — live pose camera: permission gate, viewfinder + AI overlay,
/// zoom/aspect/mode controls, pose library, shutter → crop → save.
struct CameraScreen: View {
    @Environment(CameraStore.self) private var store

    private enum Permission {
        case checking, granted, denied
    }

    @State private var permission: Permission = .checking
    @State private var controller = CameraController()
    @State private var detector = PoseDetector()
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        @Bindable var store = store
        ZStack {
            Tokens.cameraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Viewfinder(
                    state: store.displayMatchState,
                    mode: store.mode,
                    aspectRatio: store.aspectRatio
                ) {
                    viewfinderContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)

                ZoomSelector(zoom: $store.zoom)
                    .padding(.bottom, 14)

                actionRow
                    .padding(.top, 4)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                ModeSelector(mode: $store.mode) {
                    store.isPoseLibraryOpen = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                #if DEBUG
                MatchStateDevSwitch(manualState: $store.manualMatchState)
                    .padding(.bottom, 6)
                #endif
            }

            if store.showSavedToast {
                SavedToast()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 220)
            }
        }
        .preferredColorScheme(.dark)
        // Tap-outside closes the aspect popup; keyed as overlay so it sits above all chrome.
        .overlay {
            if store.isAspectMenuOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { store.isAspectMenuOpen = false }
                    }
                    .overlay(alignment: .topTrailing) {
                        AspectRatioMenu(aspectRatio: $store.aspectRatio, isMenuOpen: $store.isAspectMenuOpen)
                            .padding(.top, 40)
                            .padding(.trailing, 22)
                    }
            }
        }
        .sheet(isPresented: $store.isPoseLibraryOpen) {
            PoseLibrarySheet().environment(store)
        }
        .sheet(isPresented: $store.isPhotoLibraryOpen) {
            PhotoLibrarySheet()
        }
        .task { await startCamera() }
        .onDisappear { controller.stop() }
        .onChange(of: store.zoom) { _, newZoom in
            controller.setZoom(newZoom)
        }
        .onChange(of: store.mode) { _, newMode in
            if newMode == .nhom { store.matchState = .none }
        }
        .animation(.easeInOut(duration: 0.18), value: store.showSavedToast)
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            HStack(spacing: 14) {
                Image(systemName: "bolt")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Tokens.yellow)
                Image(systemName: "grid")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Tokens.yellow)
            }
            Spacer()
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                    Text("4")
                        .font(AppFont.medium(12))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                AspectRatioButton(
                    aspectRatio: Bindable(store).aspectRatio,
                    isMenuOpen: Bindable(store).isAspectMenuOpen
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var viewfinderContent: some View {
        switch permission {
        case .granted:
            CameraPreview(session: controller.session)
        case .checking:
            Tokens.viewfinderInner
        case .denied:
            VStack(spacing: 12) {
                Image(systemName: "video.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(Tokens.muted)
                Text("Camera.AI cần quyền truy cập camera")
                    .font(AppFont.medium(14))
                    .foregroundStyle(.white)
                Text("Vào Cài đặt để cấp quyền camera cho ứng dụng.")
                    .font(AppFont.regular(12))
                    .foregroundStyle(Tokens.muted)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Mở Cài đặt")
                        .font(AppFont.medium(13))
                        .foregroundStyle(Tokens.ink)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(Tokens.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .multilineTextAlignment(.center)
            .padding(24)
        }
    }

    private var actionRow: some View {
        HStack {
            Button {
                store.isPhotoLibraryOpen = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Tokens.photoButtonGradient)
                    Image(systemName: "photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Tokens.yellow)
                        .padding(6)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            ShutterButton(state: store.displayMatchState) {
                capturePhoto()
            }

            Spacer()

            Button {
                controller.flip()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Tokens.glassGradient, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Camera / AI pipeline

    private func startCamera() async {
        let granted = await CameraController.requestPermission()
        permission = granted ? .granted : .denied
        guard granted else { return }

        let store = store
        let detector = detector
        controller.onFrame = { pixelBuffer, orientation in
            // Group mode is UI-only (no real multi-person scoring in the MVP).
            guard store.mode != .nhom else { return }
            guard let live = detector.detect(in: pixelBuffer, orientation: orientation) else { return }

            let reference = store.selectedPose?.keypoints ?? .standing()
            let target = store.mode == .can ? reference.upperBody : reference
            let result = PoseMatcher.match(live: live, reference: target)

            DispatchQueue.main.async {
                store.matchState = result.state
            }
        }
        controller.start()
        controller.setZoom(store.zoom)
    }

    private func capturePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let ratio = store.aspectRatio
        controller.capturePhoto { image in
            guard let image else { return }
            Task {
                do {
                    try await PhotoSaver.save(image, croppedTo: ratio)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showToast()
                } catch {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func showToast() {
        toastDismissTask?.cancel()
        store.showSavedToast = true
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            store.showSavedToast = false
        }
    }
}

#Preview {
    CameraScreen()
        .environment(CameraStore())
}
