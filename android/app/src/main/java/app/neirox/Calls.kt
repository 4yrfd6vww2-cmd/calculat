package app.neirox

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import org.webrtc.AudioSource
import org.webrtc.AudioTrack
import org.webrtc.Camera2Enumerator
import org.webrtc.CameraVideoCapturer
import org.webrtc.DefaultVideoDecoderFactory
import org.webrtc.DefaultVideoEncoderFactory
import org.webrtc.EglBase
import org.webrtc.RtpReceiver
import org.webrtc.SurfaceTextureHelper
import org.webrtc.SurfaceViewRenderer
import org.webrtc.VideoSource
import org.webrtc.VideoTrack
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import org.webrtc.IceCandidate
import org.webrtc.MediaConstraints
import org.webrtc.MediaStream
import org.webrtc.PeerConnection
import org.webrtc.PeerConnectionFactory
import org.webrtc.SdpObserver
import org.webrtc.SessionDescription
import org.webrtc.audio.JavaAudioDeviceModule
import java.time.Duration
import java.time.OffsetDateTime
import java.util.UUID

enum class CallState { IDLE, OUTGOING, INCOMING, CONNECTING, ACTIVE }

private open class SdpObs : SdpObserver {
    override fun onCreateSuccess(d: SessionDescription?) {}
    override fun onSetSuccess() {}
    override fun onCreateFailure(e: String?) {}
    override fun onSetFailure(e: String?) {}
}

object Calls {
    var state by mutableStateOf(CallState.IDLE)
        private set
    var peerId by mutableStateOf<String?>(null)
        private set
    var muted by mutableStateOf(false)
        private set
    var speaker by mutableStateOf(false)
        private set
    var seconds by mutableIntStateOf(0)
        private set
    var failed by mutableStateOf("")
        private set
    var video by mutableStateOf(false)
        private set
    var camOff by mutableStateOf(false)
        private set
    var remoteVideo by mutableStateOf<VideoTrack?>(null)
        private set
    var localVideo by mutableStateOf<VideoTrack?>(null)
        private set
    var egl: EglBase? = null
        private set
    private var capturer: CameraVideoCapturer? = null
    private var vSource: VideoSource? = null
    private var vHelper: SurfaceTextureHelper? = null

    private lateinit var ctx: Context
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val sendLock = Mutex()
    private var started = false
    private var lastId = -1L
    private var callId = ""
    private var factory: PeerConnectionFactory? = null
    private var pc: PeerConnection? = null
    private var source: AudioSource? = null
    private var track: AudioTrack? = null
    private val pendingIce = mutableListOf<IceCandidate>()
    private var remoteSet = false
    private var ringtone: Ringtone? = null
    private var timeoutJob: Job? = null
    private var timerJob: Job? = null

    private val servers = listOf(
        PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
        PeerConnection.IceServer.builder("stun:stun1.l.google.com:19302").createIceServer(),
        PeerConnection.IceServer.builder("turn:openrelay.metered.ca:80")
            .setUsername("openrelayproject").setPassword("openrelayproject").createIceServer(),
        PeerConnection.IceServer.builder("turn:openrelay.metered.ca:443")
            .setUsername("openrelayproject").setPassword("openrelayproject").createIceServer(),
        PeerConnection.IceServer.builder("turn:openrelay.metered.ca:443?transport=tcp")
            .setUsername("openrelayproject").setPassword("openrelayproject").createIceServer()
    )

    fun init(c: Context) {
        if (started) return
        started = true
        ctx = c.applicationContext
        scope.launch {
            while (isActive) {
                if (Store.loggedIn) {
                    try { poll() } catch (e: Exception) { }
                }
                delay(if (state == CallState.IDLE) 1500 else 700)
            }
        }
    }

    fun hasMic(c: Context) =
        ContextCompat.checkSelfPermission(c, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    // ---------- signaling ----------

    private suspend fun poll() {
        val uid = Store.myId
        val arr = Api.select("call_signals?receiver=eq.$uid&id=gt.$lastId&order=id.asc&limit=100")
        if (arr.length() == 0) return
        val ids = ArrayList<Long>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val id = o.getLong("id")
            ids.add(id)
            if (id > lastId) lastId = id
            try { handle(o) } catch (e: Exception) { }
        }
        try { Api.delete("call_signals?id=in.(${ids.joinToString(",")})") } catch (e: Exception) { }
    }

