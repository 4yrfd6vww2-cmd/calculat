package app.neirox

import android.content.Context
import android.media.RingtoneManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

object Store {
    lateinit var appCtx: Context

    var loggedIn by mutableStateOf(false)
        private set
    var me by mutableStateOf<Profile?>(null)
        private set
    var friendships by mutableStateOf<List<Friendship>>(emptyList())
        private set
    var profiles by mutableStateOf<Map<String, Profile>>(emptyMap())
        private set
    var messages by mutableStateOf<List<Message>>(emptyList())
        private set
    var recoveryEmail by mutableStateOf<String?>(null)
        private set
    var hidden by mutableStateOf<Set<Long>>(emptySet())
        private set

    @Volatile
    var appVisible = false
    private var initialized = false

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null
    private var known = emptySet<Long>()
    private var firstLoad = false

    val myId: String get() = Api.userId()

    fun init(ctx: Context) {
        if (initialized) return
        initialized = true
        appCtx = ctx.applicationContext
        loggedIn = Api.isLoggedIn()
        if (loggedIn) start()
    }

    fun onLogin() {
        loggedIn = true
        start()
        NeiroxService.start(appCtx)
    }

    fun logout() {
        job?.cancel()
        job = null
        Api.signOut()
        Player.stopAll()
        NeiroxService.stop(appCtx)
        Notif.clearMessages(appCtx)
        me = null
        friendships = emptyList()
        profiles = emptyMap()
        messages = emptyList()
        recoveryEmail = null
        known = emptySet()
        firstLoad = false
        loggedIn = false
    }

    private fun start() {
        if (job?.isActive == true) return
        job = scope.launch {
            while (isActive) {
                refresh()
                delay(4000)
            }
        }
    }

    suspend fun refresh() {
        if (!Api.isLoggedIn()) {
            if (loggedIn) logout()
            return
        }
        val uid = myId
        try {
            val mine = Api.select("profiles?id=eq.$uid&select=*")
            me = if (mine.length() > 0) parseProfile(mine.getJSONObject(0)) else null

            val fr = Api.select("friendships?select=*")
            friendships = (0 until fr.length()).map { parseFriendship(fr.getJSONObject(it)) }

            val ms = Api.select("messages?select=*&order=created_at.desc&limit=1000")
            val list = (0 until ms.length()).map { parseMessage(ms.getJSONObject(it)) }
            try {
                val hid = Api.select("message_hidden?select=message_id")
                hidden = (0 until hid.length()).map { hid.getJSONObject(it).getLong("message_id") }.toSet()
            } catch (e: ApiError) {
            }
            notifyNew(list)
            messages = list.filter { it.id !in hidden }.reversed()

            val ids = HashSet<String>()
            for (f in friendships) { ids.add(f.requester); ids.add(f.addressee) }
            for (m in list) { ids.add(m.sender); ids.add(m.receiver) }
            ids.remove(uid)
            val map = HashMap(profiles)
            if (ids.isNotEmpty()) {
                val ps = Api.select("profiles?id=in.(${ids.joinToString(",")})&select=*")
                for (i in 0 until ps.length()) {
                    val p = parseProfile(ps.getJSONObject(i))
                    map[p.id] = p
                }
            }
            me?.let { map[it.id] = it }
            profiles = map
        } catch (e: ApiError) {
            if (!Api.isLoggedIn() && loggedIn) {
                logout()
                return
            }
        }
        if (recoveryEmail == null) {
            try { reloadRecoveryEmail() } catch (e: ApiError) { }
        }
        try {
            Api.update("profiles?id=eq.$uid", JSONObject().put("last_seen", Instant.now().toString()))
        } catch (e: ApiError) {
        }
    }

    suspend fun reloadRecoveryEmail() {
        val a = Api.select("private_profiles?user_id=eq.$myId&select=recovery_email")
        recoveryEmail = if (a.length() > 0) a.getJSONObject(0).optString("recovery_email", "").ifEmpty { null } else null
    }

    private fun notifyNew(list: List<Message>) {
        val ids = list.map { it.id }.toSet()
        if (firstLoad) {
            val fresh = list.filter { it.id !in known && it.receiver == myId }
            if (fresh.isNotEmpty()) {
                if (appVisible) {
                    if (Settings.sound) {
                        try {
                            RingtoneManager.getRingtone(
                                appCtx, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            )?.play()
                        } catch (e: Exception) {
                        }
                    }
                } else {
                    for ((sender, group) in fresh.groupBy { it.sender }) {
                        val last = group.maxByOrNull { it.createdAt } ?: continue
                        val preview = when (last.kind) {
                            "image" -> "🖼 " + tr("Фото", "Photo", "Foto")
                            "file" -> "📎 " + (last.fileName ?: tr("Файл", "File", "Datei"))
                            else -> last.body ?: ""
                        }
                        val text = if (group.size > 1) {
                            tr("Новых: ${group.size}. ", "New: ${group.size}. ", "Neu: ${group.size}. ") + preview
                        } else preview
                        Notif.message(appCtx, sender, profiles[sender]?.nick ?: "neirox", text)
                    }
                }
            }
        }
        known = ids
        firstLoad = true
    }

