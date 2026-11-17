import SwiftUI
import WebKit
import UIKit
import AVFoundation

struct ContentView: View {
    @State private var webView: WKWebView?
    @State private var downloadedFile: URL?
    @State private var showShareSheet = false
    @State private var showScanner = false
    @State private var alertMessage: String?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.68, green: 0.57, blue: 1))

                    Text("ShareMeFiles")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }

                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 38)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    pasteInviteLink()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    webView?.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.045, green: 0.055, blue: 0.08))

            ShareMeWebView(
                webView: $webView,
                onDownload: { url in
                    downloadedFile = url
                    showShareSheet = true
                },
                onLoadingChanged: { loading in
                    isLoading = loading
                }
            )
        }
        .background(Color(red: 0.045, green: 0.055, blue: 0.08).ignoresSafeArea())

        .sheet(isPresented: $showScanner) {
            QRScannerSheet { scannedValue in
                showScanner = false
                openInviteLink(scannedValue)
            }
            .ignoresSafeArea()
        }

        .sheet(isPresented: $showShareSheet, onDismiss: {
            if let url = downloadedFile {
                try? FileManager.default.removeItem(at: url)
            }
            downloadedFile = nil
        }) {
            if let url = downloadedFile {
                ActivityView(activityItems: [url])
                    .ignoresSafeArea()
            }
        }

        .alert("ShareMeFiles", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("ОК", role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func pasteInviteLink() {
        guard let value = UIPasteboard.general.string else {
            alertMessage = "Сначала скопируй ссылку ShareMeFiles."
            return
        }

        openInviteLink(value)
    }

    private func openInviteLink(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: cleaned),
              let host = url.host?.lowercased(),
              host == "sharemefiles.com" || host == "www.sharemefiles.com",
              url.path.range(
                of: "^/s/[a-f0-9]{32}$",
                options: .regularExpression
              ) != nil,
              !url.fragment.isEmpty else {

            alertMessage = "Это не QR-код комнаты ShareMeFiles."
            return
        }

        webView?.load(URLRequest(url: url))
    }
}

// MARK: - QR Scanner

struct QRScannerSheet: View {
    let onScan: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerView(onScan: onScan)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button("Закрыть") {
                        dismiss()
                    }

                    Spacer()

                    Text("Сканирование QR")
                        .font(.system(size: 17, weight: .bold))

                    Spacer()

                    Color.clear.frame(width: 55)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Text("Наведи камеру на QR-код ShareMeFiles")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())

                Spacer()

                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 250, height: 250)

                Spacer()

                Text("Подключение откроется автоматически")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 42)
            }
            .foregroundStyle(.white)
        }
        .background(.black)
        .preferredColorScheme(.dark)
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(
        _ controller: QRScannerController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ controller: QRScannerController,
        coordinator: ()
    ) {
        controller.stopScanning()
    }
}

final class QRScannerController:
    UIViewController,
    AVCaptureMetadataOutputObjectsDelegate {

    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didConfigure = false
    private var didScan = false

    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.text = "Запрашиваем доступ к камере…"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: 24
            ),
            statusLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -24
            )
        ])

        checkCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            configureSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.showCameraDenied()
                    }
                }
            }

        case .denied, .restricted:
            showCameraDenied()

        @unknown default:
            showCameraDenied()
        }
    }

    private func configureSession() {
        guard !didConfigure else { return }
        didConfigure = true

        statusLabel.text = "Подготовка камеры…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else {

                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.statusLabel.text = "Не удалось запустить камеру"
                }
                return
            }

            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()

            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.statusLabel.text = "Сканер QR недоступен"
                }
                return
            }

            self.session.addOutput(output)

            output.setMetadataObjectsDelegate(self, queue: .main)

            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }

            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(
                    session: self.session
                )

                self.previewLayer?.videoGravity = .resizeAspectFill

                if let layer = self.previewLayer {
                    self.view.layer.insertSublayer(layer, at: 0)
                    layer.frame = self.view.bounds
                }

                self.statusLabel.isHidden = true
                self.session.startRunning()
            }
        }
    }

    private func showCameraDenied() {
        statusLabel.text =
            "Нет доступа к камере. Разреши его в настройках iPhone для ShareMeFiles."
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }

        didScan = true
        session.stopRunning()
        onScan?(value)
    }

    func stopScanning() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }
}

// MARK: - Share Sheet

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ controller: UIActivityViewController,
        context: Context
    ) {}
}