    private fun sendSignal(call: String, peer: String, type: String, payload: JSONObject? = null, onFail: (() -> Unit)? = null) {
        scope.launch {
            sendLock.withLock {
                try {
                    val row = JSONObject().put("call_id", call).put("receiver", peer).put("type", type)
                    if (payload != null) row.put("payload", payload)
                    Api.insert("call_signals", row)
                } catch (e: Exception) {
                    onFail?.invoke()
                }
            }
        }
    }

    private fun send(type: String, payload: JSONObject? = null) {
        val p = peerId ?: return
        sendSignal(callId, p, type, payload)
    }

    private fun handle(o: JSONObject) {
        val type = o.getString("type")
        val call = o.getString("call_id")
        val sender = o.getString("sender")
        val payload = o.optJSONObject("payload")
        if (type == "invite") {
            val age = try {
                Duration.between(OffsetDateTime.parse(o.getString("created_at")), OffsetDateTime.now()).seconds
            } catch (e: Exception) { 0L }
            if (age > 40) return
            if (state != CallState.IDLE) {
                if (call != callId) sendSignal(call, sender, "decline")
                return
            }
            callId = call
            peerId = sender
            video = payload?.optBoolean("video") == true
            camOff = false
            state = CallState.INCOMING
            failed = ""
            startRing()
            if (!Store.appVisible) Notif.incomingCall(ctx, Store.profiles[sender]?.let { Store.dname(it) } ?: "neirox")
            timeoutJob?.cancel()
            timeoutJob = scope.launch { delay(45_000); if (state == CallState.INCOMING) end(false) }
            return
        }
        if (call != callId || state == CallState.IDLE) return
        when (type) {
            "accept" -> if (state == CallState.OUTGOING) {
                timeoutJob?.cancel()
                state = CallState.CONNECTING
                createPc()
                makeOffer()
            }
            "offer" -> if (pc != null && payload != null) {
                pc?.setRemoteDescription(object : SdpObs() {
                    override fun onSetSuccess() {
                        scope.launch {
                            remoteSet = true
                            flushIce()
                            makeAnswer()
                        }
                    }
                }, SessionDescription(SessionDescription.Type.OFFER, payload.getString("sdp")))
            }
            "answer" -> if (pc != null && payload != null) {
                pc?.setRemoteDescription(object : SdpObs() {
                    override fun onSetSuccess() {
                        scope.launch { remoteSet = true; flushIce() }
                    }
                }, SessionDescription(SessionDescription.Type.ANSWER, payload.getString("sdp")))
            }
            "ice" -> if (payload != null) {
                val c = IceCandidate(payload.optString("mid"), payload.optInt("idx"), payload.getString("sdp"))
                if (pc != null && remoteSet) pc?.addIceCandidate(c) else pendingIce.add(c)
            }
            "end", "decline" -> end(false)
        }
    }

    // ---------- public actions ----------

