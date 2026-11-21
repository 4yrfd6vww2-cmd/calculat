package app.neirox

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

val AccentPalette = listOf(
    0xFF4AA8FFL, 0xFF9B6BFFL, 0xFF35E0B4L, 0xFFFF6BB5L, 0xFFFF8A4AL, 0xFFFFD24AL,
    0xFF4AE0E0L, 0xFF7CFF6BL, 0xFFFF5C5CL, 0xFFB06BFFL, 0xFF6B8BFFL, 0xFFE06BFFL
)

object Settings {
    private lateinit var p: SharedPreferences

    var lang by mutableStateOf("ru")
        private set
    var mode by mutableIntStateOf(0) // 0 тёмная, 1 чёрная, 2 светлая
        private set
    var accent by mutableLongStateOf(0xFF4AA8FFL)
        private set
    var textSize by mutableIntStateOf(1) // 0 мелкий, 1 обычный, 2 крупный
        private set
    var sound by mutableStateOf(true)
        private set
    var haptics by mutableStateOf(true)
        private set

    fun init(ctx: Context) {
        p = ctx.applicationContext.getSharedPreferences("neirox_settings", Context.MODE_PRIVATE)
        lang = p.getString("lang", "ru") ?: "ru"
        mode = p.getInt("mode", 0)
        accent = p.getLong("accent", 0xFF4AA8FFL)
        textSize = p.getInt("size", 1)
        sound = p.getBoolean("sound", true)
        haptics = p.getBoolean("haptics", true)
    }

    fun updateLang(v: String) { lang = v; p.edit().putString("lang", v).apply() }
    fun updateMode(v: Int) { mode = v; p.edit().putInt("mode", v).apply() }
    fun updateAccent(v: Long) { accent = v; p.edit().putLong("accent", v).apply() }
    fun updateTextSize(v: Int) { textSize = v; p.edit().putInt("size", v).apply() }
    fun updateSound(v: Boolean) { sound = v; p.edit().putBoolean("sound", v).apply() }
    fun updateHaptics(v: Boolean) { haptics = v; p.edit().putBoolean("haptics", v).apply() }
}

fun tr(ru: String, en: String, de: String): String = when (Settings.lang) {
    "en" -> en
    "de" -> de
    else -> ru
}