    // Друзья

    val friendIds: List<String>
        get() = friendships.filter { it.status == "accepted" }
            .map { if (it.requester == myId) it.addressee else it.requester }
    val incoming: List<Friendship> get() = friendships.filter { it.status == "pending" && it.addressee == myId }
    val outgoing: List<Friendship> get() = friendships.filter { it.status == "pending" && it.requester == myId }

    fun friendship(with: String): Friendship? = friendships.firstOrNull {
        (it.requester == with && it.addressee == myId) || (it.requester == myId && it.addressee == with)
    }

    suspend fun search(q: String): List<Profile> {
        val clean = q.lowercase().filter { it.isLetterOrDigit() || it == '_' }
        if (clean.length < 2) return emptyList()
        return try {
            val a = Api.select("profiles?nick=ilike.*$clean*&id=neq.$myId&select=*&limit=20")
            (0 until a.length()).map { parseProfile(a.getJSONObject(it)) }
        } catch (e: ApiError) {
            emptyList()
        }
    }

    suspend fun sendRequest(to: String) {
        Api.insert("friendships", JSONObject().put("requester", myId).put("addressee", to).put("status", "pending"))
        refresh()
    }

    suspend fun accept(f: Friendship) {
        Api.update("friendships?id=eq.${f.id}", JSONObject().put("status", "accepted"))
        refresh()
    }

    suspend fun removeFriendship(f: Friendship) {
        Api.delete("friendships?id=eq.${f.id}")
        refresh()
    }

    // Сообщения

    fun thread(with: String): List<Message> = messages.filter {
        (it.sender == with && it.receiver == myId) || (it.sender == myId && it.receiver == with)
    }

    fun unread(from: String): Int = messages.count { it.sender == from && it.receiver == myId && it.readAt == null }

    val totalUnread: Int get() = messages.count { it.receiver == myId && it.readAt == null }

    suspend fun sendText(text: String, to: String) {
        Api.insert("messages", JSONObject().put("sender", myId).put("receiver", to).put("kind", "text").put("body", text))
        refresh()
    }

    suspend fun sendMedia(data: ByteArray, mime: String, fileName: String, kind: String, to: String) {
        val ext = fileName.substringAfterLast('.', "")
        val path = "$myId/${UUID.randomUUID()}" + (if (ext.isEmpty()) "" else ".$ext")
        Api.upload("chat-media", path, data, mime)
        Api.insert(
            "messages",
            JSONObject().put("sender", myId).put("receiver", to).put("kind", kind)
                .put("media_path", path).put("file_name", fileName)
        )
        refresh()
    }

    suspend fun markRead(from: String) {
        if (unread(from) == 0) return
        Api.update(
            "messages?sender=eq.$from&receiver=eq.$myId&read_at=is.null",
            JSONObject().put("read_at", Instant.now().toString())
        )
        refresh()
    }

    suspend fun editMessage(id: Long, text: String) {
        Api.update("messages?id=eq.$id", JSONObject().put("body", text).put("edited_at", Instant.now().toString()))
        refresh()
    }

    suspend fun deleteForAll(list: List<Message>) {
        for (m in list) {
            if (m.sender != myId) continue
            Api.delete("messages?id=eq.${m.id}")
            m.mediaPath?.let {
                try {
                    Api.request("DELETE", "/storage/v1/object/chat-media/$it")
                } catch (e: ApiError) {
                }
            }
        }
        refresh()
    }

    suspend fun deleteForMe(list: List<Message>) {
        for (m in list) {
            Api.insert("message_hidden", JSONObject().put("message_id", m.id))
        }
        hidden = hidden + list.map { it.id }
        messages = messages.filter { it.id !in hidden }
        refresh()
    }

    suspend fun forward(m: Message, to: String) {
        val path = m.mediaPath
        if (m.kind == "text" || path == null) {
            val t = m.body ?: ""
            if (t.isNotEmpty()) sendText(t, to)
            return
        }
        val bytes = Api.download(Api.signedUrl("chat-media", path))
        val name = m.fileName ?: "file"
        val mime = if (m.kind == "image") "image/jpeg" else
            (android.webkit.MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase()) ?: "application/octet-stream")
        sendMedia(bytes, mime, name, m.kind, to)
    }

    // Профиль

    suspend fun changeNick(nick: String) {
        Api.changeNick(nick)
        refresh()
    }

    suspend fun bindEmail(email: String) {
        val e = email.trim().lowercase()
        Api.insert("private_profiles", JSONObject().put("user_id", myId).put("recovery_email", e))
        recoveryEmail = e
    }

    suspend fun uploadAvatar(data: ByteArray) {
        val path = "$myId/avatar.jpg"
        Api.upload("avatars", path, data, "image/jpeg", upsert = true)
        val url = Api.publicUrl("avatars", path) + "?v=${System.currentTimeMillis() / 1000}"
        Api.update("profiles?id=eq.$myId", JSONObject().put("avatar_url", url))
        refresh()
    }
}