    fun hasCam(c: Context) =
        ContextCompat.checkSelfPermission(c, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    fun start(peer: String, withVideo: Boolean = false) {
        if (state != CallState.IDLE) return
        video = withVideo
        camOff = false
        callId = UUID.randomUUID().toString()
        peerId = peer
        state = CallState.OUTGOING
        failed = ""
        muted = false
        speaker = false
        val mine = callId
        sendSignal(mine, peer, "invite", if (withVideo) JSONObject().put("video", true) else null, onFail = {
            if (callId == mine && state == CallState.OUTGOING) end(false, tr("Не удалось позвонить", "Could not place the call", "Anruf fehlgeschlagen"))
        })
        timeoutJob?.cancel()
        timeoutJob = scope.launch { delay(45_000); if (state == CallState.OUTGOING) end(true, tr("Нет ответа", "No answer", "Keine Antwort")) }
    }

    fun accept() {
        if (state != CallState.INCOMING) return
        stopRing()
        Notif.cancelCall(ctx)
        timeoutJob?.cancel()
        state = CallState.CONNECTING
        createPc()
        send("accept")
        timeoutJob = scope.launch { delay(30_000); if (state == CallState.CONNECTING) end(true, tr("Нет соединения", "Connection failed", "Keine Verbindung")) }
    }

    fun decline() {
        if (state != CallState.INCOMING) return
        end(true, decline = true)
    }

    fun hangUp() {
        if (state != CallState.IDLE) end(true)
    }

    fun toggleMute() {
        muted = !muted
        track?.setEnabled(!muted)
    }

    fun toggleCam() {
        camOff = !camOff
        localVideo?.setEnabled(!camOff)
    }

    fun switchCam() {
        try { capturer?.switchCamera(null) } catch (e: Exception) { }
    }

    fun toggleSpeaker() {
        speaker = !speaker
        applySpeaker()
    }

    // ---------- webrtc ----------

    private fun ensureFactory(): PeerConnectionFactory {
        factory?.let { return it }
        PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(ctx).createInitializationOptions())
        val adm = JavaAudioDeviceModule.builder(ctx).createAudioDeviceModule()
        val e = egl ?: EglBase.create().also { egl = it }
        val f = PeerConnectionFactory.builder().setAudioDeviceModule(adm)
            .setVideoEncoderFactory(DefaultVideoEncoderFactory(e.eglBaseContext, true, true))
            .setVideoDecoderFactory(DefaultVideoDecoderFactory(e.eglBaseContext))
            .createPeerConnectionFactory()
        factory = f
        return f
    }

    private fun audio() = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    @Suppress("DEPRECATION")
    private fun applySpeaker() {
        audio().isSpeakerphoneOn = speaker
    }

    private fun createPc() {
        val f = ensureFactory()
        remoteSet = false
        pendingIce.clear()
        val cfg = PeerConnection.RTCConfiguration(servers)
        cfg.sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
        val obs = object : PeerConnection.Observer {
            override fun onSignalingChange(s: PeerConnection.SignalingState?) {}
            override fun onIceConnectionChange(s: PeerConnection.IceConnectionState?) {
                scope.launch {
                    when (s) {
                        PeerConnection.IceConnectionState.CONNECTED, PeerConnection.IceConnectionState.COMPLETED -> {
                            if (state == CallState.CONNECTING) {
                                timeoutJob?.cancel()
                                state = CallState.ACTIVE
                                seconds = 0
                                timerJob?.cancel()
                                timerJob = scope.launch { while (isActive) { delay(1000); seconds++ } }
                            }
                        }
                        PeerConnection.IceConnectionState.FAILED ->
                            end(true, tr("Нет соединения", "Connection failed", "Keine Verbindung"))
                        else -> {}
                    }
                }
            }
            override fun onIceConnectionReceivingChange(b: Boolean) {}
            override fun onIceGatheringChange(s: PeerConnection.IceGatheringState?) {}
            override fun onIceCandidate(c: IceCandidate?) {
                if (c == null) return
                scope.launch {
                    send("ice", JSONObject().put("sdp", c.sdp).put("mid", c.sdpMid ?: "").put("idx", c.sdpMLineIndex))
                }
            }
            override fun onIceCandidatesRemoved(a: Array<out IceCandidate>?) {}
            override fun onAddTrack(r: RtpReceiver?, s: Array<out MediaStream>?) {
                val t = r?.track()
                if (t is VideoTrack) scope.launch { remoteVideo = t }
            }
            override fun onAddStream(s: MediaStream?) {}
            override fun onRemoveStream(s: MediaStream?) {}
            override fun onDataChannel(d: org.webrtc.DataChannel?) {}
            override fun onRenegotiationNeeded() {}
        }
        val conn = f.createPeerConnection(cfg, obs)
        if (conn == null) {
            end(true, tr("Не удалось начать звонок", "Could not start the call", "Anruf konnte nicht gestartet werden"))
            return
        }
        pc = conn
        source = f.createAudioSource(MediaConstraints())
        track = f.createAudioTrack("a0", source)
        track?.setEnabled(!muted)
        conn.addTrack(track, listOf("s0"))
        if (video && hasCam(ctx)) startCamera(f, conn)
        val am = audio()
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        applySpeaker()
    }

