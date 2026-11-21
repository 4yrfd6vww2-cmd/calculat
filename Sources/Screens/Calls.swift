import SwiftUI
import AVFoundation
import AudioToolbox
import WebRTC

enum CallState { case idle, outgoing, incoming, connecting, active }

struct CallPayload: Decodable {
    var sdp: String?
    var mid: String?
    var idx: Int?
}

struct CallSignal: Decodable {
    let id: Int
    let callId: String
    let sender: String
    let type: String
    let payload: CallPayload?
    let createdAt: Date
}

private final class PCDelegate: NSObject, RTCPeerConnectionDelegate {
    var onCandidate: ((RTCIceCandidate) -> Void)?
    var onState: ((RTCIceConnectionState) -> Void)?

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) { onState?(newState) }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) { onCandidate?(candidate) }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

@MainActor
final class Calls: ObservableObject {
    static let shared = Calls()

    @Published var state: CallState = .idle
    @Published var peerId: String?
    @Published var muted = false
    @Published var speaker = false
    @Published var seconds = 0
    @Published var failed = ""

    private var pollTimer: Timer?
    private var lastId = -1
    private var callId = ""
    private var factory: RTCPeerConnectionFactory?
    private var pc: RTCPeerConnection?
    private var track: RTCAudioTrack?
    private let delegate = PCDelegate()
    private var pendingIce: [RTCIceCandidate] = []
    private var remoteSet = false
    private var ringTimer: Timer?
    private var secTimer: Timer?
    private var timeoutTask: Task<Void, Never>?
    private var sendChain: Task<Void, Never>?

