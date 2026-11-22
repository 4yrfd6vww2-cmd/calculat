package app.neirox

import android.content.Context
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

fun fmtSecs(s: Int): String = "${s / 60}:${(s % 60).toString().padStart(2, '0')}"

// ---------- ссылки ----------

private val URL_RE = Regex("(?:https?://|www\\.)[^\\s<>\"']+", RegexOption.IGNORE_CASE)

/** Текст, в котором ссылки подсвечены и открываются в браузере по нажатию. */
fun linkified(text: String, linkColor: Color): AnnotatedString = buildAnnotatedString {
    var last = 0
    for (m in URL_RE.findAll(text)) {
        var u = m.value
        while (u.isNotEmpty() && u.last() in ".,!?;:)]}»\"'") u = u.dropLast(1)
        if (u.length < 5 || m.range.first < last) continue
        append(text.substring(last, m.range.first))
        val href = if (u.startsWith("www.", ignoreCase = true)) "https://$u" else u
        withLink(LinkAnnotation.Url(href, TextLinkStyles(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)))) {
            append(u)
        }
        last = m.range.first + u.length
    }
    append(text.substring(last))
}

// ---------- смайлики ----------

val EMOJI_GROUPS: List<List<String>> = listOf(
    "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😋 😛 😜 🤪 😝 🤗 🤭 🤔 🤨 😐 😑 😶 🙄 😏 😴 😌 😔 😪 🤤 😷 🤒 🤕 🤢 🤮 🥵 🥶 😵 🤯 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 💀 💩 🤡 👻 👽 🤖",
    "👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🤝 🙏 💪 👏 🙌 👐 🤲 ✍️ 💅 🧠 👀 👅 👄 🙋 🤦 🤷 💃 🕺 🚶 🏃",
    "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 ✨ ⭐ 🌟 💫 🔥 💥 💯 ✅ ❌ ❓ ❗ ⚡ 🎉 🎊 🎁 🏆 🥇 🎵 🎶 💤 💢 💬",
    "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🐺 🐴 🦄 🐝 🦋 🐌 🐞 🐢 🐍 🐙 🦀 🐠 🐬 🐳 🌸 🌹 🌻 🌷 🌲 🌴 🍀 🍁 🌈 ☀️ 🌙 ☁️ ❄️ 🌊",
    "🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🥕 🌽 🥔 🍞 🧀 🍳 🥞 🥓 🍔 🍟 🍕 🌭 🌮 🍝 🍣 🍜 🍦 🍩 🍪 🎂 🍰 🍫 🍬 🍭 ☕ 🍵 🥤 🍺 🍷 🥂",
    "⚽ 🏀 🏈 ⚾ 🎾 🏐 🎱 🏓 🎮 🎲 🎯 🎸 🎹 🎤 🎧 📱 💻 ⌨️ 📷 🎬 📚 ✏️ 📌 📎 🔑 🔒 💡 💰 💳 🚗 ✈️ 🚀 🏠"
).map { it.split(" ") }

@Composable
fun EmojiPanel(onPick: (String) -> Unit) {
    var cat by remember { mutableStateOf(0) }
    Column(Modifier.fillMaxWidth().background(CardBg)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp)) {
            EMOJI_GROUPS.forEachIndexed { i, g ->
                Text(
                    g[0], fontSize = 22.sp,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp))
                        .background(if (i == cat) Accent.copy(alpha = 0.25f) else Color.Transparent)
                        .clickable { cat = i }.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
        LazyVerticalGrid(
            columns = GridCells.Adaptive(44.dp),
            modifier = Modifier.fillMaxWidth().height(200.dp),
            contentPadding = PaddingValues(horizontal = 6.dp)
        ) {
            items(EMOJI_GROUPS[cat]) { e ->
                Text(
                    e, fontSize = 26.sp, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().clickable { onPick(e) }.padding(vertical = 6.dp)
                )
            }
        }
    }
}

// ---------- запись голоса ----------

class VoiceRecorder(private val ctx: Context) {
    private var rec: MediaRecorder? = null
    private var file: File? = null

    @Suppress("DEPRECATION")
    fun start(): Boolean {
        return try {
            val f = File(ctx.cacheDir, "voice_${System.currentTimeMillis()}.m4a")
            val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(ctx) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(64000)
            r.setAudioSamplingRate(44100)
            r.setOutputFile(f.absolutePath)
            r.prepare()
            r.start()
            rec = r
            file = f
            true
        } catch (e: Exception) {
            cancel()
            false
        }
    }

    fun stop(): File? {
        val r = rec ?: return null
        rec = null
        return try {
            r.stop()
            r.release()
            file
        } catch (e: Exception) {
            try { r.release() } catch (_: Exception) { }
            file?.delete()
            null
        }
    }

    fun cancel() {
        rec?.let {
            try { it.stop() } catch (_: Exception) { }
            try { it.release() } catch (_: Exception) { }
        }
        rec = null
        file?.delete()
    }
}

