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
import android.os.Build
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
        // Push (FCM) живёт в отдельном source set и не собирается в android_old,
        // поэтому подключаем его через рефлексию: на старой сборке класса просто нет.
        try {
            Class.forName("app.neirox.push.PushBridge")
                .getMethod("install", Context::class.java)
                .invoke(null, this)
        } catch (e: Throwable) {
        }
    }
}

const val ACT_PREV = "app.neirox.PREV"
const val ACT_TOGGLE = "app.neirox.TOGGLE"
const val ACT_NEXT = "app.neirox.NEXT"

object Notif {
    const val CH_SERVICE = "service"
    const val CH_MSG = "messages"
    const val CH_CALL = "calls"
    const val ID_CALL = 2
    const val ID_SERVICE = 1

    private fun nm(ctx: Context): NotificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun channels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = nm(ctx)
        nm.createNotificationChannel(
            NotificationChannel(CH_SERVICE, tr("Работа в фоне", "Background", "Hintergrund"), NotificationManager.IMPORTANCE_LOW)
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_MSG, tr("Сообщения", "Messages", "Nachrichten"), NotificationManager.IMPORTANCE_HIGH)
        )
        val call = NotificationChannel(CH_CALL, tr("Звонки", "Calls", "Anrufe"), NotificationManager.IMPORTANCE_HIGH)
        call.setSound(null, null)
        nm.createNotificationChannel(call)
    }

    private fun openApp(ctx: Context): PendingIntent = PendingIntent.getActivity(
        ctx, 0,
        Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    private fun addAction(b: Notification.Builder, ctx: Context, icon: Int, title: String, act: String) {
        val pi = PendingIntent.getBroadcast(
            ctx, act.hashCode(),
            Intent(ctx, MediaActionReceiver::class.java).setAction(act),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        if (Build.VERSION.SDK_INT >= 23) {
            b.addAction(Notification.Action.Builder(Icon.createWithResource(ctx, icon), title, pi).build())
        } else {
            @Suppress("DEPRECATION")
            b.addAction(icon, title, pi)
        }
    }

    fun service(ctx: Context): Notification {
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CH_SERVICE) else @Suppress("DEPRECATION") Notification.Builder(ctx)
        b
            .setSmallIcon(R.drawable.ic_stat)
            .setContentIntent(openApp(ctx))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        val title = Player.currentTitle
        if (title != null) {
            b.setContentTitle(title).setContentText("neirox")
            addAction(b, ctx, android.R.drawable.ic_media_previous, "◀◀", ACT_PREV)
            addAction(
                b, ctx,
                if (Player.playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (Player.playing) "❚❚" else "▶",
                ACT_TOGGLE
            )
            addAction(b, ctx, android.R.drawable.ic_media_next, "▶▶", ACT_NEXT)
            b.setStyle(Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2))
        } else {
            b.setContentTitle("neirox")
            b.setContentText(tr("Работает в фоне, чтобы приходили сообщения", "Running in background to receive messages", "Läuft im Hintergrund, um Nachrichten zu empfangen"))
        }
        return b.build()
    }

    fun update(ctx: Context) {
        if (!NeiroxService.running) return
        nm(ctx).notify(ID_SERVICE, service(ctx))
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
            nm(ctx).notify(senderId.hashCode(), n)
        } catch (e: Exception) {
        }
    }

    fun incomingCall(ctx: Context, nick: String) {
        val open = PendingIntent.getActivity(
            ctx, 2,
            Intent(ctx, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra("call", true),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val decline = PendingIntent.getBroadcast(
            ctx, 3,
            Intent(ctx, CallActionReceiver::class.java).setAction("app.neirox.CALL_DECLINE"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val n = NotificationCompat.Builder(ctx, CH_CALL)
            .setSmallIcon(R.drawable.ic_stat)
            .setContentTitle(nick)
            .setContentText(tr("Входящий звонок", "Incoming call", "Eingehender Anruf"))
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .addAction(0, tr("Отклонить", "Decline", "Ablehnen"), decline)
            .addAction(0, tr("Ответить", "Answer", "Annehmen"), open)
            .build()
        try {
            nm(ctx).notify(ID_CALL, n)
        } catch (e: Exception) {
        }
    }

    fun cancelCall(ctx: Context) {
        try {
            nm(ctx).cancel(ID_CALL)
        } catch (e: Exception) {
        }
    }

    fun clearMessages(ctx: Context) {
        if (Build.VERSION.SDK_INT < 23) return
        val nm = nm(ctx)
        try {
            for (n in nm.activeNotifications) if (n.id != ID_SERVICE && n.id != ID_CALL) nm.cancel(n.id)
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

class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "app.neirox.CALL_DECLINE") Calls.decline()
    }
}
