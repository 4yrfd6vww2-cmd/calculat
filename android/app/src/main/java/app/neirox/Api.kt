package app.neirox

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

object Cfg {
    const val URL = "https://seimbpskeemozcibybsy.supabase.co"
    const val KEY = "sb_publishable_h5MfmS1nk907f6_1gwjm-Q_7JsUwDpI"
}

class ApiError(message: String) : Exception(message)

object Api {
    private lateinit var prefs: SharedPreferences
    private var refreshing = false

    fun init(ctx: Context) {
        prefs = ctx.applicationContext.getSharedPreferences("neirox", Context.MODE_PRIVATE)
    }

    fun isLoggedIn(): Boolean = prefs.getString("access", null) != null
    fun userId(): String = prefs.getString("uid", "") ?: ""

    fun signOut() {
        prefs.edit().clear().apply()
    }

    private fun fakeEmail(nick: String) = nick.lowercase() + "@neirox.app"

    private fun saveSession(o: JSONObject) {
        val user = o.getJSONObject("user")
        val exp = System.currentTimeMillis() + (o.optDouble("expires_in", 3600.0) * 1000).toLong()
        prefs.edit()
            .putString("access", o.getString("access_token"))
            .putString("refresh", o.getString("refresh_token"))
            .putString("uid", user.getString("id"))
            .putLong("exp", exp)
            .apply()
    }

    private suspend fun refreshIfNeeded() {
        val refresh = prefs.getString("refresh", null) ?: return
        if (refreshing || prefs.getLong("exp", 0) - System.currentTimeMillis() > 60_000) return
        refreshing = true
        try {
            val t = request(
                "POST", "/auth/v1/token?grant_type=refresh_token",
                JSONObject().put("refresh_token", refresh), auth = false
            )
            saveSession(JSONObject(t))
        } catch (e: ApiError) {
            val m = (e.message ?: "").lowercase()
            if (m.contains("refresh") || m.contains("invalid")) signOut()
            throw e
        } finally {
            refreshing = false
        }
    }

    suspend fun call(
        method: String,
        path: String,
        body: ByteArray? = null,
        contentType: String? = null,
        headers: Map<String, String> = emptyMap(),
        auth: Boolean = true
    ): String {
        if (auth) refreshIfNeeded()
        return withContext(Dispatchers.IO) {
            try {
                val c = URL(Cfg.URL + path).openConnection() as HttpURLConnection
                c.requestMethod = method
                c.connectTimeout = 20_000
                c.readTimeout = 90_000
                c.setRequestProperty("apikey", Cfg.KEY)
                val token = prefs.getString("access", null)
                if (auth && token != null) c.setRequestProperty("Authorization", "Bearer $token")
                for ((k, v) in headers) c.setRequestProperty(k, v)
                if (body != null) {
                    c.doOutput = true
                    c.setRequestProperty("Content-Type", contentType ?: "application/octet-stream")
                    c.setFixedLengthStreamingMode(body.size)
                    c.outputStream.use { it.write(body) }
                }
                val code = c.responseCode
                val stream = if (code in 200..299) c.inputStream else c.errorStream
                val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
                c.disconnect()
                if (code in 200..299) text else throw ApiError(extractError(text, code))
            } catch (e: IOException) {
                throw ApiError("network")
            }
        }
    }

    suspend fun request(
        method: String,
        path: String,
        json: JSONObject? = null,
        auth: Boolean = true,
        headers: Map<String, String> = emptyMap()
    ): String = call(method, path, json?.toString()?.toByteArray(Charsets.UTF_8), "application/json", headers, auth)

    private fun extractError(text: String, code: Int): String {
        try {
            val o = JSONObject(text)
            for (k in listOf("error", "msg", "message", "error_description", "detail")) {
                val s = o.optString(k, "")
                if (s.isNotEmpty()) return s
            }
        } catch (_: Exception) {
        }
        return "HTTP $code"
    }

    // Auth