// ---------- вложения в очереди ----------

class PendingItem(val uri: Uri, val name: String, val kind: String, val mime: String)

@Composable
private fun PendingThumb(uri: Uri) {
    val ctx = LocalContext.current
    val bmp by produceState<Bitmap?>(null, uri) {
        value = withContext(Dispatchers.IO) {
            try {
                ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }?.let { decodeBitmap(it, 256) }
            } catch (e: Exception) {
                null
            }
        }
    }
    val b = bmp
    if (b != null) Image(b.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
}

@Composable
fun PendingTray(items: List<PendingItem>, onRemove: (Int) -> Unit) {
    LazyRow(
        Modifier.fillMaxWidth().background(BgBottom).padding(horizontal = 8.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(items.size) { i ->
            val p = items[i]
            Box(Modifier.size(72.dp).clip(RoundedCornerShape(12.dp)).background(CardBg)) {
                when (p.kind) {
                    "image" -> PendingThumb(p.uri)
                    "video" -> Text("🎬", fontSize = 30.sp, modifier = Modifier.align(Alignment.Center))
                    else -> Column(Modifier.align(Alignment.Center).padding(4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("📎", fontSize = 22.sp)
                        Text(p.name, color = TextSecondary, fontSize = 10.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
                    }
                }
                Box(
                    Modifier.align(Alignment.TopEnd).padding(3.dp).size(22.dp).clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.65f)).clickable { onRemove(i) },
                    contentAlignment = Alignment.Center
                ) { Text("✕", color = Color.White, fontSize = 11.sp) }
            }
        }
    }
}

// ---------- вложения в сообщении ----------

@Composable
fun VoicePlayer(path: String, textColor: Color, onTap: (() -> Unit) -> Unit) {
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf(0) } // 0 стоп, 1 загрузка, 2 играет, 3 пауза
    var pos by remember { mutableStateOf(0) }
    var dur by remember { mutableStateOf(0) }
    val holder = remember { arrayOfNulls<MediaPlayer>(1) }
    DisposableEffect(Unit) {
        onDispose {
            try { holder[0]?.release() } catch (_: Exception) { }
            holder[0] = null
        }
    }
    LaunchedEffect(state) {
        while (state == 2) {
            pos = try { holder[0]?.currentPosition ?: 0 } catch (e: Exception) { 0 }
            delay(250)
        }
    }
    fun toggle() {
        when (state) {
            2 -> { holder[0]?.pause(); state = 3 }
            3 -> { holder[0]?.start(); state = 2 }
            1 -> {}
            else -> {
                state = 1
                try { holder[0]?.release() } catch (_: Exception) { }
                val p = MediaPlayer()
                holder[0] = p
                scope.launch {
                    try {
                        val url = Api.signedUrl("chat-media", path)
                        p.setAudioAttributes(
                            AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .setUsage(AudioAttributes.USAGE_MEDIA).build()
                        )
                        withContext(Dispatchers.IO) {
                            p.setDataSource(url)
                            p.prepare()
                        }
                        dur = p.duration
                        p.setOnCompletionListener { state = 0; pos = 0 }
                        p.start()
                        state = 2
                    } catch (e: Exception) {
                        state = 0
                    }
                }
            }
        }
    }
    Row(Modifier.width(210.dp).padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
        if (state == 1) {
            CircularProgressIndicator(Modifier.padding(8.dp).size(20.dp), color = textColor, strokeWidth = 2.dp)
        } else {
            Text(
                if (state == 2) "⏸" else "▶", fontSize = 24.sp, color = textColor,
                modifier = Modifier.clickable { onTap { toggle() } }.padding(6.dp)
            )
        }
        val frac = if (dur > 0) (pos.toFloat() / dur).coerceIn(0f, 1f) else 0f
        Box(Modifier.weight(1f).height(4.dp).clip(CircleShape).background(textColor.copy(alpha = 0.25f))) {
            Box(Modifier.fillMaxWidth(frac).fillMaxHeight().background(textColor))
        }
        Text(
            fmtSecs(((if (state == 2 || state == 3) pos else dur) / 1000)),
            color = textColor.copy(alpha = 0.7f), fontSize = 11.sp, modifier = Modifier.padding(start = 8.dp)
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AlbumContent(
    m: Message, textColor: Color, selecting: Boolean,
    onToggle: () -> Unit, onLong: () -> Unit,
    onImage: (String) -> Unit, onVideo: (String) -> Unit, onFile: (String) -> Unit
) {
    val tap: (() -> Unit) -> Unit = { action -> if (selecting) onToggle() else action() }
    val visual = m.attachments.filter { it.type == "image" || it.type == "video" }
    if (visual.isNotEmpty()) {
        val side = if (visual.size == 1) 240.dp else 124.dp
        for (row in visual.chunked(2)) {
            Row(Modifier.padding(bottom = 4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                for (a in row) {
                    Box(
                        Modifier.size(side).clip(RoundedCornerShape(10.dp)).background(Color.Black.copy(alpha = 0.35f))
                            .combinedClickable(
                                onClick = { tap { if (a.type == "image") onImage(a.path) else onVideo(a.path) } },
                                onLongClick = onLong
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (a.type == "image") {
                            RemoteImage(
                                key = "chat:${a.path}",
                                loader = { Api.download(Api.signedUrl("chat-media", a.path)) },
                                modifier = Modifier.fillMaxSize(),
                                contentScale = ContentScale.Crop
                            )
                        } else {
                            Text("▶", color = Color.White, fontSize = 34.sp)
                        }
                    }
                }
            }
        }
    }
    for (a in m.attachments.filter { it.type == "voice" }) VoicePlayer(a.path, textColor) { tap(it) }
    for (a in m.attachments.filter { it.type == "file" }) {
        Row(
            Modifier.combinedClickable(onClick = { tap { onFile(a.path) } }, onLongClick = onLong).padding(vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("📎", fontSize = 22.sp)
            Text(a.name, color = textColor, fontSize = 15.sp, modifier = Modifier.padding(start = 8.dp))
        }
    }
    if (!m.body.isNullOrEmpty()) {
        Text(linkified(m.body, if (textColor == Color.White) Color.White else Accent), color = textColor, fontSize = 16.sp)
    }
}

@Composable
fun VideoDialog(path: String, onClose: () -> Unit) {
    val url by produceState<String?>(null, path) {
        value = try { Api.signedUrl("chat-media", path) } catch (e: Exception) { null }
    }
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().background(Color.Black), contentAlignment = Alignment.Center) {
            val u = url
            if (u != null) {
                AndroidView(
                    factory = { c ->
                        VideoView(c).apply {
                            val mc = MediaController(c)
                            mc.setAnchorView(this)
                            setMediaController(mc)
                            setVideoURI(Uri.parse(u))
                            setOnPreparedListener { start() }
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                CircularProgressIndicator(color = Accent)
            }
            Text("✕", color = Color.White, fontSize = 26.sp, modifier = Modifier.align(Alignment.TopEnd).clickable { onClose() }.padding(16.dp))
        }
    }
}

private val BUILTIN_STICKERS = listOf(
    "😀", "😂", "🥹", "😍", "🥰", "😎", "🤩", "😭", "😡", "🤯", "🥳", "😴", "🤔", "🙄", "😘", "🤗",
    "👍", "👎", "👏", "🙏", "💪", "🔥", "❤️", "💔", "🎉", "🎂", "☕", "🍕", "🐱", "🐶", "🦄", "🌈",
    "⭐", "💯", "🚀", "🎁", "🌹", "🤝", "👋", "🫶"
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun StickerPanel(onEmoji: (String) -> Unit, onOwn: (Sticker) -> Unit, onAdd: () -> Unit, onDelete: (Sticker) -> Unit) {
    var delFor by remember { mutableStateOf<Sticker?>(null) }
    Column(Modifier.fillMaxWidth().background(CardBg)) {
        LazyVerticalGrid(
            columns = GridCells.Adaptive(64.dp),
            modifier = Modifier.fillMaxWidth().height(240.dp),
            contentPadding = PaddingValues(6.dp)
        ) {
            item {
                Text(
                    "＋", color = Accent, fontSize = 30.sp, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().clickable { onAdd() }.padding(vertical = 14.dp)
                )
            }
            items(Store.stickers, key = { "s" + it.id }) { s ->
                Box(
                    Modifier.fillMaxWidth().height(64.dp).padding(3.dp)
                        .combinedClickable(onClick = { onOwn(s) }, onLongClick = { delFor = s })
                ) {
                    RemoteImage(
                        key = "chat:" + s.path,
                        loader = { Api.download(Api.signedUrl("chat-media", s.path)) },
                        modifier = Modifier.fillMaxSize(),
                        contentScale = androidx.compose.ui.layout.ContentScale.Fit
                    )
                }
            }
            items(BUILTIN_STICKERS) { e ->
                Text(
                    e, fontSize = 34.sp, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().clickable { onEmoji(e) }.padding(vertical = 8.dp)
                )
            }
        }
    }
    val d = delFor
    if (d != null) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { delFor = null },
            title = { Text(tr("Удалить стикер?", "Delete sticker?", "Sticker löschen?")) },
            confirmButton = { androidx.compose.material3.TextButton(onClick = { delFor = null; onDelete(d) }) { Text(tr("Удалить", "Delete", "Löschen")) } },
            dismissButton = { androidx.compose.material3.TextButton(onClick = { delFor = null }) { Text(tr("Отмена", "Cancel", "Abbrechen")) } }
        )
    }
}
