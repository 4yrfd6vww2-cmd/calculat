package app.neirox

import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
private fun SettingsRow(icon: String, title: String, value: String = "", onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(icon, fontSize = 20.sp)
        Text(title, color = Txt, fontSize = 16.sp, modifier = Modifier.padding(start = 14.dp).weight(1f))
        if (value.isNotEmpty()) Text(value, color = TextSecondary, fontSize = 14.sp)
        Text("›", color = TextSecondary, fontSize = 20.sp, modifier = Modifier.padding(start = 8.dp))
    }
}

@Composable
private fun SubPage(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    BackHandler { onBack() }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("‹", color = Accent, fontSize = 34.sp, modifier = Modifier.clickable { onBack() }.padding(horizontal = 12.dp))
            Text(title, color = Txt, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            content()
            Spacer(Modifier.height(30.dp))
        }
    }
}

@Composable
fun SettingsTab() {
    var page by remember { mutableIntStateOf(0) }
    val back = { page = 0 }
    when (page) {
        1 -> SubPage(tr("Профиль", "Profile", "Profil"), back) { ProfilePage() }
        2 -> SubPage(tr("Почта", "Email", "E-Mail"), back) { EmailPage() }
        3 -> SubPage(tr("Оформление", "Appearance", "Aussehen"), back) { LookPage() }
        4 -> SubPage(tr("Звуки", "Sounds", "Töne"), back) { SoundPage() }
        5 -> SubPage(tr("Язык", "Language", "Sprache"), back) { LangPage() }
        6 -> SubPage(tr("Мой nox", "My nox", "Mein nox"), back) {
            NxCard(
                tr("Пока что данная механика nox находится в разработке",
                    "The nox mechanic is still in development",
                    "Die nox-Mechanik ist noch in Entwicklung"),
                Txt
            )
        }
        7 -> SubPage(tr("Статистика", "Statistics", "Statistik"), back) { StatsPage() }
        8 -> SubPage(tr("О приложении", "About", "Über die App"), back) { AboutPage() }
        else -> Column(Modifier.fillMaxSize()) {
            ScreenTitle(tr("Настройки", "Settings", "Einstellungen"))
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable { page = 1 }.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Avatar(Store.me, 54.dp)
                    Column(Modifier.padding(start = 14.dp)) {
                        Text(Store.me?.nick ?: "", color = Txt, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Text(tr("Профиль", "Profile", "Profil"), color = TextSecondary, fontSize = 13.sp)
                    }
                }
                SettingsRow(
                    "✉️", tr("Почта", "Email", "E-Mail"),
                    if (Store.recoveryEmail == null) tr("не привязана", "not bound", "nicht verknüpft") else tr("привязана", "bound", "verknüpft")
                ) { page = 2 }
                SettingsRow("🎨", tr("Оформление", "Appearance", "Aussehen")) { page = 3 }
                SettingsRow("🔊", tr("Звуки", "Sounds", "Töne")) { page = 4 }
                SettingsRow("🌐", tr("Язык", "Language", "Sprache"), langTitle(Settings.lang)) { page = 5 }
                SettingsRow("⚡", tr("Мой nox", "My nox", "Mein nox")) { page = 6 }
                SettingsRow("📊", tr("Статистика", "Statistics", "Statistik")) { page = 7 }
                SettingsRow("ℹ️", tr("О приложении", "About", "Über die App"), "v" + versionName()) { page = 8 }
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable { Store.logout() }.padding(16.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    Text(tr("Выйти", "Sign out", "Abmelden"), color = ErrorRed, fontSize = 16.sp, fontWeight = FontWeight.Medium)
                }
                Spacer(Modifier.height(20.dp))
            }
        }
    }
}

private fun langTitle(code: String) = when (code) {
    "en" -> "English"
    "de" -> "Deutsch"
    else -> "Русский"
}

@Composable
private fun versionName(): String {
    val ctx = LocalContext.current
    return remember {
        try {
            ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName ?: ""
        } catch (e: Exception) {
            ""
        }
    }
}

