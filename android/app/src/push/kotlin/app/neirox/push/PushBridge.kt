package app.neirox.push

import android.content.Context
import app.neirox.Api
import app.neirox.PushHook
import app.neirox.Store
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject

// Реальная FCM-реализация. Компилируется только для обычной сборки
// (см. sourceSets в app/build.gradle.kts, gradle -PoldAndroid=true его не видит),
// поэтому замороженная android_old сборка не получает ни этого кода, ни
// зависимости firebase-messaging.
object PushBridge {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    @Volatile private var lastToken: String? = null

    @JvmStatic
    fun install(ctx: Context) {
        PushHook.onReady = { refreshAndUpload() }
        PushHook.onLogout = { deleteCurrentToken() }
        if (Store.loggedIn) refreshAndUpload()
    }

    private fun refreshAndUpload() {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val t = task.result ?: return@addOnCompleteListener
                    uploadToken(t)
                }
            }
        } catch (e: Exception) {
        }
    }

    fun uploadToken(token: String) {
        lastToken = token
        if (!Store.loggedIn) return
        scope.launch {
            try {
                Api.upsert(
                    "push_tokens",
                    JSONObject().put("token", token).put("user_id", Store.myId).put("platform", "android")
                )
            } catch (e: Exception) {
            }
        }
    }

    private fun deleteCurrentToken() {
        val t = lastToken ?: return
        scope.launch {
            try {
                Api.delete("push_tokens?token=eq.$t")
            } catch (e: Exception) {
            }
        }
    }
}
