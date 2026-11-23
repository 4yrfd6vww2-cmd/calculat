package app.neirox

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings as AndroidSettings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/** Самообновление: берёт docs/version.json, качает APK и открывает установщик. */
object Updater {
    private const val INFO = "https://4yrfd6vww2-cmd.github.io/calculat/version.json"
    private const val PREFIX = "https://github.com/4yrfd6vww2-cmd/calculat/releases/download/"

    var newVersion by mutableStateOf<String?>(null)
        private set
    var url by mutableStateOf<String?>(null)
        private set
    var progress by mutableIntStateOf(-1)
        private set
    var error by mutableStateOf("")
        private set
    private var dismissed = false
    private var downloaded: File? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var started = false

    fun start(ctx: Context) {
        if (started) return
        started = true
        val app = ctx.applicationContext
        scope.launch {
            delay(3000)
            while (true) {
                try { check(app) } catch (e: Exception) { }
                delay(30 * 60 * 1000L)
            }
        }
    }

    private suspend fun check(ctx: Context) {
        val text = withContext(Dispatchers.IO) {
            val c = URL(INFO).openConnection() as HttpURLConnection
            c.connectTimeout = 10000; c.readTimeout = 10000
            c.inputStream.bufferedReader().use { it.readText() }
        }
        val a = JSONObject(text).optJSONObject(BuildConfig.UPDATE_KEY) ?: return
        val code = a.optInt("code", 0)
        val u = a.optString("url", "")
        val cur = try {
            @Suppress("DEPRECATION")
            ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionCode
        } catch (e: Exception) { Int.MAX_VALUE }
        if (code > cur && u.startsWith(PREFIX)) {
            if (newVersion != a.optString("version", "")) dismissed = false
            newVersion = a.optString("version", code.toString())
            url = u
        } else {
            newVersion = null
        }
    }

    val visible: Boolean get() = newVersion != null && !dismissed

    fun dismiss() { dismissed = true }

    fun install(ctx: Context) {
        val u = url ?: return
        if (progress in 0..99) return
        error = ""
        val f = downloaded
        if (f != null && f.exists() && progress == 100) { open(ctx, f); return }
        progress = 0
        scope.launch {
            try {
                val file = withContext(Dispatchers.IO) {
                    val dir = File(ctx.cacheDir, "updates").apply { mkdirs() }
                    val out = File(dir, "neirox.apk")
                    val c = URL(u).openConnection() as HttpURLConnection
                    c.connectTimeout = 15000; c.readTimeout = 30000
                    val total = c.getHeaderField("Content-Length")?.toLongOrNull() ?: c.contentLength.toLong()
                    c.inputStream.use { inp ->
                        out.outputStream().use { o ->
                            val buf = ByteArray(64 * 1024)
                            var got = 0L
                            var last = -1
                            while (true) {
                                val n = inp.read(buf)
                                if (n < 0) break
                                o.write(buf, 0, n)
                                got += n
                                if (total > 0) {
                                    val pct = (got * 100 / total).toInt().coerceAtMost(99)
                                    if (pct != last) { last = pct; withContext(Dispatchers.Main) { progress = pct } }
                                }
                            }
                        }
                    }
                    out
                }
                downloaded = file
                progress = 100
                open(ctx, file)
            } catch (e: Exception) {
                progress = -1
                error = tr("Не удалось скачать", "Download failed", "Download fehlgeschlagen")
            }
        }
    }

    private fun open(ctx: Context, f: File) {
        try {
            if (Build.VERSION.SDK_INT >= 26 && !ctx.packageManager.canRequestPackageInstalls()) {
                ctx.startActivity(
                    Intent(AndroidSettings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + ctx.packageName))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                error = tr("Разреши установку из этого приложения и нажми «Установить» ещё раз",
                    "Allow installs from this app, then tap Install again", "Installation erlauben und erneut tippen")
                return
            }
            val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".fileprovider", f)
            ctx.startActivity(
                Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (e: Exception) {
            error = tr("Не удалось открыть установщик", "Could not open installer", "Installer nicht gestartet")
        }
    }
}

@Composable
fun UpdateBanner() {
    if (!Updater.visible) return
    val ctx = androidx.compose.ui.platform.LocalContext.current
    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(10.dp)
            .clip(RoundedCornerShape(16.dp)).background(CardBg).padding(12.dp)
    ) {
        Text(
            tr("Доступно новое обновление ", "New update available ", "Neues Update verfügbar ") + Updater.newVersion,
            color = Txt, fontSize = 15.sp
        )
        if (Updater.progress in 0..99) {
            Text(tr("Скачиваю… ", "Downloading… ", "Lade … ") + Updater.progress + "%", color = Accent, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp))
        }
        if (Updater.error.isNotEmpty()) Text(Updater.error, color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { Updater.dismiss() }) { Text(tr("Не устанавливать", "Not now", "Nicht jetzt"), color = TextSecondary) }
            TextButton(onClick = { Updater.install(ctx) }) { Text(tr("Установить", "Install", "Installieren"), color = Accent) }
        }
    }
}
