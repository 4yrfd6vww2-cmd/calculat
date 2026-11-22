package app.neirox

import android.Manifest
import android.content.ClipData
import android.content.pm.PackageManager
import androidx.activity.result.PickVisualMediaRequest
import androidx.compose.runtime.DisposableEffect
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import android.net.Uri
import android.view.HapticFeedbackConstants
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

private const val MAX_FILE = 50 * 1024 * 1024

private class ChatRow(val key: String, val title: String, val profile: Profile?, val chat: Chat?)

@Composable
fun ChatsTab(onOpen: (String) -> Unit, onAI: () -> Unit) {
    val rows = ArrayList<ChatRow>()
    for (id in Store.friendIds) Store.profiles[id]?.let { rows.add(ChatRow(it.id, it.nick, it, null)) }
    for (c in Store.chats) rows.add(ChatRow("c:" + c.id, c.title, null, c))
    val lastOf = { k: String -> Store.thread(k).lastOrNull() }
    val sorted = rows.sortedByDescending { lastOf(it.key)?.createdAt ?: "" }
    var showCreate by remember { mutableStateOf(false) }
    var showFind by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize()) {
        ScreenTitle(tr("Чаты", "Chats", "Chats"))
        LazyColumn(Modifier.fillMaxSize()) {
            item {
                Row(
                    Modifier.fillMaxWidth().clickable { onAI() }.padding(horizontal = 20.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        Modifier.size(48.dp).clip(CircleShape)
                            .background(Brush.linearGradient(listOf(Accent, Accent2))),
                        contentAlignment = Alignment.Center
                    ) { Text("✨", fontSize = 22.sp) }
                    Column(Modifier.padding(start = 14.dp)) {
                        Text(tr("Умный Чат", "Smart Chat", "Smarter Chat"), color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                        Text(
                            tr("Вопросы и картинки от ИИ", "Questions and images from AI", "Fragen und Bilder von der KI"),
                            color = TextSecondary, fontSize = 13.sp
                        )
                    }
                }
            }
            item {
                Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp)) {
                    Text(
                        "＋ " + tr("Группа / канал", "Group / channel", "Gruppe / Kanal"), color = Accent, fontSize = 14.sp,
                        modifier = Modifier.clickable { showCreate = true }.padding(vertical = 8.dp, horizontal = 4.dp)
                    )
                    Text(
                        "🔍 " + tr("Найти канал", "Find channel", "Kanal suchen"), color = Accent, fontSize = 14.sp,
                        modifier = Modifier.padding(start = 16.dp).clickable { showFind = true }.padding(vertical = 8.dp, horizontal = 4.dp)
                    )
                }
            }
            items(sorted, key = { it.key }) { r ->
                val last = lastOf(r.key)
                val unread = Store.unread(r.key)
                Row(
                    Modifier.fillMaxWidth().clickable { onOpen(r.key) }.padding(horizontal = 20.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (r.profile != null) Avatar(r.profile, 48.dp)
                    else if (r.chat != null) Avatar(r.chat.asProfile(), 48.dp)
                    Column(Modifier.padding(start = 14.dp).weight(1f)) {
                        Text(r.title, color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val who = if (r.chat != null && last != null && last.sender != Store.myId) (Store.profiles[last.sender]?.nick ?: "") + ": " else ""
                        Text(who + previewOf(last), color = TextSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    if (unread > 0) {
                        Box(
                            Modifier.clip(CircleShape).background(Accent).padding(horizontal = 8.dp, vertical = 3.dp),
                            contentAlignment = Alignment.Center
                        ) { Text("$unread", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                    }
                }
            }
            if (sorted.isEmpty()) {
                item {
                    Text(
                        tr("Добавь друзей во вкладке «Друзья», и здесь появятся чаты.",
                            "Add friends in the Friends tab and chats will appear here.",
                            "Füge Freunde im Tab „Freunde“ hinzu, dann erscheinen hier Chats."),
                        color = TextSecondary, fontSize = 14.sp, modifier = Modifier.padding(24.dp)
                    )
                }
            }
        }
    }
    if (showCreate) CreateChatDialog({ showCreate = false }) { showCreate = false; onOpen(it) }
    if (showFind) FindChannelDialog({ showFind = false }) { showFind = false; onOpen(it) }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatScreen(friendId: String, onBack: () -> Unit, onForwardToAI: (String) -> Unit) {
    val friend = Store.profiles[friendId]
    val chat = Store.chatByKey(friendId)
    val thread = Store.thread(friendId)
    var replyTo by remember { mutableStateOf<Message?>(null) }
    var showInfo by remember { mutableStateOf(false) }
    val ctx = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    var input by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var menu by remember { mutableStateOf(false) }
    var showAI by remember { mutableStateOf(false) }
    var aiPrompt by remember { mutableStateOf("") }
    var fullscreen by remember { mutableStateOf<String?>(null) }
    var selected by remember { mutableStateOf<Set<Long>>(emptySet()) }
    var editing by remember { mutableStateOf<Message?>(null) }
    var showForward by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    var menuSingle by remember { mutableStateOf(false) }
    var showEmoji by remember { mutableStateOf(false) }
    val pending = remember { mutableStateListOf<PendingItem>() }
    var video by remember { mutableStateOf<String?>(null) }
    var recording by remember { mutableStateOf(false) }
    var recSecs by remember { mutableStateOf(0) }
    val recorder = remember { VoiceRecorder(ctx) }
    DisposableEffect(Unit) { onDispose { recorder.cancel() } }
    LaunchedEffect(recording) {
        if (recording) {
            val t0 = System.currentTimeMillis()
            while (true) {
                recSecs = ((System.currentTimeMillis() - t0) / 1000).toInt()
                delay(250)
            }
        }
    }

    val selMsgs = thread.filter { it.id in selected }

    BackHandler(enabled = selected.isNotEmpty() || editing != null) {
        if (selected.isNotEmpty()) {
            selected = emptySet()
        } else {
            editing = null
            input = ""
        }
    }

    LaunchedEffect(thread.size) {
        if (thread.isNotEmpty()) listState.scrollToItem(thread.size - 1)
    }
    LaunchedEffect(input) {
        if (input.isNotBlank()) Store.sendTyping(friendId)
    }
    LaunchedEffect(Store.unread(friendId)) {
        if (Store.unread(friendId) > 0) {
            try { Store.markRead(friendId) } catch (e: Exception) { }
        }
    }

    fun buzz() {
        if (Settings.haptics) view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }

    fun toast(text: String) {
        Toast.makeText(ctx, text, Toast.LENGTH_SHORT).show()
    }

    fun addUris(uris: List<Uri>, forceFile: Boolean) {
        for (u in uris) {
            if (pending.size >= 20) {
                error = tr("Не больше 20 вложений в одном сообщении", "Up to 20 attachments per message", "Höchstens 20 Anhänge pro Nachricht")
                break
            }
            val mime = ctx.contentResolver.getType(u) ?: ""
            val kind = when {
                forceFile -> "file"
                mime.startsWith("image/") -> "image"
                mime.startsWith("video/") -> "video"
                else -> "file"
            }
            pending.add(PendingItem(u, displayName(ctx, u), kind, mime.ifEmpty { "application/octet-stream" }))
        }
    }

    fun sendPending(caption: String) {
        val list = pending.toList()
        busy = true
        error = ""
        scope.launch {
            try {
                val out = withContext(Dispatchers.IO) {
                    list.map { p ->
                        if (p.kind == "image") {
                            val jpg = compressImage(ctx, p.uri)
                                ?: throw ApiError(tr("Не удалось прочитать фото", "Could not read the photo", "Foto konnte nicht gelesen werden"))
                            Store.OutItem(jpg, "image/jpeg", "photo.jpg", "image")
                        } else {
                            val bytes = ctx.contentResolver.openInputStream(p.uri)?.use { it.readBytes() }
                                ?: throw ApiError(tr("Не удалось прочитать файл", "Could not read the file", "Datei konnte nicht gelesen werden"))
                            if (bytes.size > MAX_FILE) {
                                throw ApiError(tr("Файл больше 50 МБ", "File is larger than 50 MB", "Datei ist größer als 50 MB"))
                            }
                            Store.OutItem(bytes, p.mime, p.name, p.kind)
                        }
                    }
                }
                Store.sendAlbum(out, caption, friendId, replyTo?.id)
                replyTo = null
                pending.clear()
                buzz()
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
                if (input.isEmpty()) input = caption
            }
            busy = false
        }
    }

    val mediaPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(20)) { uris ->
        addUris(uris, false)
    }
    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        addUris(uris, true)
    }

    fun startRecording() {
        if (recorder.start()) {
            recSecs = 0
            recording = true
        } else {
            error = tr("Не удалось начать запись", "Could not start recording", "Aufnahme konnte nicht gestartet werden")
        }
    }

    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) startRecording()
        else error = tr("Нет доступа к микрофону", "No access to the microphone", "Kein Zugriff auf das Mikrofon")
    }

    val callPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) Calls.start(friendId)
        else error = tr("Нет доступа к микрофону", "No access to the microphone", "Kein Zugriff auf das Mikrofon")
    }

    val vcallPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { res ->
        if (res[Manifest.permission.RECORD_AUDIO] == true) Calls.start(friendId, res[Manifest.permission.CAMERA] == true)
        else error = tr("Нет доступа к микрофону", "No access to the microphone", "Kein Zugriff auf das Mikrofon")
    }

    fun callClick() {
        if (Calls.hasMic(ctx)) Calls.start(friendId) else callPermission.launch(Manifest.permission.RECORD_AUDIO)
    }

    fun videoCallClick() {
        if (Calls.hasMic(ctx) && Calls.hasCam(ctx)) Calls.start(friendId, true)
        else vcallPermission.launch(arrayOf(Manifest.permission.RECORD_AUDIO, Manifest.permission.CAMERA))
    }

    fun micClick() {
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) startRecording()
        else micPermission.launch(Manifest.permission.RECORD_AUDIO)
    }

    fun cancelRecording() {
        recording = false
        recorder.cancel()
    }

    fun finishRecording() {
        recording = false
        val secs = recSecs
        val f = recorder.stop()
        if (f == null || secs < 1) {
            f?.delete()
            toast(tr("Слишком короткое сообщение", "Too short", "Zu kurz"))
            return
        }
        busy = true
        error = ""
        scope.launch {
            try {
                val bytes = withContext(Dispatchers.IO) { f.readBytes() }
                Store.sendAlbum(listOf(Store.OutItem(bytes, "audio/mp4", "voice.m4a", "voice")), "", friendId, replyTo?.id)
                replyTo = null
                buzz()
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            f.delete()
            busy = false
        }
    }

    fun sendText() {
        val t = input.trim()
        if (busy) return
        val ed = editing
        if (ed == null && pending.isNotEmpty()) {
            input = ""
            buzz()
            sendPending(t)
            return
        }
        if (t.isEmpty()) return
        if (ed != null) {
            error = ""
            scope.launch {
                try {
                    if (t != (ed.body ?: "")) Store.editMessage(ed.id, t)
                    editing = null
                    input = ""
                } catch (e: Exception) {
                    error = friendlyError(e.message ?: "")
                }
            }
            return
        }
        input = ""
        error = ""
        buzz()
        val rid = replyTo?.id
        replyTo = null
        scope.launch {
            try {
                Store.sendText(t, friendId, rid)
            } catch (e: Exception) {
                input = t
                error = friendlyError(e.message ?: "")
            }
        }
    }

    fun sendAIImage() {
        val p = aiPrompt.trim()
        if (p.isEmpty()) return
        aiPrompt = ""
        showAI = false
        busy = true
        error = ""
        scope.launch {
            try {
                val img = Api.aiImage(p)
                Store.sendMedia(img, "image/jpeg", "ai.jpg", "image", friendId, replyTo?.id)
                replyTo = null
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    fun copySelected() {
        val texts = selMsgs.sortedBy { it.createdAt }.mapNotNull { m ->
            when (m.kind) {
                "text" -> m.body
                "file" -> m.fileName
                "album" -> m.body ?: m.attachments.filter { it.type == "file" }.joinToString("\n") { it.name }.ifEmpty { null }
                else -> null
            }
        }
        if (texts.isEmpty()) {
            toast(tr("Нечего копировать", "Nothing to copy", "Nichts zu kopieren"))
        } else {
            val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("neirox", texts.joinToString("\n")))
            toast(tr("Скопировано", "Copied", "Kopiert"))
            selected = emptySet()
        }
    }

    fun forwardTo(to: String) {
        val list = selMsgs.sortedBy { it.createdAt }
        showForward = false
        selected = emptySet()
        menuSingle = false
        busy = true
        error = ""
        scope.launch {
            try {
                for (m in list) Store.forward(m, to)
                toast(tr("Переслано", "Forwarded", "Weitergeleitet"))
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    fun forwardToAI() {
        val text = selMsgs.sortedBy { it.createdAt }.filter { it.kind == "text" }.mapNotNull { it.body }.joinToString("\n")
        if (text.isEmpty()) {
            toast(tr("В ИИ можно переслать только текст", "Only text can be sent to AI", "An die KI kann nur Text gesendet werden"))
            return
        }
        showForward = false
        selected = emptySet()
        onForwardToAI(text)
    }

    fun deleteSelected(forAll: Boolean) {
        val list = selMsgs
        showDelete = false
        selected = emptySet()
        menuSingle = false
        scope.launch {
            try {
                if (forAll) Store.deleteForAll(list) else Store.deleteForMe(list)
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
        }
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        if (selected.isNotEmpty()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("✕", color = Txt, fontSize = 22.sp, modifier = Modifier.clickable { selected = emptySet() }.padding(12.dp))
                Text("${selected.size}", color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 18.sp, modifier = Modifier.weight(1f))
                val one = selMsgs.singleOrNull()
                if (one != null && one.sender == Store.myId && one.kind == "text") {
                    Text("✏️", fontSize = 22.sp, modifier = Modifier.clickable {
                        editing = one
                        input = one.body ?: ""
                        selected = emptySet()
                    }.padding(12.dp))
                }
                Text("📋", fontSize = 22.sp, modifier = Modifier.clickable { copySelected() }.padding(12.dp))
                Text("↪️", fontSize = 22.sp, modifier = Modifier.clickable { showForward = true }.padding(12.dp))
                Text("🗑", fontSize = 22.sp, modifier = Modifier.clickable { showDelete = true }.padding(12.dp))
            }
        } else {
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("‹", color = Accent, fontSize = 34.sp, modifier = Modifier.clickable { onBack() }.padding(horizontal = 12.dp))
                if (chat != null) Avatar(chat.asProfile(), 38.dp) else Avatar(friend, 38.dp)
                val typers = Store.typingIn(friendId)
                val sub = when {
                    typers.isNotEmpty() -> (if (chat != null) typers.joinToString(", ") { it.nick } + " " else "") + tr("печатает…", "typing…", "tippt …")
                    chat != null -> (if (chat.kind == "channel") tr("Канал", "Channel", "Kanal") else tr("Группа", "Group", "Gruppe")) + " · " + Store.memberCount(friendId)
                    else -> Store.statusLine(friend)
                }
                Column(
                    Modifier.padding(start = 10.dp).weight(1f).then(if (chat != null) Modifier.clickable { showInfo = true } else Modifier)
                ) {
                    Text(chat?.title ?: friend?.nick ?: "", color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(sub, color = if (typers.isNotEmpty() || (chat == null && Store.isOnline(friend))) Accent else TextSecondary, fontSize = 12.sp)
                }
                if (chat == null) {
                    Text("🎥", fontSize = 22.sp, modifier = Modifier.clickable { videoCallClick() }.padding(8.dp))
                    Text("📞", fontSize = 22.sp, modifier = Modifier.clickable { callClick() }.padding(8.dp))
                }
            }
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(thread, key = { it.id }) { m ->
                MessageBubble(
                    m,
                    quoted = m.replyTo?.let { rid -> thread.firstOrNull { it.id == rid } },
                    showNick = chat != null && m.sender != Store.myId,
                    reactions = Store.reactionsOf(m.id),
                    onReply = { if (Store.canPost(friendId)) replyTo = m },
                    onReact = { e -> scope.launch { try { Store.react(m.id, e) } catch (ex: Exception) { } } },
                    mine = m.sender == Store.myId,
                    selected = m.id in selected,
                    selecting = selected.isNotEmpty(),
                    onImage = { fullscreen = it },
                    onVideo = { video = it },
                    onToggle = { selected = if (m.id in selected) selected - m.id else selected + m.id },
                    onCopy = {
                        val t = when (m.kind) {
                            "text" -> m.body
                            "file" -> m.fileName
                            "album" -> m.body ?: m.attachments.filter { it.type == "file" }.joinToString("\n") { it.name }.ifEmpty { null }
                            else -> null
                        }
                        if (t == null) toast(tr("Нечего копировать", "Nothing to copy", "Nichts zu kopieren"))
                        else {
                            val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            cm.setPrimaryClip(ClipData.newPlainText("neirox", t))
                            toast(tr("Скопировано", "Copied", "Kopiert"))
                        }
                    },
                    onEdit = if (m.sender == Store.myId && m.kind == "text") ({
                        editing = m
                        input = m.body ?: ""
                    }) else null,
                    onForward = { menuSingle = true; selected = setOf(m.id); showForward = true },
                    onDelete = { menuSingle = true; selected = setOf(m.id); showDelete = true }
                )
            }
        }

        if (error.isNotEmpty()) {
            Box(Modifier.padding(horizontal = 14.dp)) { NxError(error) }
        }
        if (busy) {
            Row(Modifier.padding(start = 16.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(16.dp), color = Accent, strokeWidth = 2.dp)
                Text(tr("Отправляю…", "Sending…", "Sende …"), color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(start = 8.dp))
            }
        }
        val rt = replyTo
        if (rt != null && editing == null) {
            Row(
                Modifier.fillMaxWidth().background(CardBg).padding(horizontal = 16.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text("↩ " + (Store.profiles[rt.sender]?.nick ?: if (rt.sender == Store.myId) tr("Вы", "You", "Du") else ""), color = Accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Text(previewOf(rt), color = TextSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Text("✕", color = TextSecondary, fontSize = 18.sp, modifier = Modifier.clickable { replyTo = null }.padding(6.dp))
            }
        }
        if (editing != null) {
            Row(
                Modifier.fillMaxWidth().background(CardBg).padding(horizontal = 16.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("✏️ " + tr("Редактирование", "Editing", "Bearbeiten"), color = Accent, fontSize = 13.sp, modifier = Modifier.weight(1f))
                Text("✕", color = TextSecondary, fontSize = 18.sp, modifier = Modifier.clickable { editing = null; input = "" }.padding(6.dp))
            }
        }

        if (pending.isNotEmpty() && editing == null) {
            PendingTray(pending) { pending.removeAt(it) }
        }
        if (showEmoji) {
            EmojiPanel { input += it }
        }
        if (recording) {
            Row(
                Modifier.fillMaxWidth().background(BgBottom).navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("🔴", fontSize = 16.sp, modifier = Modifier.padding(horizontal = 12.dp))
                Text(fmtSecs(recSecs), color = Txt, fontSize = 18.sp, modifier = Modifier.weight(1f))
                Text("🗑", fontSize = 24.sp, modifier = Modifier.clickable { cancelRecording() }.padding(10.dp))
                Text("➤", color = Accent, fontSize = 28.sp, modifier = Modifier.clickable { finishRecording() }.padding(10.dp))
            }
        } else if (chat != null && !Store.canPost(friendId)) {
            Row(
                Modifier.fillMaxWidth().background(BgBottom).navigationBarsPadding().padding(12.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                if (Store.myMember(friendId) == null) {
                    Text(
                        tr("Подписаться", "Subscribe", "Abonnieren"), color = Accent, fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.clickable { scope.launch { try { Store.joinChat(Store.cidOf(friendId)) } catch (e: Exception) { error = friendlyError(e.message ?: "") } } }.padding(8.dp)
                    )
                } else {
                    Text(tr("Писать в канал может только владелец", "Only the owner can post", "Nur der Besitzer kann posten"), color = TextSecondary, fontSize = 13.sp)
                }
            }
        } else {
            Row(
                Modifier.fillMaxWidth().background(BgBottom).navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (editing == null) {
                    Box {
                        Text("📎", fontSize = 26.sp, modifier = Modifier.clickable { menu = true }.padding(8.dp))
                        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                            DropdownMenuItem(
                                text = { Text(tr("Фото и видео", "Photos and videos", "Fotos und Videos")) },
                                onClick = { menu = false; mediaPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo)) }
                            )
                            DropdownMenuItem(text = { Text(tr("Файл", "File", "Datei")) }, onClick = { menu = false; filePicker.launch(arrayOf("*/*")) })
                            DropdownMenuItem(text = { Text(tr("Картинка от ИИ", "AI image", "KI-Bild")) }, onClick = { menu = false; showAI = true })
                        }
                    }
                }
                Text("😊", fontSize = 26.sp, modifier = Modifier.clickable { showEmoji = !showEmoji }.padding(6.dp))
                NxField(
                    input, { input = it }, tr("Сообщение", "Message", "Nachricht"),
                    modifier = Modifier.weight(1f), singleLine = false
                )
                if (editing == null && input.isBlank() && pending.isEmpty()) {
                    Text("🎤", fontSize = 26.sp, modifier = Modifier.clickable { micClick() }.padding(10.dp))
                } else {
                    Text(if (editing != null) "✓" else "➤", color = Accent, fontSize = 28.sp, modifier = Modifier.clickable { sendText() }.padding(10.dp))
                }
            }
        }
    }

    if (showAI) {
        AlertDialog(
            onDismissRequest = { showAI = false },
            title = { Text(tr("Картинка от ИИ", "AI image", "KI-Bild")) },
            text = { NxField(aiPrompt, { aiPrompt = it }, tr("Что нарисовать?", "What to draw?", "Was zeichnen?")) },
            confirmButton = { TextButton(onClick = { sendAIImage() }) { Text(tr("Отправить", "Send", "Senden")) } },
            dismissButton = { TextButton(onClick = { showAI = false }) { Text(tr("Отмена", "Cancel", "Abbrechen")) } }
        )
    }

    if (showForward) {
        val friends = Store.friendIds.mapNotNull { Store.profiles[it] }
        AlertDialog(
            onDismissRequest = { showForward = false; if (menuSingle) { selected = emptySet(); menuSingle = false } },
            title = { Text(tr("Переслать", "Forward", "Weiterleiten")) },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    Row(
                        Modifier.fillMaxWidth().clickable { forwardToAI() }.padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("✨", fontSize = 26.sp, modifier = Modifier.padding(end = 12.dp))
                        Text(tr("Умный Чат", "Smart Chat", "Smarter Chat"), fontSize = 16.sp)
                    }
                    for (c in Store.chats.filter { Store.canPost("c:" + it.id) }) {
                        Row(
                            Modifier.fillMaxWidth().clickable { forwardTo("c:" + c.id) }.padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(if (c.kind == "channel") "📢" else "👥", fontSize = 26.sp, modifier = Modifier.padding(end = 12.dp))
                            Text(c.title, fontSize = 16.sp)
                        }
                    }
                    for (p in friends) {
                        Row(
                            Modifier.fillMaxWidth().clickable { forwardTo(p.id) }.padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Avatar(p, 36.dp)
                            Text(p.nick, fontSize = 16.sp, modifier = Modifier.padding(start = 12.dp))
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { showForward = false; if (menuSingle) { selected = emptySet(); menuSingle = false } }) { Text(tr("Отмена", "Cancel", "Abbrechen")) } }
        )
    }

    if (showDelete) {
        val allMine = selMsgs.isNotEmpty() && selMsgs.all { it.sender == Store.myId }
        AlertDialog(
            onDismissRequest = { showDelete = false; if (menuSingle) { selected = emptySet(); menuSingle = false } },
            title = { Text(tr("Удалить сообщения?", "Delete messages?", "Nachrichten löschen?")) },
            text = {
                Text(
                    if (allMine) tr("Можно удалить у всех или только у себя.", "Delete for everyone or only for you.", "Für alle oder nur für dich löschen.")
                    else tr("Сообщения собеседника удалятся только у тебя.", "Messages from the other person are deleted only for you.", "Nachrichten des anderen werden nur bei dir gelöscht.")
                )
            },
            confirmButton = {
                Row {
                    TextButton(onClick = { deleteSelected(false) }) { Text(tr("У меня", "For me", "Für mich")) }
                    if (allMine) TextButton(onClick = { deleteSelected(true) }) { Text(tr("У всех", "For everyone", "Für alle")) }
                }
            },
            dismissButton = { TextButton(onClick = { showDelete = false; if (menuSingle) { selected = emptySet(); menuSingle = false } }) { Text(tr("Отмена", "Cancel", "Abbrechen")) } }
        )
    }

    val vd = video
    if (vd != null) VideoDialog(vd) { video = null }
    if (showInfo && chat != null) ChatInfoDialog(friendId, { showInfo = false }) { showInfo = false; onBack() }

    val fs = fullscreen
    if (fs != null) {
        Dialog(onDismissRequest = { fullscreen = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(Modifier.fillMaxSize().background(Color.Black).clickable { fullscreen = null }, contentAlignment = Alignment.Center) {
                RemoteImage(
                    key = "chat:$fs",
                    loader = { Api.download(Api.signedUrl("chat-media", fs)) },
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    m: Message, mine: Boolean, selected: Boolean, selecting: Boolean,
    quoted: Message?, showNick: Boolean, reactions: List<Reaction>, onReply: () -> Unit, onReact: (String) -> Unit,
    onImage: (String) -> Unit, onVideo: (String) -> Unit, onToggle: () -> Unit,
    onCopy: () -> Unit, onEdit: (() -> Unit)?, onForward: () -> Unit, onDelete: () -> Unit
) {
    val ctx = LocalContext.current
    var menuOpen by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    Row(
        Modifier
            .fillMaxWidth()
            .background(if (selected) Accent.copy(alpha = 0.18f) else Color.Transparent)
            .padding(vertical = 2.dp),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start
    ) {
        val shape = RoundedCornerShape(18.dp)
        Column(
            Modifier
                .widthIn(max = 290.dp)
                .clip(shape)
                .background(if (mine) Brush.horizontalGradient(listOf(Accent, Accent2)) else Brush.horizontalGradient(listOf(CardBg, CardBg)))
                .combinedClickable(
                    onClick = {
                        val path = m.mediaPath
                        if (selecting) {
                            onToggle()
                        } else if (m.kind == "image" && path != null) {
                            onImage(path)
                        } else if (m.kind == "file" && path != null) {
                            scope.launch {
                                try {
                                    val url = Api.signedUrl("chat-media", path)
                                    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                } catch (e: Exception) {
                                }
                            }
                        }
                    },
                    onLongClick = { if (selecting) onToggle() else menuOpen = true }
                )
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            val textColor = if (mine) Color.White else Txt
            if (showNick) {
                Text(Store.profiles[m.sender]?.nick ?: "", color = Accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
            if (m.replyTo != null) {
                Column(
                    Modifier.padding(bottom = 4.dp).clip(RoundedCornerShape(8.dp))
                        .background(Color.Black.copy(alpha = 0.18f)).padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Text(
                        if (quoted == null) tr("Сообщение удалено", "Message deleted", "Nachricht gelöscht")
                        else (if (quoted.sender == Store.myId) tr("Вы", "You", "Du") else Store.profiles[quoted.sender]?.nick ?: ""),
                        color = textColor, fontSize = 11.sp, fontWeight = FontWeight.SemiBold
                    )
                    if (quoted != null) Text(previewOf(quoted), color = textColor.copy(alpha = 0.8f), fontSize = 12.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
            val path = m.mediaPath
            if (m.kind == "image" && path != null) {
                RemoteImage(
                    key = "chat:$path",
                    loader = { Api.download(Api.signedUrl("chat-media", path)) },
                    modifier = Modifier.widthIn(max = 260.dp).height(220.dp).clip(RoundedCornerShape(12.dp)),
                    contentScale = ContentScale.Crop
                )
            } else if (m.kind == "file" && path != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("📎", fontSize = 22.sp)
                    Text(m.fileName ?: tr("Файл", "File", "Datei"), color = textColor, fontSize = 15.sp, modifier = Modifier.padding(start = 8.dp))
                }
            } else if (m.kind == "album") {
                AlbumContent(
                    m, textColor, selecting, onToggle, { if (selecting) onToggle() else menuOpen = true },
                    onImage, onVideo,
                    { p ->
                        scope.launch {
                            try {
                                val url = Api.signedUrl("chat-media", p)
                                ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            } catch (e: Exception) {
                            }
                        }
                    }
                )
            } else {
                Text(linkified(m.body ?: "", if (mine) Color.White else Accent), color = textColor, fontSize = 16.sp)
            }
            Text(
                (if (m.editedAt != null) tr("изм. ", "edited ", "bearb. ") else "") + timeOf(m.createdAt) + if (mine && m.readAt != null) " ✓✓" else "",
                color = textColor.copy(alpha = 0.6f), fontSize = 10.sp,
                modifier = Modifier.align(Alignment.End)
            )
            if (reactions.isNotEmpty()) {
                Row(Modifier.padding(top = 4.dp)) {
                    for ((e, list) in reactions.groupBy { it.emoji }) {
                        Text(
                            e + (if (list.size > 1) " ${list.size}" else ""), color = textColor, fontSize = 13.sp,
                            modifier = Modifier.padding(end = 4.dp).clip(RoundedCornerShape(10.dp))
                                .background(Color.Black.copy(alpha = 0.2f)).clickable { onReact(e) }.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                Row(Modifier.padding(horizontal = 8.dp)) {
                    for (e in listOf("👍", "❤️", "😂", "😮", "😢", "🔥")) {
                        Text(e, fontSize = 22.sp, modifier = Modifier.clickable { menuOpen = false; onReact(e) }.padding(6.dp))
                    }
                }
                DropdownMenuItem(text = { Text(tr("Ответить", "Reply", "Antworten")) }, onClick = { menuOpen = false; onReply() })
                DropdownMenuItem(text = { Text(tr("Копировать", "Copy", "Kopieren")) }, onClick = { menuOpen = false; onCopy() })
                if (onEdit != null) {
                    DropdownMenuItem(text = { Text(tr("Изменить", "Edit", "Bearbeiten")) }, onClick = { menuOpen = false; onEdit() })
                }
                DropdownMenuItem(text = { Text(tr("Переслать", "Forward", "Weiterleiten")) }, onClick = { menuOpen = false; onForward() })
                DropdownMenuItem(text = { Text(tr("Удалить", "Delete", "Löschen"), color = Color(0xFFE5484D)) }, onClick = { menuOpen = false; onDelete() })
                DropdownMenuItem(text = { Text(tr("Выделить", "Select", "Auswählen")) }, onClick = { menuOpen = false; onToggle() })
            }
        }
    }
}

// ---------- ИИ-чат ----------

private class AiMsg(val role: String, val text: String, val image: android.graphics.Bitmap? = null)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AIChatScreen(onBack: () -> Unit, initial: String = "") {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("neirox_ai", 0) }
    val msgs = remember {
        mutableStateListOf<AiMsg>().apply {
            try {
                val arr = JSONArray(prefs.getString("history", "[]"))
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    add(AiMsg(o.getString("role"), o.getString("text")))
                }
            } catch (e: Exception) {
            }
        }
    }
    var input by remember { mutableStateOf("") }
    var imageMode by remember { mutableStateOf(false) }
    var showEmoji by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    fun save() {
        val arr = JSONArray()
        for (m in msgs.takeLast(100)) arr.put(JSONObject().put("role", m.role).put("text", m.text))
        prefs.edit().putString("history", arr.toString()).apply()
    }

    LaunchedEffect(msgs.size, busy) {
        if (msgs.isNotEmpty()) listState.scrollToItem(msgs.size - 1)
    }

    fun send(override: String? = null) {
        val t = (override ?: input).trim()
        if (t.isEmpty() || busy) return
        if (override == null) input = ""
        error = ""
        msgs.add(AiMsg("user", t))
        busy = true
        val asImage = imageMode
        val history = msgs.takeLast(20).filter { it.image == null }.map { Pair(it.role, it.text) }
        scope.launch {
            try {
                if (asImage) {
                    val data = Api.aiImage(t)
                    val bmp = withContext(Dispatchers.IO) { decodeBitmap(data) }
                    msgs.add(AiMsg("assistant", "🖼", bmp))
                } else {
                    msgs.add(AiMsg("assistant", Api.aiText(history)))
                }
                save()
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    LaunchedEffect(Unit) {
        if (initial.isNotEmpty()) send(initial)
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("‹", color = Accent, fontSize = 34.sp, modifier = Modifier.clickable { onBack() }.padding(horizontal = 12.dp))
            Text(tr("Умный Чат", "Smart Chat", "Smarter Chat"), color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, modifier = Modifier.weight(1f))
            Text("🗑", fontSize = 22.sp, modifier = Modifier.clickable { msgs.clear(); save() }.padding(10.dp))
        }
        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (msgs.isEmpty()) {
                item {
                    Text(
                        tr("Задай вопрос или переключись на «Картинка» и опиши, что нарисовать.",
                            "Ask a question, or switch to “Image” and describe what to draw.",
                            "Stelle eine Frage oder wechsle zu „Bild“ und beschreibe, was gezeichnet werden soll."),
                        color = TextSecondary, fontSize = 14.sp, modifier = Modifier.padding(top = 30.dp)
                    )
                }
            }
            items(msgs.size) { i ->
                val m = msgs[i]
                val mine = m.role == "user"
                Row(Modifier.fillMaxWidth(), horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start) {
                    Box(
                        Modifier
                            .widthIn(max = 300.dp)
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (mine) Brush.horizontalGradient(listOf(Accent, Accent2)) else Brush.horizontalGradient(listOf(CardBg, CardBg)))
                            .combinedClickable(onClick = {}, onLongClick = {
                                if (m.image == null) {
                                    val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                    cm.setPrimaryClip(ClipData.newPlainText("neirox", m.text))
                                    Toast.makeText(ctx, tr("Скопировано", "Copied", "Kopiert"), Toast.LENGTH_SHORT).show()
                                }
                            })
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        if (m.image != null) {
                            Image(m.image.asImageBitmap(), null, Modifier.widthIn(max = 260.dp), contentScale = ContentScale.Fit)
                        } else {
                            Text(linkified(m.text, if (mine) Color.White else Accent), color = if (mine) Color.White else Txt, fontSize = 16.sp)
                        }
                    }
                }
            }
            if (busy) {
                item { CircularProgressIndicator(Modifier.size(22.dp), color = Accent, strokeWidth = 2.dp) }
            }
        }
        if (error.isNotEmpty()) Box(Modifier.padding(horizontal = 14.dp)) { NxError(error) }
        Row(Modifier.padding(horizontal = 14.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            NxSmallButton(tr("Текст", "Text", "Text"), filled = !imageMode) { imageMode = false }
            NxSmallButton(tr("Картинка", "Image", "Bild"), filled = imageMode) { imageMode = true }
        }
        if (showEmoji) EmojiPanel { input += it }
        Row(
            Modifier.fillMaxWidth().background(BgBottom).navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("😊", fontSize = 26.sp, modifier = Modifier.clickable { showEmoji = !showEmoji }.padding(6.dp))
            NxField(
                input, { input = it },
                if (imageMode) tr("Что нарисовать?", "What to draw?", "Was zeichnen?") else tr("Сообщение", "Message", "Nachricht"),
                modifier = Modifier.weight(1f), singleLine = false
            )
            Text("➤", color = Accent, fontSize = 28.sp, modifier = Modifier.clickable { send() }.padding(10.dp))
        }
    }
}
