import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

// MARK: - Генерация QR

func makeQRImage(_ string: String) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scale: CGFloat = 10
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cg)
}

// MARK: - Сканер (чистый AVFoundation, без внешних зависимостей)

final class QRScanDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: (String) -> Void
    private var done = false
    init(onFound: @escaping (String) -> Void) { self.onFound = onFound }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !done else { return }
        for obj in metadataObjects {
            if let readable = obj as? AVMetadataMachineReadableCodeObject,
               readable.type == .qr, let value = readable.stringValue {
                done = true
                onFound(value)
                break
            }
        }
    }
}

final class QRScanViewController: UIViewController {
    var onFound: (String) -> Void = { _ in }
    private let session = AVCaptureSession()
    private var scanDelegate: QRScanDelegate?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        let d = QRScanDelegate(onFound: { [weak self] s in
            DispatchQueue.main.async { self?.onFound(s) }
        })
        scanDelegate = d
        output.setMetadataObjectsDelegate(d, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
        let s = session
        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let s = session
        DispatchQueue.global(qos: .userInitiated).async { s.stopRunning() }
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onFound: (String) -> Void
    func makeUIViewController(context: Context) -> QRScanViewController {
        let vc = QRScanViewController()
        vc.onFound = onFound
        return vc
    }
    func updateUIViewController(_ uiViewController: QRScanViewController, context: Context) {}
}

// MARK: - Экран «Мой QR / Сканировать»

struct AddFriendQRScreen: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var scannedNick: String?
    @State private var error = ""
    @State private var busy = false

    private var myPayload: String { "neirox:add:" + (store.me?.nick ?? "") }

    static func parseNick(_ s: String) -> String? {
        guard s.hasPrefix("neirox:add:") else { return nil }
        let nick = String(s.dropFirst("neirox:add:".count))
        return nick.isEmpty ? nil : nick
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 16) {
                    Picker("", selection: $mode) {
                        Text(tr("Мой код", "My code", "Mein Code")).tag(0)
                        Text(tr("Сканировать", "Scan", "Scannen")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .onChange(of: mode) { _ in error = ""; scannedNick = nil }

                    if mode == 0 {
                        Spacer()
                        if let img = makeQRImage(myPayload) {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Text("@" + (store.me?.nick ?? ""))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(tr("Покажи этот код другу — пусть отсканирует во вкладке «Сканировать»",
                                "Show this code to a friend — have them scan it under “Scan”",
                                "Zeig diesen Code einem Freund – er scannt ihn unter „Scannen“"))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    } else {
                        QRScannerRepresentable { value in
                            guard scannedNick == nil else { return }
                            if let nick = Self.parseNick(value) {
                                error = ""
                                scannedNick = nick
                            } else {
                                error = tr("Это не код друга Neirox", "Not a Neirox friend code", "Kein Neirox-Freundescode")
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(16)
                        ErrorText(text: error)
                        if let nick = scannedNick {
                            VStack(spacing: 10) {
                                Text("@" + nick).font(.system(size: 16, weight: .semibold)).foregroundColor(Theme.text)
                                HStack(spacing: 10) {
                                    Button {
                                        busy = true
                                        Task {
                                            do {
                                                try await store.sendRequestByNick(nick)
                                                dismiss()
                                            } catch {
                                                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
                                                scannedNick = nil
                                            }
                                            busy = false
                                        }
                                    } label: {
                                        Text(tr("Добавить в друзья", "Add friend", "Freund hinzufügen"))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16).padding(.vertical, 9)
                                            .background(Theme.accentGradient)
                                            .clipShape(Capsule())
                                    }
                                    .disabled(busy)
                                    Button(tr("Ещё раз", "Rescan", "Erneut")) { scannedNick = nil }
                                        .font(.system(size: 13))
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .neonScreen(tr("Добавить по QR", "Add by QR", "Per QR hinzufügen"))
        }
    }
}