@Composable
private fun ProfilePage() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var nick by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var msg by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            busy = true
            error = ""
            msg = ""
            scope.launch {
                try {
                    val jpg = withContext(Dispatchers.IO) { compressImage(ctx, uri, 512) }
                        ?: throw ApiError(tr("Не удалось прочитать фото", "Could not read the photo", "Foto konnte nicht gelesen werden"))
                    Store.uploadAvatar(jpg)
                } catch (e: Exception) {
                    error = friendlyError(e.message ?: "")
                }
                busy = false
            }
        }
    }

    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.clickable { picker.launch("image/*") }) { Avatar(Store.me, 110.dp) }
        NxSmallButton(tr("Сменить фото", "Change photo", "Foto ändern")) { picker.launch("image/*") }
        Text(Store.me?.nick ?: "", color = Txt, fontSize = 22.sp, fontWeight = FontWeight.Bold)
    }
    NxField(nick, { nick = it }, tr("Новый ник", "New nick", "Neuer Nick"))
    NxCard(
        tr("Ник: 3–20 символов, a–z, цифры и _. Чужие ники занять нельзя. Вход выполняется по нику, поэтому после смены входи с новым.",
            "Nick: 3–20 chars, a–z, digits and _. Taken nicks cannot be used. You sign in with the nick, so use the new one after changing.",
            "Nick: 3–20 Zeichen, a–z, Ziffern und _. Vergebene Nicks sind nicht möglich. Die Anmeldung erfolgt per Nick, nutze nach der Änderung den neuen.")
    )
    NxError(error)
    if (msg.isNotEmpty()) Text(msg, color = Accent, fontSize = 14.sp)
    NxButton(tr("Сменить ник", "Change nick", "Nick ändern"), busy) {
        val n = nick.trim().lowercase()
        if (n.isEmpty()) return@NxButton
        busy = true
        error = ""
        msg = ""
        scope.launch {
            try {
                Store.changeNick(n)
                nick = ""
                msg = tr("Ник изменён", "Nick changed", "Nick geändert")
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }
}

@Composable
private fun EmailPage() {
    val scope = rememberCoroutineScope()
    var email by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val bound = Store.recoveryEmail

    if (bound != null) {
        NxCard(tr("Привязана почта:", "Bound email:", "Verknüpfte E-Mail:") + "\n" + bound, Txt)
        NxCard(
            tr("Почту после привязки изменить нельзя. Она нужна для восстановления пароля.",
                "The email cannot be changed after binding. It is used to recover your password.",
                "Die E-Mail kann nach dem Verknüpfen nicht geändert werden. Sie dient zur Passwort-Wiederherstellung.")
        )
    } else {
        NxCard(
            tr("Почта нужна, чтобы восстановить пароль. Привязать можно один раз, изменить потом нельзя.",
                "Email is used to recover your password. You can bind it once and it cannot be changed afterwards.",
                "Die E-Mail dient zur Passwort-Wiederherstellung. Sie kann einmal verknüpft und danach nicht geändert werden."),
            Warn
        )
        NxField(email, { email = it }, tr("Почта", "Email", "E-Mail"), keyboard = KeyboardType.Email)
        NxError(error)
        NxButton(tr("Привязать", "Bind", "Verknüpfen"), busy) {
            val e = email.trim()
            if (!e.contains("@") || !e.contains(".")) {
                error = friendlyError("bad_email")
                return@NxButton
            }
            busy = true
            error = ""
            scope.launch {
                try {
                    Store.bindEmail(e)
                } catch (ex: Exception) {
                    error = friendlyError(ex.message ?: "")
                }
                busy = false
            }
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun LookPage() {
    Text(tr("Тема", "Theme", "Design"), color = TextSecondary, fontSize = 13.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NxSmallButton(tr("Тёмная", "Dark", "Dunkel"), filled = Settings.mode == 0) { Settings.setMode(0) }
        NxSmallButton(tr("Чёрная", "Black", "Schwarz"), filled = Settings.mode == 1) { Settings.setMode(1) }
        NxSmallButton(tr("Светлая", "Light", "Hell"), filled = Settings.mode == 2) { Settings.setMode(2) }
    }
    Text(tr("Размер текста", "Text size", "Textgröße"), color = TextSecondary, fontSize = 13.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NxSmallButton(tr("Мелкий", "Small", "Klein"), filled = Settings.textSize == 0) { Settings.setTextSize(0) }
        NxSmallButton(tr("Обычный", "Normal", "Normal"), filled = Settings.textSize == 1) { Settings.setTextSize(1) }
        NxSmallButton(tr("Крупный", "Large", "Groß"), filled = Settings.textSize == 2) { Settings.setTextSize(2) }
    }
    Text(tr("Акцентный цвет", "Accent color", "Akzentfarbe"), color = TextSecondary, fontSize = 13.sp)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        for (c in AccentPalette) {
            val selected = Settings.accent == c
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color(c))
                    .then(if (selected) Modifier.border(3.dp, Txt, CircleShape) else Modifier)
                    .clickable { Settings.setAccent(c) }
            )
        }
    }
}

@Composable
private fun SoundPage() {
    @Composable
    fun ToggleRow(title: String, value: Boolean, onChange: (Boolean) -> Unit) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, color = Txt, fontSize = 16.sp, modifier = Modifier.weight(1f))
            Switch(checked = value, onCheckedChange = onChange, colors = SwitchDefaults.colors(checkedTrackColor = Accent))
        }
    }
    ToggleRow(tr("Звук сообщений", "Message sound", "Nachrichtenton"), Settings.sound) { Settings.setSound(it) }
    ToggleRow(tr("Вибрация", "Haptics", "Vibration"), Settings.haptics) { Settings.setHaptics(it) }
}

@Composable
private fun LangPage() {
    for (code in listOf("ru", "en", "de")) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable { Settings.setLang(code) }.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(langTitle(code), color = Txt, fontSize = 16.sp, modifier = Modifier.weight(1f))
            if (Settings.lang == code) Text("✓", color = Accent, fontSize = 18.sp)
        }
    }
}

@Composable
private fun StatsPage() {
    val me = Store.myId
    val sent = Store.messages.count { it.sender == me }
    val received = Store.messages.count { it.receiver == me }
    @Composable
    fun StatCard(title: String, value: String) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, color = TextSecondary, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Text(value, color = Txt, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
    }
    StatCard(tr("Отправлено", "Sent", "Gesendet"), "$sent")
    StatCard(tr("Получено", "Received", "Empfangen"), "$received")
    StatCard(tr("Друзей", "Friends", "Freunde"), "${Store.friendIds.size}")
    StatCard(tr("Дней с нами", "Days with us", "Tage bei uns"), "${daysSince(Store.me?.createdAt)}")
}

@Composable
private fun AboutPage() {
    Column(Modifier.fillMaxWidth().padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "neirox",
            style = androidx.compose.ui.text.TextStyle(
                brush = Brush.horizontalGradient(listOf(Accent, Accent2)),
                fontSize = 40.sp,
                fontWeight = FontWeight.Bold
            )
        )
        Text(tr("Умный Чат", "Smart Chat", "Smarter Chat"), color = TextSecondary, fontSize = 16.sp)
        Text("v" + versionName(), color = TextSecondary, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp))
    }
}
