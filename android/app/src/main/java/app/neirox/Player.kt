package app.neirox

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.io.File

object Player {
    private lateinit var dir: File
    private lateinit var appCtx: Context
    private var mp: MediaPlayer? = null

    private fun changed() {
        if (::appCtx.isInitialized) Notif.update(appCtx)
    }

    var tracks by mutableStateOf<List<File>>(emptyList())
        private set
    var currentIndex by mutableIntStateOf(-1)
        private set
    var playing by mutableStateOf(false)
        private set
    var position by mutableFloatStateOf(0f)
        private set
    var duration by mutableFloatStateOf(0f)
        private set

    fun init(ctx: Context) {
        appCtx = ctx.applicationContext
        dir = File(appCtx.filesDir, "music").apply { mkdirs() }
        reload()
    }

    private fun reload() {
        tracks = dir.listFiles()?.filter { it.isFile && it.extension.lowercase() in setOf("mp3", "mp4", "m4a") }
            ?.sortedBy { it.name.lowercase() } ?: emptyList()
    }

    val currentTitle: String? get() = tracks.getOrNull(currentIndex)?.nameWithoutExtension

    private fun release() {
        try {
            mp?.release()
        } catch (e: Exception) {
        }
        mp = null
        playing = false
        position = 0f
        duration = 0f
    }

    fun stopAll() {
        release()
        currentIndex = -1
        changed()
    }

    fun play(i: Int) {
        val f = tracks.getOrNull(i) ?: return
        release()
        try {
            val p = MediaPlayer()
            p.setWakeMode(appCtx, android.os.PowerManager.PARTIAL_WAKE_LOCK)
            p.setDataSource(f.absolutePath)
            p.setOnCompletionListener { next() }
            p.prepare()
            p.start()
            mp = p
            currentIndex = i
            playing = true
            duration = p.duration / 1000f
        } catch (e: Exception) {
            release()
        }
        changed()
    }

    fun toggle() {
        val p = mp
        if (p == null) {
            if (tracks.isNotEmpty()) play(if (currentIndex in tracks.indices) currentIndex else 0)
            return
        }
        if (p.isPlaying) {
            p.pause()
            playing = false
        } else {
            p.start()
            playing = true
        }
        changed()
    }

    fun next() {
        if (tracks.isEmpty()) return
        play((currentIndex + 1) % tracks.size)
    }

    fun prev() {
        if (tracks.isEmpty()) return
        play(if (currentIndex <= 0) tracks.size - 1 else currentIndex - 1)
    }

    fun seek(s: Float) {
        mp?.seekTo((s * 1000).toInt())
        position = s
    }

    fun tick() {
        val p = mp ?: return
        try {
            if (p.isPlaying) position = p.currentPosition / 1000f
        } catch (e: Exception) {
        }
    }

    fun delete(i: Int) {
        val f = tracks.getOrNull(i) ?: return
        val wasCurrent = i == currentIndex
        val cur = tracks.getOrNull(currentIndex)
        if (wasCurrent) stopAll()
        f.delete()
        reload()
        if (!wasCurrent && cur != null) currentIndex = tracks.indexOf(cur)
    }

    /** Возвращает (добавлено, не добавлено). Принимаются MP3, M4A и MP4. */
    fun import(ctx: Context, uris: List<Uri>): Pair<Int, Int> {
        var added = 0
        var failed = 0
        for (u in uris) {
            val name = displayName(ctx, u)
            val mime = ctx.contentResolver.getType(u) ?: ""
            val ext = when {
                name.lowercase().endsWith(".mp3") || mime == "audio/mpeg" -> "mp3"
                name.lowercase().endsWith(".m4a") || mime == "audio/mp4" || mime == "audio/x-m4a" -> "m4a"
                name.lowercase().endsWith(".mp4") || mime == "video/mp4" -> "mp4"
                else -> null
            }
            if (ext == null) {
                failed++
                continue
            }
            try {
                var base = name.substringBeforeLast('.', name).replace(Regex("[\\\\/:*?\"<>|]"), "_")
                if (base.isEmpty()) base = "track"
                var f = File(dir, "$base.$ext")
                var n = 1
                while (f.exists()) {
                    f = File(dir, "$base ($n).$ext")
                    n++
                }
                ctx.contentResolver.openInputStream(u)?.use { input ->
                    f.outputStream().use { out -> input.copyTo(out) }
                } ?: throw IllegalStateException()
                added++
            } catch (e: Exception) {
                failed++
            }
        }
        val cur = tracks.getOrNull(currentIndex)
        reload()
        if (cur != null) currentIndex = tracks.indexOf(cur)
        return Pair(added, failed)
    }
}
