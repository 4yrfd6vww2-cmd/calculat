package app.neirox

import android.content.Intent
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

private const val MAX_FILE = 25 * 1024 * 1024

@Composable
fun ChatsTab(onOpen: (String) -> Unit, onAI: () -> Unit) {
    val friends = Store.friendIds.mapNotNull { Store.profiles[it] }
    val lastOf = { id: String -> Store.thread(id).lastOrNull() }
    val sorted = friends.sortedByDescending { lastOf(it.id)?.createdAt ?: "" }

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
            items(sorted, key = { it.id }) { p ->
                val last = lastOf(p.id)
                val unread = Store.unread(p.id)
                Row(
                    Modifier.fillMaxWidth().clickable { onOpen(p.id) }.padding(horizontal = 20.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Avatar(p, 48.dp)
                    Column(Modifier.padding(start = 14.dp).weight(1f)) {
                        Text(p.nick, color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                        val preview = when {
                            last == null -> tr("Нет сообщений", "No messages", "Keine Nachrichten")
                            last.kind == "image" -> "🖼 " + tr("Фото", "Photo", "Foto")
                            last.kind == "file" -> "📎 " + (last.fileName ?: tr("Файл", "File", "Datei"))
                            else -> last.body ?: ""
                        }
                        Text(preview, color = TextSecondary, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
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
}

@Composable
fun ChatScreen(friendId: String, onBack: () -> Unit) {
    val friend = Store.profiles[friendId]
    val thread = Store.thread(friendId)
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

    LaunchedEffect(thread.size) {
        if (thread.isNotEmpty()) listState.scrollToItem(thread.size - 1)
    }
    LaunchedEffect(Store.unread(friendId)) {
        if (Store.unread(friendId) > 0) {
            try { Store.markRead(friendId) } catch (e: Exception) { }
        }
    }

    fun buzz() {
        if (Settings.haptics) view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    }

    fun sendUri(uri: Uri, photo: Boolean) {
        busy = true
        error = ""
        scope.launch {
            try {
                if (photo) {
                    val jpg = withContext(Dispatchers.IO) { compressImage(ctx, uri) }
                        ?: throw ApiError(tr("Не удалось прочитать фото", "Could not read the photo", "Foto konnte nicht gelesen werden"))
                    Store.sendMedia(jpg, "image/jpeg", "photo.jpg", "image", friendId)
                } else {
                    val bytes = withContext(Dispatchers.IO) {
                        ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    } ?: throw ApiError(tr("Не удалось прочитать файл", "Could not read the file", "Datei konnte nicht gelesen werden"))
                    if (bytes.size > MAX_FILE) {
                        throw ApiError(tr("Файл больше 25 МБ", "File is larger than 25 MB", "Datei ist größer als 25 MB"))
                    }
                    val mime = ctx.contentResolver.getType(uri) ?: "application/octet-stream"
                    Store.sendMedia(bytes, mime, displayName(ctx, uri), "file", friendId)
                }
                buzz()
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) sendUri(uri, true)
    }
    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) sendUri(uri, false)
    }

    fun sendText() {
        val t = input.trim()
        if (t.isEmpty() || busy) return
        input = ""
        error = ""
        buzz()
        scope.launch {
            try {
                Store.sendText(t, friendId)
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
                Store.sendMedia(img, "image/jpeg", "ai.jpg", "image", friendId)
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("‹", color = Accent, fontSize = 34.sp, modifier = Modifier.clickable { onBack() }.padding(horizontal = 12.dp))
            Avatar(friend, 38.dp)
            Text(friend?.nick ?: "", color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, modifier = Modifier.padding(start = 10.dp))
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(thread, key = { it.id }) { m ->
                MessageBubble(m, mine = m.sender == Store.myId, onImage = { fullscreen = it })
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

        Row(
            Modifier.fillMaxWidth().background(BgBottom).navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box {
                Text("📎", fontSize = 26.sp, modifier = Modifier.clickable { menu = true }.padding(8.dp))
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text(tr("Фото", "Photo", "Foto")) }, onClick = { menu = false; photoPicker.launch("image/*") })
                    DropdownMenuItem(text = { Text(tr("Файл", "File", "Datei")) }, onClick = { menu = false; filePicker.launch("*/*") })
                    DropdownMenuItem(text = { Text(tr("Картинка от ИИ", "AI image", "KI-Bild")) }, onClick = { menu = false; showAI = true })
                }
            }
            NxField(
                input, { input = it }, tr("Сообщение", "Message", "Nachricht"),
                modifier = Modifier.weight(1f), singleLine = false
            )
            Text("➤", color = Accent, fontSize = 28.sp, modifier = Modifier.clickable { sendText() }.padding(10.dp))
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

@Composable
fun MessageBubble(m: Message, mine: Boolean, onImage: (String) -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start) {
        val shape = RoundedCornerShape(18.dp)
        Column(
            Modifier
                .widthIn(max = 290.dp)
                .clip(shape)
                .background(if (mine) Brush.horizontalGradient(listOf(Accent, Accent2)) else Brush.horizontalGradient(listOf(CardBg, CardBg)))
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            val textColor = if (mine) Color.White else Txt
            val path = m.mediaPath
            if (m.kind == "image" && path != null) {
                RemoteImage(
                    key = "chat:$path",
                    loader = { Api.download(Api.signedUrl("chat-media", path)) },
                    modifier = Modifier.widthIn(max = 260.dp).height(220.dp).clip(RoundedCornerShape(12.dp)).clickable { onImage(path) },
                    contentScale = ContentScale.Crop
                )
            } else if (m.kind == "file" && path != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.clickable {
                        scope.launch {
                            try {
                                val url = Api.signedUrl("chat-media", path)
                                ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            } catch (e: Exception) {
                            }
                        }
                    }
                ) {
                    Text("📎", fontSize = 22.sp)
                    Text(m.fileName ?: tr("Файл", "File", "Datei"), color = textColor, fontSize = 15.sp, modifier = Modifier.padding(start = 8.dp))
                }
            } else {
                Text(m.body ?: "", color = textColor, fontSize = 16.sp)
            }
            Text(
                timeOf(m.createdAt) + if (mine && m.readAt != null) " ✓✓" else "",
                color = textColor.copy(alpha = 0.6f), fontSize = 10.sp,
                modifier = Modifier.align(Alignment.End)
            )
        }
    }
}

// ---------- ИИ-чат ----------

private class AiMsg(val role: String, val text: String, val image: android.graphics.Bitmap? = null)

@Composable
fun AIChatScreen(onBack: () -> Unit) {
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

    fun send() {
        val t = input.trim()
        if (t.isEmpty() || busy) return
        input = ""
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
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        if (m.image != null) {
                            Image(m.image.asImageBitmap(), null, Modifier.widthIn(max = 260.dp), contentScale = ContentScale.Fit)
                        } else {
                            Text(m.text, color = if (mine) Color.White else Txt, fontSize = 16.sp)
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
        Row(
            Modifier.fillMaxWidth().background(BgBottom).navigationBarsPadding().padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            NxField(
                input, { input = it },
                if (imageMode) tr("Что нарисовать?", "What to draw?", "Was zeichnen?") else tr("Сообщение", "Message", "Nachricht"),
                modifier = Modifier.weight(1f), singleLine = false
            )
            Text("➤", color = Accent, fontSize = 28.sp, modifier = Modifier.clickable { send() }.padding(10.dp))
        }
    }
}
