package app.neirox

import org.json.JSONObject
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private fun JSONObject.str(k: String): String? = if (isNull(k)) null else optString(k, "").ifEmpty { null }

data class Profile(val id: String, val nick: String, val avatarUrl: String?, val createdAt: String?)

data class Friendship(val id: Long, val requester: String, val addressee: String, val status: String)

data class Message(
    val id: Long,
    val sender: String,
    val receiver: String,
    val kind: String,
    val body: String?,
    val mediaPath: String?,
    val fileName: String?,
    val createdAt: String,
    val readAt: String?
)

fun parseProfile(o: JSONObject) = Profile(o.getString("id"), o.getString("nick"), o.str("avatar_url"), o.str("created_at"))

fun parseFriendship(o: JSONObject) =
    Friendship(o.getLong("id"), o.getString("requester"), o.getString("addressee"), o.getString("status"))

fun parseMessage(o: JSONObject) = Message(
    o.getLong("id"), o.getString("sender"), o.getString("receiver"), o.optString("kind", "text"),
    o.str("body"), o.str("media_path"), o.str("file_name"), o.getString("created_at"), o.str("read_at")
)

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
