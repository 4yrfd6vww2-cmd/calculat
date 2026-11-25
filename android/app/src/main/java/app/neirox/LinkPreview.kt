package app.neirox

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

data class OgData(val title: String?, val desc: String?, val image: String?)

object LinkPreviewFetcher {
    private val cache = HashMap<String, OgData?>()

    private fun decodeEntities(s: String): String = s
        .replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
        .replace("&quot;", "\"").replace("&#39;", "'").replace("&apos;", "'")

    private fun meta(html: String, prop: String): String? {
        val re = Regex(
            "<meta[^>]+(?:property|name)=[\"']$prop[\"'][^>]+content=[\"']([^\"']*)[\"']",
            RegexOption.IGNORE_CASE
        )
        val reAlt = Regex(
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+(?:property|name)=[\"']$prop[\"']",
            RegexOption.IGNORE_CASE
        )
        val m = re.find(html) ?: reAlt.find(html)
        return m?.groupValues?.get(1)?.let { decodeEntities(it) }
    }

    private fun tagText(html: String): String? {
        val m = Regex("<title[^>]*>([^<]*)</title>", RegexOption.IGNORE_CASE).find(html)
        return m?.groupValues?.get(1)?.trim()?.let { decodeEntities(it) }
    }

    private suspend fun load(urlStr: String): OgData? = withContext(Dispatchers.IO) {
        try {
            val c = URL(urlStr).openConnection() as HttpURLConnection
            c.connectTimeout = 6_000
            c.readTimeout = 6_000
            c.setRequestProperty("User-Agent", "Mozilla/5.0 (compatible; NeiroxBot/1.0)")
            c.instanceFollowRedirects = true
            if (c.responseCode !in 200..299) {
                c.disconnect()
                return@withContext null
            }
            val buf = ByteArray(400_000)
            var total = 0
            c.inputStream.use { ins ->
                while (total < buf.size) {
                    val n = ins.read(buf, total, buf.size - total)
                    if (n <= 0) break
                    total += n
                }
            }
            c.disconnect()
            val html = String(buf, 0, total, Charsets.UTF_8)
            val title = meta(html, "og:title") ?: tagText(html)
            val desc = meta(html, "og:description") ?: meta(html, "description")
            var image = meta(html, "og:image")
            if (image != null && !image.startsWith("http", ignoreCase = true)) {
                try {
                    val base = URL(urlStr)
                    image = URL(base, image).toString()
                } catch (e: Exception) {
                    image = null
                }
            }
            if (title == null && desc == null && image == null) null else OgData(title, desc, image)
        } catch (e: Exception) {
            null
        }
    }

    suspend fun fetch(url: String): OgData? {
        cache[url]?.let { return it }
        if (cache.containsKey(url)) return null
        val data = load(url)
        cache[url] = data
        return data
    }
}

@Composable
fun LinkPreviewView(url: String, mine: Boolean) {
    val ctx = LocalContext.current
    val state: State<OgData?> = produceState<OgData?>(null, url) {
        value = LinkPreviewFetcher.fetch(url)
    }
    val data = state.value ?: return
    if (data.title == null && data.desc == null && data.image == null) return
    val bg = if (mine) Color.White.copy(alpha = 0.14f) else Color.Black.copy(alpha = 0.06f)
    val textColor = if (mine) Color.White else Txt
    Column(
        Modifier
            .padding(top = 6.dp)
            .widthIn(max = 240.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .clickable {
                try {
                    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } catch (e: Exception) {
                }
            }
            .padding(8.dp)
    ) {
        if (data.image != null) {
            val img: State<android.graphics.Bitmap?> = produceState<android.graphics.Bitmap?>(null, data.image) {
                value = try {
                    withContext(Dispatchers.IO) {
                        val c = URL(data.image).openConnection() as HttpURLConnection
                        c.connectTimeout = 6_000
                        c.readTimeout = 6_000
                        val bytes = c.inputStream.use { it.readBytes() }
                        c.disconnect()
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    }
                } catch (e: Exception) {
                    null
                }
            }
            val bmp = img.value
            if (bmp != null) {
                Image(
                    bitmap = bmp.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().height(110.dp).clip(RoundedCornerShape(8.dp))
                )
            }
        }
        if (data.title != null) {
            Row(Modifier.padding(top = 4.dp)) {
                Text(data.title, color = textColor, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
        if (data.desc != null) {
            Row(Modifier.padding(top = 2.dp)) {
                Text(data.desc, color = textColor.copy(alpha = 0.8f), fontSize = 11.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

fun firstHTTPURL(s: String): String? {
    val re = Regex("(?:https?://|www\\.)[^\\s<>\"']+", RegexOption.IGNORE_CASE)
    val m = re.find(s) ?: return null
    var u = m.value
    while (u.isNotEmpty() && u.last() in ".,!?;:)]}»\"'") u = u.dropLast(1)
    if (u.length < 5) return null
    return if (u.startsWith("www.", ignoreCase = true)) "https://$u" else u
}
