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
    var chats by mutableStateOf<List<Chat>>(emptyList())
        private set
    var members by mutableStateOf<List<Member>>(emptyList())
        private set
    var reactions by mutableStateOf<List<Reaction>>(emptyList())

    var prefs by mutableStateOf<Map<String, ChatPref>>(emptyMap())

    var jumpTo by mutableStateOf<Long?>(null)

    var alias by mutableStateOf<Map<String, String>>(emptyMap())

    var wallet by mutableStateOf<Wallet?>(null)
    var colors by mutableStateOf<List<ThemeColor>>(emptyList())
    var levels by mutableStateOf<Map<String, Int>>(emptyMap())
    var board by mutableStateOf<List<BoardRow>>(emptyList())
    private var checkedAt = 0L

    var stickers by mutableStateOf<List<Sticker>>(emptyList())
    private var stkLoaded = false
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
        Calls.init(appCtx)
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
        Calls.reset()
        Api.signOut()
        Player.stopAll()
        NeiroxService.stop(appCtx)
        Notif.clearMessages(appCtx)
        me = null
        friendships = emptyList()
        profiles = emptyMap()
        messages = emptyList()
        chats = emptyList()
        members = emptyList()
        reactions = emptyList()
        prefs = emptyMap()
        alias = emptyMap()
        wallet = null
        colors = emptyList()
        levels = emptyMap()
        board = emptyList()
        checkedAt = 0L
        stickers = emptyList()
        stkLoaded = false
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

            try {
                val mm = Api.select("chat_members?select=*")
                members = (0 until mm.length()).map { parseMember(mm.getJSONObject(it)) }
                val ck = members.map { it.chatId }.distinct()
                if (ck.isNotEmpty()) {
                    val cc = Api.select("chats?id=in.(${ck.joinToString(",")})&select=*")
                    chats = (0 until cc.length()).map { parseChat(cc.getJSONObject(it)) }
                } else chats = emptyList()
            } catch (e: ApiError) {
            }
            try {
                val cn = Api.select("contact_names?select=*")
                alias = (0 until cn.length()).associate { cn.getJSONObject(it).getString("contact_id") to cn.getJSONObject(it).getString("name") }
            } catch (e: ApiError) {
            }
            try {
                val pr = Api.select("chat_prefs?select=*")
                prefs = (0 until pr.length()).associate {
                    val o = pr.getJSONObject(it)
                    o.getString("key") to ChatPref(o.getString("key"), o.optBoolean("muted", false), o.optBoolean("pinned", false))
                }
            } catch (e: ApiError) {
            }
            if (!stkLoaded) {
                try {
                    val st = Api.select("my_stickers?select=*&order=id.desc")
                    stickers = (0 until st.length()).map { Sticker(st.getJSONObject(it).getLong("id"), st.getJSONObject(it).getString("path")) }
                    stkLoaded = true
                } catch (e: ApiError) {
                }
            }
            val ms = Api.select("messages?select=*&order=created_at.desc&limit=1000")
            val list = (0 until ms.length()).map { parseMessage(ms.getJSONObject(it)) }
            try {
                val hid = Api.select("message_hidden?select=message_id")
                hidden = (0 until hid.length()).map { hid.getJSONObject(it).getLong("message_id") }.toSet()
            } catch (e: ApiError) {
            }
            notifyNew(list)
            messages = list.filter { it.id !in hidden }.reversed()
            try {
                val rr = Api.select("message_reactions?select=*&limit=3000")
                reactions = (0 until rr.length()).map { parseReaction(rr.getJSONObject(it)) }
            } catch (e: ApiError) {
            }

            val ids = HashSet<String>()
            for (f in friendships) { ids.add(f.requester); ids.add(f.addressee) }
            for (m in list) { ids.add(m.sender); m.receiver?.let { ids.add(it) } }
            for (mb in members) ids.add(mb.userId)
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
            try { noxSync(map.keys.toList()) } catch (e: Exception) { }
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
            val fresh = list.filter { it.id !in known && it.sender != myId && (it.receiver == myId || (it.chatId != null && isMember(it.chatId))) && muted(it) }
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
                    for ((key, group) in fresh.groupBy { if (it.chatId != null) "c:" + it.chatId else it.sender }) {
                        val last = group.maxByOrNull { it.createdAt } ?: continue
                        val sender = key
                        val title = if (last.chatId != null) (chatByKey(key)?.title ?: "neirox") else (profiles[last.sender]?.let { dname(it) } ?: "neirox")
                        val preview = previewOf(last)
                        val text = if (group.size > 1) {
                            tr("Новых: ${group.size}. ", "New: ${group.size}. ", "Neu: ${group.size}. ") + preview
                        } else preview
                        Notif.message(appCtx, sender, title, text)
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

    fun isKey(k: String) = k.startsWith("c:")
    fun cidOf(k: String) = k.removePrefix("c:")
    fun chatByKey(k: String): Chat? = if (isKey(k)) chats.firstOrNull { it.id == cidOf(k) } else null
    fun isMember(cid: String) = members.any { it.chatId == cid && it.userId == myId }
    fun myMember(k: String): Member? = members.firstOrNull { it.chatId == cidOf(k) && it.userId == myId }
    fun memberCount(k: String) = members.count { it.chatId == cidOf(k) }
    // nox

    private suspend fun loadColors() {
        val a = Api.select("theme_colors?select=*&order=id.asc")
        colors = (0 until a.length()).map { ThemeColor(a.getJSONObject(it).getLong("id"), if (a.getJSONObject(it).isNull("color")) null else a.getJSONObject(it).getString("color")) }
    }

    private suspend fun noxSync(ids: List<String>) {
        if (checkedAt == 0L || System.currentTimeMillis() - checkedAt > 30 * 60 * 1000) {
            checkedAt = System.currentTimeMillis()
            val o = JSONObject(Api.request("POST", "/rest/v1/rpc/nox_checkin", JSONObject()))
            wallet = parseWallet(o)
            if (o.optBoolean("awarded")) {
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    android.widget.Toast.makeText(appCtx, tr("+5 nox за 3 дня подряд! ⚡", "+5 nox for 3 days in a row! ⚡", "+5 nox für 3 Tage in Folge! ⚡"), android.widget.Toast.LENGTH_LONG).show()
                }
            }
            loadColors()
        }
        val all = (ids + myId).distinct()
        if (all.isNotEmpty()) {
            val a = Api.select("nox_wallets?select=user_id,level&user_id=in.(${all.joinToString(",")})")
            levels = (0 until a.length()).associate { a.getJSONObject(it).getString("user_id") to a.getJSONObject(it).optInt("level") }
        }
    }

    fun levelTag(id: String): String {
        val l = levels[id] ?: 0
        return if (l > 0) " · ★ " + levelStr(l) else ""
    }

    suspend fun noxOpen() {
        wallet = parseWallet(JSONObject(Api.request("POST", "/rest/v1/rpc/nox_me", JSONObject())))
        val b = org.json.JSONArray(Api.request("POST", "/rest/v1/rpc/nox_leaderboard", JSONObject()))
        board = (0 until b.length()).map {
            val o = b.getJSONObject(it)
            BoardRow(o.getString("user_id"), o.optString("nick", ""), if (o.isNull("avatar_url")) null else o.optString("avatar_url"), o.optInt("earned"), o.optInt("level"))
        }
        loadColors()
    }

    suspend fun buyColor(): Long {
        val id = Api.request("POST", "/rest/v1/rpc/nox_buy_color", JSONObject()).trim().toLong()
        noxOpen()
        return id
    }

    suspend fun setColor(id: Long, hex: String) {
        Api.request("POST", "/rest/v1/rpc/nox_set_color", JSONObject().put("p_id", id).put("p_color", hex))
        loadColors()
    }

    suspend fun buyLevel(units: Int) {
        wallet = parseWallet(JSONObject(Api.request("POST", "/rest/v1/rpc/nox_buy_level", JSONObject().put("p_units", units))))
        noxOpen()
        try { noxSync(profiles.keys.toList()) } catch (e: Exception) { }
    }

    /** Имя контакта: своё, если задано, иначе ник. */
    fun dname(p: Profile?): String = if (p == null) "" else (alias[p.id] ?: p.nick)
    fun dname(id: String): String = dname(profiles[id])

    suspend fun setAlias(id: String, name: String) {
        val v = name.trim()
        if (v.isEmpty()) {
            Api.delete("contact_names?user_id=eq.$myId&contact_id=eq.$id")
            alias = alias - id
        } else {
            if (alias.containsKey(id)) Api.update("contact_names?user_id=eq.$myId&contact_id=eq.$id", JSONObject().put("name", v))
            else Api.insert("contact_names", JSONObject().put("user_id", myId).put("contact_id", id).put("name", v))
            alias = alias + (id to v)
        }
    }

    fun isMuted(k: String) = prefs[k]?.muted == true
    fun isPinned(k: String) = prefs[k]?.pinned == true
    private fun muted(m: Message) = !isMuted(if (m.chatId != null) "c:" + m.chatId else m.sender)

    suspend fun setPref(k: String, field: String, v: Boolean) {
        val cur = prefs[k]
        if (cur != null) Api.update("chat_prefs?user_id=eq.$myId&key=eq.$k", JSONObject().put(field, v))
        else Api.insert("chat_prefs", JSONObject().put("user_id", myId).put("key", k).put(field, v))
        val n = ChatPref(k, if (field == "muted") v else (cur?.muted ?: false), if (field == "pinned") v else (cur?.pinned ?: false))
        prefs = prefs + (k to n)
    }

    suspend fun pinMessage(cid: String, mid: Long?) {
        Api.update("chats?id=eq.$cid", JSONObject().put("pinned_msg", mid ?: JSONObject.NULL))
        refresh()
    }

    suspend fun setDescription(cid: String, d: String) {
        Api.update("chats?id=eq.$cid", JSONObject().put("description", d.ifBlank { JSONObject.NULL }))
        refresh()
    }

    suspend fun joinByCode(code: String): String {
        val r = Api.request("POST", "/rest/v1/rpc/join_by_code", JSONObject().put("code", code.trim()))
        refresh()
        return r.trim().trim('"')
    }

    suspend fun channelCounts(ids: List<String>): Map<String, Int> {
        if (ids.isEmpty()) return emptyMap()
        return try {
            val a = org.json.JSONArray(Api.request("POST", "/rest/v1/rpc/channel_counts", JSONObject().put("ids", org.json.JSONArray(ids))))
            (0 until a.length()).associate { a.getJSONObject(it).getString("chat_id") to a.getJSONObject(it).optInt("n") }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    suspend fun addSticker(data: ByteArray, mime: String, ext: String) {
        val path = "$myId/stickers/${UUID.randomUUID()}.$ext"
        Api.upload("chat-media", path, data, mime)
        Api.insert("my_stickers", JSONObject().put("path", path))
        stkLoaded = false
        refresh()
    }

    suspend fun deleteSticker(id: Long) {
        Api.delete("my_stickers?id=eq.$id")
        stickers = stickers.filter { it.id != id }
    }

    suspend fun sendSticker(path: String, to: String, reply: Long? = null) {
        val ext = path.substringAfterLast('.', "png")
        val o = tgt(to, JSONObject().put("sender", myId).put("kind", "image").put("media_path", path).put("file_name", "sticker.$ext"))
        if (reply != null) o.put("reply_to", reply)
        Api.insert("messages", o)
        refresh()
    }

    fun canPost(k: String): Boolean {
        val c = chatByKey(k) ?: return true
        if (c.kind != "channel") return myMember(k) != null
        val r = myMember(k)?.role
        return r == "owner" || r == "admin"
    }

    private fun tgt(to: String, o: JSONObject): JSONObject =
        if (isKey(to)) o.put("chat_id", cidOf(to)) else o.put("receiver", to)

    fun thread(with: String): List<Message> =
        if (isKey(with)) messages.filter { it.chatId == cidOf(with) }
        else messages.filter { (it.sender == with && it.receiver == myId) || (it.sender == myId && it.receiver == with) }

    fun unread(from: String): Int {
        if (isKey(from)) {
            val lr = myMember(from)?.lastRead ?: 0L
            return messages.count { it.chatId == cidOf(from) && it.sender != myId && it.id > lr }
        }
        return messages.count { it.sender == from && it.receiver == myId && it.readAt == null }
    }

    val totalUnread: Int
        get() = messages.count { it.receiver == myId && it.readAt == null } +
            chats.sumOf { unread("c:" + it.id) }

    fun reactionsOf(id: Long) = reactions.filter { it.messageId == id }

    suspend fun react(id: Long, emoji: String) {
        val mine = reactions.firstOrNull { it.messageId == id && it.userId == myId }
        if (mine != null) Api.delete("message_reactions?message_id=eq.$id&user_id=eq.$myId")
        if (mine == null || mine.emoji != emoji) {
            Api.insert("message_reactions", JSONObject().put("message_id", id).put("user_id", myId).put("emoji", emoji))
        }
        refresh()
    }

    // Группы и каналы

    suspend fun createChat(kind: String, title: String, friendIds: List<String>, desc: String = ""): String {
        val id = UUID.randomUUID().toString()
        val row = JSONObject().put("id", id).put("kind", kind).put("title", title).put("owner", myId)
        if (desc.isNotBlank()) row.put("description", desc.trim())
        Api.insert("chats", row)
        for (f in friendIds) {
            try { Api.insert("chat_members", JSONObject().put("chat_id", id).put("user_id", f).put("role", "member")) } catch (e: ApiError) { }
        }
        refresh()
        return "c:$id"
    }

    suspend fun findChannels(q: String): List<Chat> {
        val clean = q.trim().replace("*", "").replace(",", " ").replace("(", "").replace(")", "")
        if (clean.isEmpty()) return emptyList()
        return try {
            val a = Api.select("chats?kind=eq.channel&title=ilike.*" + java.net.URLEncoder.encode(clean, "UTF-8") + "*&select=*&limit=20")
            (0 until a.length()).map { parseChat(a.getJSONObject(it)) }
        } catch (e: ApiError) {
            emptyList()
        }
    }

    suspend fun joinChat(cid: String) {
        Api.insert("chat_members", JSONObject().put("chat_id", cid).put("user_id", myId).put("role", "member"))
        refresh()
    }

    suspend fun leaveChat(cid: String) {
        Api.delete("chat_members?chat_id=eq.$cid&user_id=eq.$myId")
        refresh()
    }

    suspend fun addMember(cid: String, uid: String) {
        Api.insert("chat_members", JSONObject().put("chat_id", cid).put("user_id", uid).put("role", "member"))
        refresh()
    }

    suspend fun kickMember(cid: String, uid: String) {
        Api.delete("chat_members?chat_id=eq.$cid&user_id=eq.$uid")
        refresh()
    }

    suspend fun deleteChat(cid: String) {
        Api.delete("chats?id=eq.$cid")
        refresh()
    }

    suspend fun setRole(cid: String, uid: String, role: String) {
        Api.update("chat_members?chat_id=eq.$cid&user_id=eq.$uid", JSONObject().put("role", role))
        refresh()
    }

    suspend fun setChatAvatar(cid: String, data: ByteArray) {
        val path = "$myId/chat-$cid.jpg"
        Api.upload("avatars", path, data, "image/jpeg", upsert = true)
        val url = Api.publicUrl("avatars", path) + "?v=${System.currentTimeMillis() / 1000}"
        Api.update("chats?id=eq.$cid", JSONObject().put("avatar_url", url))
        refresh()
    }

    suspend fun renameChat(cid: String, title: String) {
        Api.update("chats?id=eq.$cid", JSONObject().put("title", title))
        refresh()
    }

    // Печатает / онлайн

    private var lastTyping = 0L

    fun sendTyping(to: String) {
        val now = System.currentTimeMillis()
        if (now - lastTyping < 3000) return
        lastTyping = now
        scope.launch {
            try {
                Api.update("profiles?id=eq.$myId", JSONObject().put("typing_to", to).put("typing_at", Instant.now().toString()))
            } catch (e: ApiError) {
            }
        }
    }

    private fun ageSec(iso: String?): Long = try {
        if (iso == null) 99999 else (System.currentTimeMillis() - java.time.OffsetDateTime.parse(iso).toInstant().toEpochMilli()) / 1000
    } catch (e: Exception) { 99999 }

    fun isTyping(p: Profile?, key: String): Boolean = p != null && p.typingTo == key && ageSec(p.typingAt) < 6

    fun isOnline(p: Profile?): Boolean = p != null && ageSec(p.lastSeen) < 15

    /** Кто печатает в чате key (кроме меня). */
    fun typingIn(key: String): List<Profile> =
        if (isKey(key)) profiles.values.filter { it.id != myId && isTyping(it, key) }
        else listOfNotNull(profiles[key]).filter { isTyping(it, myId) }

    fun statusLine(p: Profile?): String = when {
        p == null -> ""
        isOnline(p) -> tr("в сети", "online", "online")
        else -> tr("был(а) недавно", "last seen recently", "zuletzt online")
    }

    suspend fun sendText(text: String, to: String, reply: Long? = null) {
        val o = tgt(to, JSONObject().put("sender", myId).put("kind", "text").put("body", text))
        if (reply != null) o.put("reply_to", reply)
        Api.insert("messages", o)
        refresh()
    }

    suspend fun sendMedia(data: ByteArray, mime: String, fileName: String, kind: String, to: String, reply: Long? = null) {
        val ext = fileName.substringAfterLast('.', "")
        val path = "$myId/${UUID.randomUUID()}" + (if (ext.isEmpty()) "" else ".$ext")
        Api.upload("chat-media", path, data, mime)
        Api.insert(
            "messages",
            tgt(to, JSONObject().put("sender", myId).put("kind", kind)
                .put("media_path", path).put("file_name", fileName)).also { if (reply != null) it.put("reply_to", reply) }
        )
        refresh()
    }

    /** Одно вложение для отправки альбомом. kind: image / video / file / voice. */
    class OutItem(val data: ByteArray, val mime: String, val name: String, val kind: String)

    suspend fun sendAlbum(items: List<OutItem>, caption: String, to: String, reply: Long? = null) {
        val atts = org.json.JSONArray()
        for (it in items) {
            val ext = it.name.substringAfterLast('.', "")
            val path = "$myId/${UUID.randomUUID()}" + (if (ext.isEmpty()) "" else ".$ext")
            Api.upload("chat-media", path, it.data, it.mime)
            atts.put(JSONObject().put("path", path).put("name", it.name).put("type", it.kind).put("mime", it.mime).put("size", it.data.size))
        }
        val row = tgt(to, JSONObject().put("sender", myId).put("kind", "album").put("attachments", atts))
        if (reply != null) row.put("reply_to", reply)
        if (caption.isNotEmpty()) row.put("body", caption)
        Api.insert("messages", row)
        refresh()
    }

    suspend fun markRead(from: String) {
        if (unread(from) == 0) return
        if (isKey(from)) {
            val last = thread(from).maxOfOrNull { it.id } ?: return
            Api.update("chat_members?chat_id=eq.${cidOf(from)}&user_id=eq.$myId", JSONObject().put("last_read", last))
            refresh()
            return
        }
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
            val paths = (if (isSticker(m)) emptyList() else listOfNotNull(m.mediaPath)) + m.attachments.map { it.path }
            for (it in paths) {
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
        if (m.kind == "album") {
            val out = ArrayList<OutItem>()
            for (a in m.attachments) {
                val bytes = Api.download(Api.signedUrl("chat-media", a.path))
                out.add(OutItem(bytes, a.mime.ifEmpty { "application/octet-stream" }, a.name, a.type))
            }
            sendAlbum(out, m.body ?: "", to)
            return
        }
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