    suspend fun signIn(nick: String, password: String) {
        val body = JSONObject().put("email", fakeEmail(nick)).put("password", password)
        val t = request("POST", "/auth/v1/token?grant_type=password", body, auth = false)
        saveSession(JSONObject(t))
    }

    suspend fun register(nick: String, password: String, email: String) {
        val body = JSONObject().put("nick", nick).put("password", password)
        if (email.isNotEmpty()) body.put("email", email)
        request("POST", "/functions/v1/register", body, auth = false)
    }

    suspend fun recoverRequest(nick: String) {
        request(
            "POST", "/functions/v1/recover",
            JSONObject().put("action", "request").put("nick", nick), auth = false
        )
    }

    suspend fun recoverConfirm(nick: String, code: String, newPassword: String) {
        request(
            "POST", "/functions/v1/recover",
            JSONObject().put("action", "confirm").put("nick", nick)
                .put("code", code).put("new_password", newPassword),
            auth = false
        )
    }

    suspend fun changeNick(nick: String) {
        request("POST", "/functions/v1/account", JSONObject().put("action", "change_nick").put("nick", nick))
    }

    // REST

    suspend fun select(path: String): JSONArray = JSONArray(request("GET", "/rest/v1/$path"))

    suspend fun insert(table: String, row: JSONObject) {
        request("POST", "/rest/v1/$table", row, headers = mapOf("Prefer" to "return=minimal"))
    }

    suspend fun update(tableAndQuery: String, values: JSONObject) {
        request("PATCH", "/rest/v1/$tableAndQuery", values, headers = mapOf("Prefer" to "return=minimal"))
    }

    suspend fun delete(tableAndQuery: String) {
        request("DELETE", "/rest/v1/$tableAndQuery")
    }

    suspend fun upsert(table: String, row: JSONObject) {
        request("POST", "/rest/v1/$table", row, headers = mapOf("Prefer" to "resolution=merge-duplicates,return=minimal"))
    }

    // Storage

    suspend fun upload(bucket: String, path: String, data: ByteArray, mime: String, upsert: Boolean = false) {
        call(
            "POST", "/storage/v1/object/$bucket/$path", data, mime,
            mapOf("x-upsert" to (if (upsert) "true" else "false"))
        )
    }

    suspend fun signedUrl(bucket: String, path: String): String {
        val t = request("POST", "/storage/v1/object/sign/$bucket/$path", JSONObject().put("expiresIn", 3600))
        return Cfg.URL + "/storage/v1" + JSONObject(t).getString("signedURL")
    }

    fun publicUrl(bucket: String, path: String) = Cfg.URL + "/storage/v1/object/public/$bucket/$path"

    suspend fun download(url: String): ByteArray = withContext(Dispatchers.IO) {
        try {
            val c = URL(url).openConnection() as HttpURLConnection
            c.connectTimeout = 20_000
            c.readTimeout = 90_000
            if (c.responseCode !in 200..299) throw ApiError("HTTP ${c.responseCode}")
            val bytes = c.inputStream.use { it.readBytes() }
            c.disconnect()
            bytes
        } catch (e: IOException) {
            throw ApiError("network")
        }
    }

    // AI

    suspend fun aiText(messages: List<Pair<String, String>>): String {
        val arr = JSONArray()
        for ((role, content) in messages) arr.put(JSONObject().put("role", role).put("content", content))
        val t = request("POST", "/functions/v1/ai", JSONObject().put("type", "text").put("messages", arr))
        val o = JSONObject(t)
        val s = o.optString("text", "")
        if (s.isEmpty()) throw ApiError("Empty AI answer")
        return s
    }

    suspend fun aiImage(prompt: String): ByteArray {
        val t = request("POST", "/functions/v1/ai", JSONObject().put("type", "image").put("prompt", prompt))
        val b64 = JSONObject(t).optString("base64", "")
        if (b64.isEmpty()) throw ApiError("Empty AI image")
        return Base64.decode(b64, Base64.DEFAULT)
    }
}
