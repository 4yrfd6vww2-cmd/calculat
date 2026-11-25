package app.neirox

import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private fun JSONObject.str(k: String): String? = if (isNull(k)) null else optString(k, "").ifEmpty { null }

data class Profile(
    val id: String, val nick: String, val avatarUrl: String?, val createdAt: String?,
    val lastSeen: String? = null, val typingTo: String? = null, val typingAt: String? = null
)

data class Friendship(val id: Long, val requester: String, val addressee: String, val status: String)

data class Attachment(val path: String, val name: String, val type: String, val mime: String)

data class Message(
    val id: Long,
    val sender: String,
    val receiver: String?,
    val kind: String,
    val body: String?,
    val mediaPath: String?,
    val fileName: String?,
    val createdAt: String,
    val readAt: String?,
    val editedAt: String?,
    val attachments: List<Attachment> = emptyList(),
    val chatId: String? = null,
    val replyTo: Long? = null,
    val sendAt: String? = null,
    val expiresAt: String? = null
)

data class Chat(val id: String, val kind: String, val title: String, val description: String?, val owner: String, val avatarUrl: String? = null, val inviteCode: String? = null, val pinnedMsg: Long? = null, val disappearSec: Int? = null) {
    fun asProfile() = Profile(id, title, avatarUrl, null)
}

data class Member(val chatId: String, val userId: String, val role: String, val lastRead: Long)

data class Wallet(val balance: Int, val earned: Int, val streak: Int, val level: Int)

data class ThemeColor(val id: Long, val color: String?)

data class BoardRow(val userId: String, val nick: String, val avatarUrl: String?, val earned: Int, val level: Int)

fun parseWallet(o: JSONObject) = Wallet(o.optInt("balance"), o.optInt("earned"), o.optInt("streak"), o.optInt("level"))

fun levelStr(n: Int): String = String.format(java.util.Locale.US, "%.2f", n / 100.0)

data class ChatPref(val key: String, val muted: Boolean, val pinned: Boolean, val folder: String? = null)

data class DmPref(val userA: String, val userB: String, val disappearSec: Int?)

data class Sticker(val id: Long, val path: String)

data class Reaction(val messageId: Long, val userId: String, val emoji: String)

fun parseChat(o: JSONObject) = Chat(
    o.getString("id"), o.getString("kind"), o.optString("title", ""), o.str("description"), o.getString("owner"),
    o.str("avatar_url"), o.str("invite_code"), if (o.isNull("pinned_msg")) null else o.optLong("pinned_msg"),
    if (o.isNull("disappear_sec")) null else o.optInt("disappear_sec")
)

fun parseChatPref(o: JSONObject) = ChatPref(o.getString("key"), o.optBoolean("muted", false), o.optBoolean("pinned", false), o.str("folder"))

fun parseDmPref(o: JSONObject) = DmPref(o.getString("user_a"), o.getString("user_b"), if (o.isNull("disappear_sec")) null else o.optInt("disappear_sec"))

fun parseMember(o: JSONObject) = Member(o.getString("chat_id"), o.getString("user_id"), o.optString("role", "member"), o.optLong("last_read", 0L))

fun parseReaction(o: JSONObject) = Reaction(o.getLong("message_id"), o.getString("user_id"), o.getString("emoji"))

fun parseProfile(o: JSONObject) = Profile(
    o.getString("id"), o.getString("nick"), o.str("avatar_url"), o.str("created_at"),
    o.str("last_seen"), o.str("typing_to"), o.str("typing_at")
)

fun parseFriendship(o: JSONObject) =
    Friendship(o.getLong("id"), o.getString("requester"), o.getString("addressee"), o.getString("status"))

fun parseMessage(o: JSONObject) = Message(
    o.getLong("id"), o.getString("sender"), o.str("receiver"), o.optString("kind", "text"),
    o.str("body"), o.str("media_path"), o.str("file_name"), o.getString("created_at"), o.str("read_at"), o.str("edited_at"),
    parseAttachments(o),
    o.str("chat_id"),
    if (o.isNull("reply_to")) null else o.optLong("reply_to"),
    o.str("send_at"),
    o.str("expires_at")
)