    private fun startCamera(f: PeerConnectionFactory, conn: PeerConnection) {
        try {
            val en = Camera2Enumerator(ctx)
            val name = en.deviceNames.firstOrNull { en.isFrontFacing(it) } ?: en.deviceNames.firstOrNull() ?: return
            val cap = en.createCapturer(name, null) ?: return
            val helper = SurfaceTextureHelper.create("cam", egl!!.eglBaseContext)
            val src = f.createVideoSource(false)
            cap.initialize(helper, ctx, src.capturerObserver)
            cap.startCapture(640, 480, 24)
            val vt = f.createVideoTrack("v0", src)
            vt.setEnabled(!camOff)
            conn.addTrack(vt, listOf("s0"))
            capturer = cap; vSource = src; vHelper = helper
            localVideo = vt
        } catch (e: Exception) { }
    }

    private fun makeOffer() {
        val c = pc ?: return
        c.createOffer(object : SdpObs() {
            override fun onCreateSuccess(d: SessionDescription?) {
                if (d == null) return
                c.setLocalDescription(SdpObs(), d)
                scope.launch { send("offer", JSONObject().put("sdp", d.description)) }
            }
        }, MediaConstraints())
    }

    private fun makeAnswer() {
        val c = pc ?: return
        c.createAnswer(object : SdpObs() {
            override fun onCreateSuccess(d: SessionDescription?) {
                if (d == null) return
                c.setLocalDescription(SdpObs(), d)
                scope.launch { send("answer", JSONObject().put("sdp", d.description)) }
            }
        }, MediaConstraints())
    }

    private fun flushIce() {
        val c = pc ?: return
        for (i in pendingIce) c.addIceCandidate(i)
        pendingIce.clear()
    }

    private fun end(notify: Boolean, message: String = "", decline: Boolean = false) {
        val peer = peerId
        val call = callId
        if (!notify && state == CallState.INCOMING && !Store.appVisible) {
            Notif.message(ctx, "missed", Store.profiles[peer ?: ""]?.let { Store.dname(it) } ?: "neirox", tr("Пропущенный звонок", "Missed call", "Verpasster Anruf"))
        }
        Notif.cancelCall(ctx)
        if (notify && peer != null && state != CallState.IDLE) sendSignal(call, peer, if (decline) "decline" else "end")
        stopRing()
        timeoutJob?.cancel()
        timerJob?.cancel()
        try { pc?.close() } catch (e: Exception) { }
        try { pc?.dispose() } catch (e: Exception) { }
        try { source?.dispose() } catch (e: Exception) { }
        try { track?.dispose() } catch (e: Exception) { }
        try { capturer?.stopCapture() } catch (e: Exception) { }
        try { capturer?.dispose() } catch (e: Exception) { }
        try { vSource?.dispose() } catch (e: Exception) { }
        try { vHelper?.dispose() } catch (e: Exception) { }
        capturer = null; vSource = null; vHelper = null
        remoteVideo = null; localVideo = null
        video = false; camOff = false
        pc = null; source = null; track = null
        pendingIce.clear()
        remoteSet = false
        try {
            val am = audio()
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn = false
            am.mode = AudioManager.MODE_NORMAL
        } catch (e: Exception) { }
        state = CallState.IDLE
        peerId = null
        seconds = 0
        failed = message
    }

    private fun startRing() {
        try {
            val r = RingtoneManager.getRingtone(ctx, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))
            if (Build.VERSION.SDK_INT >= 28) r.isLooping = true
            r.play()
            ringtone = r
        } catch (e: Exception) { }
    }

    private fun stopRing() {
        try { ringtone?.stop() } catch (e: Exception) { }
        ringtone = null
    }

    fun clearFailed() { failed = "" }

    fun reset() {
        if (state != CallState.IDLE) end(true)
        lastId = -1L
    }
}