    private let servers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["turn:openrelay.metered.ca:80", "turn:openrelay.metered.ca:443",
                                  "turn:openrelay.metered.ca:443?transport=tcp"],
                     username: "openrelayproject", credential: "openrelayproject")
    ]

    // MARK: polling / signaling

    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in await Calls.shared.poll() }
        }
    }

    private var polling = false

    private func poll() async {
        guard API.shared.isLoggedIn, !polling else { return }
        polling = true
        defer { polling = false }
        do {
            let rows: [CallSignal] = try await API.shared.select("call_signals", [
                URLQueryItem(name: "receiver", value: "eq.\(API.shared.userId)"),
                URLQueryItem(name: "id", value: "gt.\(lastId)"),
                URLQueryItem(name: "order", value: "id.asc"),
                URLQueryItem(name: "limit", value: "100"),
                URLQueryItem(name: "select", value: "*")])
            if rows.isEmpty { return }
            for r in rows {
                if r.id > lastId { lastId = r.id }
                handle(r)
            }
            let ids = rows.map { String($0.id) }.joined(separator: ",")
            try? await API.shared.delete("call_signals", [URLQueryItem(name: "id", value: "in.(\(ids))")])
        } catch {}
    }

    private func sendSignal(_ call: String, _ peer: String, _ type: String, _ payload: [String: Any]? = nil,
                            onFail: (@MainActor () -> Void)? = nil) {
        let prev = sendChain
        sendChain = Task { @MainActor in
            await prev?.value
            var row: [String: Any] = ["call_id": call, "receiver": peer, "type": type]
            if let payload = payload { row["payload"] = payload }
            do { try await API.shared.insert("call_signals", row) } catch { onFail?() }
        }
    }

    private func send(_ type: String, _ payload: [String: Any]? = nil) {
        guard let p = peerId else { return }
        sendSignal(callId, p, type, payload)
    }

    private func handle(_ r: CallSignal) {
        if r.type == "invite" {
            if Date().timeIntervalSince(r.createdAt) > 40 { return }
            if state != .idle {
                if r.callId != callId { sendSignal(r.callId, r.sender, "decline") }
                return
            }
            callId = r.callId
            peerId = r.sender
            state = .incoming
            failed = ""
            startRing()
            timeoutTask?.cancel()
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                if !Task.isCancelled && self.state == .incoming { self.end(notify: false) }
            }
            return
        }
        guard r.callId == callId, state != .idle else { return }
        switch r.type {
        case "accept":
            if state == .outgoing {
                timeoutTask?.cancel()
                state = .connecting
                createPC()
                makeOffer()
            }
        case "offer":
            if let pc = pc, let sdp = r.payload?.sdp {
                pc.setRemoteDescription(RTCSessionDescription(type: .offer, sdp: sdp)) { _ in
                    Task { @MainActor in
                        self.remoteSet = true
                        self.flushIce()
                        self.makeAnswer()
                    }
                }
            }
        case "answer":
            if let pc = pc, let sdp = r.payload?.sdp {
                pc.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp)) { _ in
                    Task { @MainActor in
                        self.remoteSet = true
                        self.flushIce()
                    }
                }
            }
        case "ice":
            if let sdp = r.payload?.sdp {
                let c = RTCIceCandidate(sdp: sdp, sdpMLineIndex: Int32(r.payload?.idx ?? 0), sdpMid: r.payload?.mid)
                if let pc = pc, remoteSet { pc.add(c) { _ in } } else { pendingIce.append(c) }
            }
        case "end", "decline":
            end(notify: false)
        default: break
        }
    }

    // MARK: actions

    func start(peer: String) {
        guard state == .idle else { return }
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            Task { @MainActor in
                if !ok {
                    self.failed = tr("Нет доступа к микрофону", "No access to the microphone", "Kein Zugriff auf das Mikrofon")
                    return
                }
                guard self.state == .idle else { return }
                self.callId = UUID().uuidString.lowercased()
                self.peerId = peer
                self.state = .outgoing
                self.failed = ""
                self.muted = false
                self.speaker = false
                let mine = self.callId
                self.sendSignal(mine, peer, "invite", onFail: {
                    if self.callId == mine && self.state == .outgoing {
                        self.end(notify: false, message: tr("Не удалось позвонить", "Could not place the call", "Anruf fehlgeschlagen"))
                    }
                })
                self.timeoutTask?.cancel()
                self.timeoutTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 45_000_000_000)
                    if !Task.isCancelled && self.state == .outgoing {
                        self.end(notify: true, message: tr("Нет ответа", "No answer", "Keine Antwort"))
                    }
                }
            }
        }
    }

    func accept() {
        guard state == .incoming else { return }
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            Task { @MainActor in
                guard self.state == .incoming else { return }
                if !ok { self.decline(); return }
                self.stopRing()
                self.timeoutTask?.cancel()
                self.state = .connecting
                self.createPC()
                self.send("accept")
                self.timeoutTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if !Task.isCancelled && self.state == .connecting {
                        self.end(notify: true, message: tr("Нет соединения", "Connection failed", "Keine Verbindung"))
                    }
                }
            }
        }
    }

    func decline() {
        guard state == .incoming else { return }
        end(notify: true, decline: true)
    }

    func hangUp() { if state != .idle { end(notify: true) } }

    func toggleMute() {
        muted.toggle()
        track?.isEnabled = !muted
    }

    func toggleSpeaker() {
        speaker.toggle()
        applySpeaker()
    }

    func reset() {
        if state != .idle { end(notify: true) }
        pollTimer?.invalidate()
        pollTimer = nil
        lastId = -1
    }

    // MARK: webrtc

    private func applySpeaker() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(speaker ? .speaker : .none)
    }

    private func createPC() {
        if factory == nil { factory = RTCPeerConnectionFactory() }
        guard let f = factory else { return }
        remoteSet = false
        pendingIce = []
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
        try? s.setActive(true)
        let cfg = RTCConfiguration()
        cfg.iceServers = servers
        cfg.sdpSemantics = .unifiedPlan
        delegate.onCandidate = { [weak self] c in
            Task { @MainActor in
                self?.send("ice", ["sdp": c.sdp, "mid": c.sdpMid ?? "", "idx": Int(c.sdpMLineIndex)])
            }
        }
        delegate.onState = { [weak self] st in
            Task { @MainActor in
                guard let self = self else { return }
                switch st {
                case .connected, .completed:
                    if self.state == .connecting {
                        self.timeoutTask?.cancel()
                        self.state = .active
                        self.seconds = 0
                        self.secTimer?.invalidate()
                        self.secTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                            Task { @MainActor in Calls.shared.seconds += 1 }
                        }
                    }
                case .failed:
                    self.end(notify: true, message: tr("Нет соединения", "Connection failed", "Keine Verbindung"))
                default: break
                }
            }
        }
        let cons = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let conn = f.peerConnection(with: cfg, constraints: cons, delegate: delegate) else {
            end(notify: true, message: tr("Не удалось начать звонок", "Could not start the call", "Anruf konnte nicht gestartet werden"))
            return
        }
        pc = conn
        let src = f.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let t = f.audioTrack(with: src, trackId: "a0")
        t.isEnabled = !muted
        track = t
        conn.add(t, streamIds: ["s0"])
        applySpeaker()
    }

    private func makeOffer() {
        guard let c = pc else { return }
        let cons = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil)
        c.offer(for: cons) { sdp, _ in
            guard let sdp = sdp else { return }
            c.setLocalDescription(sdp) { _ in }
            Task { @MainActor in self.send("offer", ["sdp": sdp.sdp]) }
        }
    }

    private func makeAnswer() {
        guard let c = pc else { return }
        let cons = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true"], optionalConstraints: nil)
        c.answer(for: cons) { sdp, _ in
            guard let sdp = sdp else { return }
            c.setLocalDescription(sdp) { _ in }
            Task { @MainActor in self.send("answer", ["sdp": sdp.sdp]) }
        }
    }

    private func flushIce() {
        guard let c = pc else { return }
        for i in pendingIce { c.add(i) { _ in } }
        pendingIce = []
    }

    private func end(notify: Bool, message: String = "", decline: Bool = false) {
        if notify, let p = peerId, state != .idle { sendSignal(callId, p, decline ? "decline" : "end") }
        stopRing()
        timeoutTask?.cancel()
        secTimer?.invalidate()
        secTimer = nil
        pc?.close()
        pc = nil
        track = nil
        pendingIce = []
        remoteSet = false
        let s = AVAudioSession.sharedInstance()
        try? s.overrideOutputAudioPort(.none)
        try? s.setActive(false, options: .notifyOthersOnDeactivation)
        state = .idle
        peerId = nil
        seconds = 0
        failed = message
    }

    private func startRing() {
        ringTimer?.invalidate()
        let fire = { AudioServicesPlaySystemSound(1005); AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        fire()
        ringTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in fire() }
    }

    private func stopRing() {
        ringTimer?.invalidate()
        ringTimer = nil
    }
}

