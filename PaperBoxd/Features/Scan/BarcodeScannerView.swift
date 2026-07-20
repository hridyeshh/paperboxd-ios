import SwiftUI
import AVFoundation

/// Live camera barcode scanner. Requests camera permission, shows a real preview, and
/// reports the first EAN-13 / EAN-8 / UPC-E code it reads (book barcodes are EAN-13 ISBNs).
///
/// Status is surfaced to the SwiftUI host so it can render permission / unavailable
/// fallbacks (e.g. on the Simulator, which has no camera).
struct BarcodeScannerView: UIViewControllerRepresentable {
    enum Status { case scanning, denied, unavailable }

    var onCode: (String) -> Void
    var onStatus: (Status) -> Void
    var torchOn: Bool = false

    func makeUIViewController(context: Context) -> BarcodeScannerController {
        let vc = BarcodeScannerController()
        vc.onCode = onCode
        vc.onStatus = onStatus
        return vc
    }

    func updateUIViewController(_ vc: BarcodeScannerController, context: Context) {
        vc.setTorch(torchOn)
    }
}

final class BarcodeScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onStatus: ((BarcodeScannerView.Status) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmit = false
    private var device: AVCaptureDevice?
    private var pendingTorch = false

    /// Toggles the rear torch. Safe to call before the session is configured —
    /// the request is remembered and applied once the device is available.
    func setTorch(_ on: Bool) {
        pendingTorch = on
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Torch unavailable (e.g. front camera / Simulator) — ignore silently.
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestPermissionAndStart()
    }

    private func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureSession() } else { self?.onStatus?(.denied) }
                }
            }
        default:
            onStatus?(.denied)
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onStatus?(.unavailable)
            return
        }
        self.device = device
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onStatus?(.unavailable)
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        onStatus?(.scanning)
        // startRunning blocks; keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.setTorch(self?.pendingTorch ?? false) }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didEmit,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        didEmit = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
        onCode?(code)
    }
}
