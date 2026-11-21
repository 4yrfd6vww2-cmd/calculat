package app.neirox

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class NeiroxApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Api.init(this)
        Settings.init(this)
        Player.init(this)
        Store.init(this)
    }
}

const val ACT_PREV = "app.neirox.PREV"
const val ACT_TOGGLE = "app.neirox.TOGGLE"
const val ACT_NEXT = "app.neirox.NEXT"

object Notif {
    const val CH_SERVICE = "service"
    const val CH_MSG = "messages"
    const val ID_SERVICE = 1

    fun channels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CH_SERVICE, tr("Работа в фоне", "Background", "Hintergrund"), NotificationManager.IMPORTANCE_LOW)
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_MSG, tr("Сообщения", "Messages", "Nachrichten"), NotificationManager.IMPORTANCE_HIGH)
        )
    }

    private fun openApp(ctx: Context): PendingIntent = PendingIntent.getActivity(
        ctx, 0,
        Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    private fun action(ctx: Context, icon: Int, title: String, act: String): Notification.Action {
        val pi = PendingIntent.getBroadcast(
            ctx, act.hashCode(),
            Intent(ctx, MediaActionReceiver::class.java).setAction(act),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return Notification.Action.Builder(Icon.createWithResource(ctx, icon), title, pi).build()
    }

    fun service(ctx: Context): Notification {
        val b = Notification.Builder(ctx, CH_SERVICE)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentIntent(openApp(ctx))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        val title = Player.currentTitle
        if (title != null) {
            b.setContentTitle(title).setContentText("neirox")
            b.addAction(action(ctx, android.R.drawable.ic_media_previous, "◀◀", ACT_PREV))
            b.addAction(
                action(
                    ctx,
                    if (Player.playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                    if (Player.playing) "❚❚" else "▶",
                    ACT_TOGGLE
                )
            )
            b.addAction(action(ctx, android.R.drawable.ic_media_next, "▶▶", ACT_NEXT))
            b.setStyle(Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2))
        } else {
            b.setContentTitle("neirox")
            b.setContentText(tr("Работает в фоне, чтобы приходили сообщения", "Running in background to receive messages", "Läuft im Hintergrund, um Nachrichten zu empfangen"))
        }
        return b.build()
    }

    fun update(ctx: Context) {
        if (!NeiroxService.running) return
        ctx.getSystemService(NotificationManager::class.java).notify(ID_SERVICE, service(ctx))
    }

    fun message(ctx: Context, senderId: String, nick: String, text: String) {
        val n = NotificationCompat.Builder(ctx, CH_MSG)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle(nick)
            .setContentText(text)
            .setAutoCancel(true)
            .setSilent(!Settings.sound)
            .setContentIntent(openApp(ctx))
            .build()
        try {
            ctx.getSystemService(NotificationManager::class.java).notify(senderId.hashCode(), n)
        } catch (e: Exception) {
        }
    }

    fun clearMessages(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        try {
            for (n in nm.activeNotifications) if (n.id != ID_SERVICE) nm.cancel(n.id)
        } catch (e: Exception) {
        }
    }
}

class NeiroxService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Notif.channels(this)
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(Notif.ID_SERVICE, Notif.service(this))
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    companion object {
        @Volatile
        var running = false

        fun start(ctx: Context) {
            try {
                ContextCompat.startForegroundService(ctx, Intent(ctx, NeiroxService::class.java))
            } catch (e: Exception) {
            }
        }

        fun stop(ctx: Context) {
            try {
                ctx.stopService(Intent(ctx, NeiroxService::class.java))
            } catch (e: Exception) {
            }
        }
    }
}

class MediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACT_PREV -> Player.prev()
            ACT_TOGGLE -> Player.toggle()
            ACT_NEXT -> Player.next()
        }
    }
}
