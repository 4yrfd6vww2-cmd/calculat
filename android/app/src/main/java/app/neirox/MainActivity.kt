package app.neirox

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.app.ActivityCompat

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockIfCall(intent)
        Notif.channels(this)
        if (Build.VERSION.SDK_INT >= 33) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
        if (Store.loggedIn) NeiroxService.start(this)
        setContent { NeiroxApp() }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        showOverLockIfCall(intent)
    }

    private fun showOverLockIfCall(i: android.content.Intent?) {
        if (i?.getBooleanExtra("call", false) == true && Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    override fun onStart() {
        super.onStart()
        Store.appVisible = true
        Notif.clearMessages(this)
    }

    override fun onStop() {
        Store.appVisible = false
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        }
        super.onStop()
    }
}