@Composable
fun CallScreen() {
    val ctx = LocalContext.current
    val peer = Calls.peerId?.let { Store.profiles[it] }
    val st = Calls.state
    val perm = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        if (res[Manifest.permission.RECORD_AUDIO] == true) Calls.accept() else Calls.decline()
    }
    val status = when (st) {
        CallState.OUTGOING -> tr("Вызов…", "Calling…", "Anruf…")
        CallState.INCOMING -> tr("Входящий звонок", "Incoming call", "Eingehender Anruf")
        CallState.CONNECTING -> tr("Соединение…", "Connecting…", "Verbindung…")
        CallState.ACTIVE -> "%02d:%02d".format(Calls.seconds / 60, Calls.seconds % 60)
        else -> ""
    }
    Box(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(BgTop, BgBottom)))
            .clickable(enabled = false) { }
    ) {
        val rv = Calls.remoteVideo
        if (rv != null && Calls.egl != null) VideoView(rv, Modifier.fillMaxSize(), false)
        val lv = Calls.localVideo
        if (lv != null && Calls.egl != null && !Calls.camOff) {
            Box(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(12.dp).size(width = 100.dp, height = 140.dp).clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))) {
                VideoView(lv, Modifier.fillMaxSize(), true)
            }
        }
        Column(
            Modifier.fillMaxSize().statusBarsPadding().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(if (rv != null) 20.dp else 80.dp))
            if (rv == null) Avatar(peer, 120.dp)
            Spacer(Modifier.height(20.dp))
            Text(Store.dname(peer), color = Txt, fontSize = 26.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            Text(status, color = TextSecondary, fontSize = 17.sp)
            Box(Modifier.weight(1f))
            if (st == CallState.INCOMING) {
                Row(Modifier.fillMaxWidth().padding(bottom = 48.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    CallBtn("📵", Color(0xFFE5484D)) { Calls.decline() }
                    CallBtn("📞", Color(0xFF30A46C)) {
                        val need = if (Calls.video) arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA) else arrayOf(Manifest.permission.RECORD_AUDIO)
                        if (Calls.hasMic(ctx) && (!Calls.video || Calls.hasCam(ctx))) Calls.accept() else perm.launch(need)
                    }
                }
            } else {
                Row(Modifier.fillMaxWidth().padding(bottom = 48.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    CallBtn(if (Calls.muted) "🔇" else "🎤", if (Calls.muted) Accent else Color.White.copy(alpha = 0.18f)) { Calls.toggleMute() }
                    CallBtn("📵", Color(0xFFE5484D)) { Calls.hangUp() }
                    if (Calls.video) {
                        CallBtn(if (Calls.camOff) "🚫" else "📷", if (Calls.camOff) Accent else Color.White.copy(alpha = 0.18f)) { Calls.toggleCam() }
                        CallBtn("🔄", Color.White.copy(alpha = 0.18f)) { Calls.switchCam() }
                    }
                    CallBtn("🔊", if (Calls.speaker) Accent else Color.White.copy(alpha = 0.18f)) { Calls.toggleSpeaker() }
                }
            }
        }
    }
}

@Composable
private fun CallBtn(icon: String, bg: Color, onClick: () -> Unit) {
    Box(
        Modifier.size(70.dp).clip(CircleShape).background(bg).clickable { onClick() },
        contentAlignment = Alignment.Center
    ) { Text(icon, fontSize = 28.sp) }
}

@Composable
private fun VideoView(track: VideoTrack, modifier: Modifier, mirror: Boolean) {
    val egl = Calls.egl ?: return
    val holder = remember { arrayOfNulls<SurfaceViewRenderer>(1) }
    AndroidView(
        modifier = modifier,
        factory = { c ->
            SurfaceViewRenderer(c).also {
                it.init(egl.eglBaseContext, null)
                it.setMirror(mirror)
                it.setScalingType(org.webrtc.RendererCommon.ScalingType.SCALE_ASPECT_FILL)
                if (mirror) it.setZOrderMediaOverlay(true)
                track.addSink(it)
                holder[0] = it
            }
        }
    )
    DisposableEffect(track) {
        onDispose {
            holder[0]?.let { r ->
                try { track.removeSink(r) } catch (e: Exception) { }
                try { r.release() } catch (e: Exception) { }
            }
        }
    }
}