struct CallView: View {
    @ObservedObject private var calls = Calls.shared
    @ObservedObject private var store = Store.shared

    private var peer: Profile? { calls.peerId.flatMap { store.profiles[$0] } }

    private var status: String {
        switch calls.state {
        case .outgoing: return tr("Вызов…", "Calling…", "Anruf…")
        case .incoming: return tr("Входящий звонок", "Incoming call", "Eingehender Anruf")
        case .connecting: return tr("Соединение…", "Connecting…", "Verbindung…")
        case .active: return String(format: "%02d:%02d", calls.seconds / 60, calls.seconds % 60)
        case .idle: return ""
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 8) {
                Spacer().frame(height: 60)
                Avatar(nick: peer?.nick ?? "?", url: peer?.avatarUrl, size: 120)
                Text(peer?.nick ?? "").font(.system(size: 26, weight: .semibold)).foregroundColor(Theme.text).padding(.top, 14)
                Text(status).font(.system(size: 17)).foregroundColor(Theme.textSecondary)
                Spacer()
                if calls.state == .incoming {
                    HStack {
                        Spacer()
                        round("phone.down.fill", Color(red: 0.9, green: 0.28, blue: 0.3)) { calls.decline() }
                        Spacer()
                        round("phone.fill", Color(red: 0.19, green: 0.64, blue: 0.42)) { calls.accept() }
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        round(calls.muted ? "mic.slash.fill" : "mic.fill", calls.muted ? Theme.accent : Color.white.opacity(0.18)) { calls.toggleMute() }
                        Spacer()
                        round("phone.down.fill", Color(red: 0.9, green: 0.28, blue: 0.3)) { calls.hangUp() }
                        Spacer()
                        round("speaker.wave.2.fill", calls.speaker ? Theme.accent : Color.white.opacity(0.18)) { calls.toggleSpeaker() }
                        Spacer()
                    }
                }
                Spacer().frame(height: 50)
            }
        }
    }

    private func round(_ icon: String, _ bg: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 26)).foregroundColor(.white)
                .frame(width: 70, height: 70).background(bg).clipShape(Circle())
        }
    }
}
