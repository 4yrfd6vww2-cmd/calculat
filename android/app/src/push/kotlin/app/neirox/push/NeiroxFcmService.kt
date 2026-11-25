package app.neirox.push

import app.neirox.Notif
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class NeiroxFcmService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushBridge.uploadToken(token)
    }

    override fun onMessageReceived(msg: RemoteMessage) {
        val data = msg.data
        val senderId = data["sender"] ?: return
        val nick = data["nick"] ?: msg.notification?.title ?: ""
        val text = data["text"] ?: msg.notification?.body ?: ""
        Notif.message(applicationContext, senderId, nick, text)
    }
}
