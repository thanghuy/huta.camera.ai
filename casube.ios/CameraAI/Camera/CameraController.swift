import AVFoundation
import UIKit

/// AVCaptureSession wrapper: configuration, flip, zoom, photo capture, and a
/// video-frame tap that feeds the pose detector.
final class CameraController: NSObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "cameraai.session")
    private let videoQueue = DispatchQueue(label: "cameraai.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var currentDevice: AVCaptureDevice?
    private var configured = false
    private var currentZoom: Zoom = .x1
    private(set) var position: AVCaptureDevice.Position = .back

    /// Called on a background queue with every video frame.
    var onFrame: ((CVPixelBuffer, CGImagePropertyOrientation) -> Void)?
    private var photoCompletion: ((UIImage?) -> Void)?

    // MARK: Permission / lifecycle

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func start() {
        sessionQueue.async {
            self.configureIfNeeded()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        attachInput(position: .back)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()
        applyZoom(currentZoom)
    }

    private func attachInput(position: AVCaptureDevice.Position) {
        for input in session.inputs { session.removeInput(input) }
        // Prefer virtual multi-cam devices so 0.5x (ultra-wide) works.
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: position
        )
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        currentDevice = device
        self.position = position
    }

    // MARK: Controls

    func flip() {
        sessionQueue.async {
            let newPosition: AVCaptureDevice.Position = self.position == .back ? .front : .back
            self.session.beginConfiguration()
            self.attachInput(position: newPosition)
            self.session.commitConfiguration()
            self.applyZoom(self.currentZoom)
        }
    }

    func setZoom(_ zoom: Zoom) {
        sessionQueue.async {
            self.applyZoom(zoom)
        }
    }

    /// `Zoom.displayFactor` is the user-facing multiplier where 1x = the main wide
    /// lens. On virtual devices videoZoomFactor is relative to the widest lens, so
    /// the wide lens sits at the first switch-over factor (e.g. 2.0 when an
    /// ultra-wide is present).
    private func applyZoom(_ zoom: Zoom) {
        currentZoom = zoom
        guard let device = currentDevice else { return }
        let wideBaseline = device.virtualDeviceSwitchOverVideoZoomFactors.first
            .map { CGFloat(truncating: $0) } ?? 1
        let target = zoom.displayFactor * wideBaseline
        let clamped = min(max(target, device.minAvailableVideoZoomFactor),
                          device.maxAvailableVideoZoomFactor)
        do {
            try device.lockForConfiguration()
            device.ramp(toVideoZoomFactor: clamped, withRate: 8)
            device.unlockForConfiguration()
        } catch {
            // Zoom is cosmetic; ignore configuration failures.
        }
    }

    // MARK: Capture

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            self.photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Vision orientation for the current camera in portrait UI.
    var frameOrientation: CGImagePropertyOrientation {
        position == .front ? .leftMirrored : .right
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        let completion = photoCompletion
        photoCompletion = nil
        DispatchQueue.main.async {
            completion?(error == nil ? image : nil)
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer, frameOrientation)
    }
}