private fun parseAttachments(o: JSONObject): List<Attachment> {
    val arr = o.optJSONArray("attachments") ?: return emptyList()
    val out = ArrayList<Attachment>()
    for (i in 0 until arr.length()) {
        val a = arr.optJSONObject(i) ?: continue
        val path = a.optString("path", "")
        if (path.isEmpty()) continue
        out.add(Attachment(path, a.optString("name", "file"), a.optString("type", "file"), a.optString("mime", "")))
    }
    return out
}

/** Имя Material-иконки для превью сообщения в списке чатов, если есть. */
fun previewIconOf(m: Message?): String? {
    if (m == null) return null
    return when (m.kind) {
        "image" -> if ((m.fileName ?: "").startsWith("sticker.")) "tag" else "photo"
        "file" -> "attach"
        "album" -> {
            val a = m.attachments
            when {
                a.isNotEmpty() && a.all { it.type == "voice" } -> "mic"
                a.isNotEmpty() && a.all { it.type == "image" } -> "photo"
                a.isNotEmpty() && a.all { it.type == "video" } -> "video"
                else -> "attach"
            }
        }
        else -> null
    }
}

/** Короткое описание сообщения для списка чатов и уведомлений. */
fun previewOf(m: Message?): String {
    if (m == null) return tr("Нет сообщений", "No messages", "Keine Nachrichten")
    return when (m.kind) {
        "image" -> if ((m.fileName ?: "").startsWith("sticker.")) tr("Стикер", "Sticker", "Sticker") else tr("Фото", "Photo", "Foto")
        "file" -> m.fileName ?: tr("Файл", "File", "Datei")
        "album" -> {
            val a = m.attachments
            val base = when {
                a.isNotEmpty() && a.all { it.type == "voice" } -> tr("Голосовое сообщение", "Voice message", "Sprachnachricht")
                a.isNotEmpty() && a.all { it.type == "image" } -> tr("Фото", "Photo", "Foto") + (if (a.size > 1) " (${a.size})" else "")
                a.isNotEmpty() && a.all { it.type == "video" } -> tr("Видео", "Video", "Video") + (if (a.size > 1) " (${a.size})" else "")
                else -> tr("Вложения", "Attachments", "Anhänge") + " (${a.size})"
            }
            if (m.body.isNullOrEmpty()) base else base + ": " + m.body
        }
        else -> m.body ?: ""
    }
}

fun isFuture(iso: String?): Boolean = try {
    iso != null && OffsetDateTime.parse(iso).toInstant().isAfter(java.time.Instant.now())
} catch (e: Exception) {
    false
}

fun timeOf(iso: String): String = try {
    OffsetDateTime.parse(iso).atZoneSameInstant(ZoneId.systemDefault()).format(DateTimeFormatter.ofPattern("HH:mm"))
} catch (e: Exception) {
    ""
}

fun daysSince(iso: String?): Int = try {
    if (iso == null) 1 else {
        val d = java.time.temporal.ChronoUnit.DAYS.between(OffsetDateTime.parse(iso).toInstant(), java.time.Instant.now())
        maxOf(1, d.toInt() + 1)
    }
} catch (e: Exception) {
    1
}

private fun isEmoCp(c: Int) = c in 0x1F000..0x1FFFF || c in 0x2190..0x2BFF || c == 0xA9 || c == 0xAE || c in 0x203C..0x3299

/** Сообщение из 1–5 эмодзи показываем крупно (встроенный стикер). */
fun isBigEmoji(b: String?): Boolean {
    if (b == null || b.length > 24 || b.isBlank()) return false
    var n = 0
    var i = 0
    while (i < b.length) {
        val c = b.codePointAt(i)
        i += Character.charCount(c)
        if (c == 0x200D || c == 0xFE0F || Character.isWhitespace(c)) continue
        if (!isEmoCp(c)) return false
        n++
    }
    return n in 1..5
}

fun isSticker(m: Message) = m.kind == "image" && (m.fileName ?: "").startsWith("sticker.")
