package app.neirox

import android.content.Context
import android.content.SharedPreferences
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

    suspend fun request(method: String, path: String, json: JSONObject? = null, auth: Boolean = true): String {
        if (auth) refreshIfNeeded()
        return withContext(Dispatchers.IO) {
            try {
                val c = URL(Cfg.URL + path).openConnection() as HttpURLConnection
                c.requestMethod = method
                c.connectTimeout = 20_000
                c.readTimeout = 60_000
                c.setRequestProperty("apikey", Cfg.KEY)
                val token = prefs.getString("access", null)
                if (auth && token != null) c.setRequestProperty("Authorization", "Bearer $token")
                if (json != null) {
                    c.doOutput = true
                    c.setRequestProperty("Content-Type", "application/json")
                    c.outputStream.use { it.write(json.toString().toByteArray(Charsets.UTF_8)) }
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

    suspend fun fetchNick(): String {
        val t = request("GET", "/rest/v1/profiles?id=eq.${userId()}&select=nick")
        val a = JSONArray(t)
        return if (a.length() > 0) a.getJSONObject(0).getString("nick") else ""
    }
}
