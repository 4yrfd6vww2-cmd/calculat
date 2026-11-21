package app.neirox

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Api.init(this)
        Settings.init(this)
        Player.init(this)
        Store.init(this)
        setContent { NeiroxApp() }
    }
}
