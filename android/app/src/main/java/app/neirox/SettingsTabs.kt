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
import androidx.compose.foundation.layout.width
import androidx.compose.ui.graphics.toArgb
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.VolumeUp
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
private fun SettingsRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, value: String = "", onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = Accent, modifier = Modifier.size(18.dp))
        Text(title, color = Txt, fontSize = 14.sp, modifier = Modifier.padding(start = 14.dp).weight(1f))
        if (value.isNotEmpty()) Text(value, color = TextSecondary, fontSize = 12.sp)
        Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(18.dp).padding(start = 8.dp))
    }
}

@Composable
private fun SubPage(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    BackHandler { onBack() }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("‹", color = Accent, fontSize = 27.sp, modifier = Modifier.clickable { onBack() }.padding(horizontal = 12.dp))
            Text(title, color = Txt, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            content()
            Spacer(Modifier.height(26.dp))
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
        6 -> SubPage(tr("Мой nox", "My nox", "Mein nox"), back) { NoxPage() }
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
                        Text(Store.me?.nick ?: "", color = Txt, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text(tr("Профиль", "Profile", "Profil"), color = TextSecondary, fontSize = 11.sp)
                    }
                }
                SettingsRow(
                    Icons.Filled.Email, tr("Почта", "Email", "E-Mail"),
                    if (Store.recoveryEmail == null) tr("не привязана", "not bound", "nicht verknüpft") else tr("привязана", "bound", "verknüpft")
                ) { page = 2 }
                SettingsRow(Icons.Filled.Palette, tr("Оформление", "Appearance", "Aussehen")) { page = 3 }
                SettingsRow(Icons.Filled.VolumeUp, tr("Звуки", "Sounds", "Töne")) { page = 4 }
                SettingsRow(Icons.Filled.Language, tr("Язык", "Language", "Sprache"), langTitle(Settings.lang)) { page = 5 }
                SettingsRow(Icons.Filled.Bolt, tr("Мой nox", "My nox", "Mein nox")) { page = 6 }
                SettingsRow(Icons.Filled.BarChart, tr("Статистика", "Statistics", "Statistik")) { page = 7 }
                SettingsRow(Icons.Filled.Info, tr("О приложении", "About", "Über die App"), "v" + versionName()) { page = 8 }
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable { Store.logout() }.padding(16.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    Text(tr("Выйти", "Sign out", "Abmelden"), color = ErrorRed, fontSize = 14.sp, fontWeight = FontWeight.Medium)
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
        Text(Store.me?.nick ?: "", color = Txt, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text("★ " + levelStr(Store.levels[Store.myId] ?: 0), color = Accent, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
    NxField(nick, { nick = it }, tr("Новый ник", "New nick", "Neuer Nick"))
    NxCard(
        tr("Ник: 3–20 символов, a–z, цифры и _. Чужие ники занять нельзя. Вход выполняется по нику, поэтому после смены входи с новым.",
            "Nick: 3–20 chars, a–z, digits and _. Taken nicks cannot be used. You sign in with the nick, so use the new one after changing.",
            "Nick: 3–20 Zeichen, a–z, Ziffern und _. Vergebene Nicks sind nicht möglich. Die Anmeldung erfolgt per Nick, nutze nach der Änderung den neuen.")
    )
    NxError(error)
    if (msg.isNotEmpty()) Text(msg, color = Accent, fontSize = 12.sp)
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
    Text(tr("Тема", "Theme", "Design"), color = TextSecondary, fontSize = 11.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NxSmallButton(tr("Тёмная", "Dark", "Dunkel"), filled = Settings.mode == 0) { Settings.updateMode(0) }
        NxSmallButton(tr("Чёрная", "Black", "Schwarz"), filled = Settings.mode == 1) { Settings.updateMode(1) }
        NxSmallButton(tr("Светлая", "Light", "Hell"), filled = Settings.mode == 2) { Settings.updateMode(2) }
    }
    Text(tr("Размер текста", "Text size", "Textgröße"), color = TextSecondary, fontSize = 11.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NxSmallButton(tr("Мелкий", "Small", "Klein"), filled = Settings.textSize == 0) { Settings.updateTextSize(0) }
        NxSmallButton(tr("Обычный", "Normal", "Normal"), filled = Settings.textSize == 1) { Settings.updateTextSize(1) }
        NxSmallButton(tr("Крупный", "Large", "Groß"), filled = Settings.textSize == 2) { Settings.updateTextSize(2) }
    }
    Text(tr("Акцентный цвет", "Accent color", "Akzentfarbe"), color = TextSecondary, fontSize = 11.sp)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        for (c in AccentPalette) {
            val selected = Settings.accent == c
            Box(
                Modifier
                    .size(39.dp)
                    .clip(CircleShape)
                    .background(Color(c))
                    .then(if (selected) Modifier.border(3.dp, Txt, CircleShape) else Modifier)
                    .clickable { Settings.updateAccent(c) }
            )
        }
        for (tc in Store.colors) {
            val hex = tc.color ?: continue
            val c = 0xFF000000L or java.lang.Long.parseLong(hex.removePrefix("#"), 16)
            val selected = Settings.accent == c
            Box(
                Modifier
                    .size(39.dp)
                    .clip(CircleShape)
                    .background(Color(c))
                    .then(if (selected) Modifier.border(3.dp, Txt, CircleShape) else Modifier)
                    .clickable { Settings.updateAccent(c) }
            )
        }
    }
    Text(tr("Свои цвета открываются за nox: раздел «Мой nox».", "Custom colors are unlocked with nox: see “My nox”.", "Eigene Farben schaltest du mit nox frei: „Mein nox“."), color = TextSecondary, fontSize = 12.sp)
}

@Composable
private fun SoundPage() {
    @Composable
    fun ToggleRow(title: String, value: Boolean, onChange: (Boolean) -> Unit) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, color = Txt, fontSize = 14.sp, modifier = Modifier.weight(1f))
            Switch(checked = value, onCheckedChange = onChange, colors = SwitchDefaults.colors(checkedTrackColor = Accent))
        }
    }
    ToggleRow(tr("Звук сообщений", "Message sound", "Nachrichtenton"), Settings.sound) { Settings.updateSound(it) }
    ToggleRow(tr("Вибрация", "Haptics", "Vibration"), Settings.haptics) { Settings.updateHaptics(it) }
}

@Composable
private fun LangPage() {
    for (code in listOf("ru", "en", "de")) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg).clickable { Settings.updateLang(code) }.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(langTitle(code), color = Txt, fontSize = 14.sp, modifier = Modifier.weight(1f))
            if (Settings.lang == code) Icon(Icons.Filled.Check, contentDescription = null, tint = Accent, modifier = Modifier.size(16.dp))
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
            Text(title, color = TextSecondary, fontSize = 13.sp, modifier = Modifier.weight(1f))
            Text(value, color = Txt, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
    }
    StatCard(tr("Отправлено", "Sent", "Gesendet"), "$sent")
    StatCard(tr("Получено", "Received", "Empfangen"), "$received")
    StatCard(tr("Друзей", "Friends", "Freunde"), "${Store.friendIds.size}")
    StatCard(tr("Дней с нами", "Days with us", "Tage bei uns"), "${daysSince(Store.me?.createdAt)}")
}

@Composable
private fun AboutPage() {
    val ctx = LocalContext.current
    Column(Modifier.fillMaxWidth().padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            "neirox",
            style = androidx.compose.ui.text.TextStyle(
                brush = Brush.horizontalGradient(listOf(Accent, Accent2)),
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold
            )
        )
        Text(tr("Умный Чат", "Smart Chat", "Smarter Chat"), color = TextSecondary, fontSize = 14.sp)
        Text("v" + versionName(), color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
        Column(Modifier.fillMaxWidth().padding(top = 24.dp, start = 16.dp, end = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SettingsRow(Icons.Filled.Language, tr("Сайт", "Website", "Webseite")) {
                ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("https://4yrfd6vww2-cmd.github.io/calculat/")))
            }
            SettingsRow(Icons.Filled.Code, "GitHub") {
                ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("https://github.com/4yrfd6vww2-cmd/calculat")))
            }
        }
    }
}


@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun NoxPage() {
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    var pickId by remember { mutableStateOf<Long?>(null) }
    var error by remember { mutableStateOf("") }
    androidx.compose.runtime.LaunchedEffect(Unit) { try { Store.noxOpen() } catch (e: Exception) { error = friendlyError(e.message ?: "") } }
    fun act(block: suspend () -> Unit) {
        error = ""
        scope.launch {
            try { block() } catch (e: Exception) {
                val m = e.message ?: ""
                error = when {
                    m.contains("not_enough") -> tr("Не хватает nox", "Not enough nox", "Nicht genug nox")
                    m.contains("max_level") -> tr("Максимальный уровень", "Maximum level reached", "Maximales Level erreicht")
                    else -> friendlyError(m)
                }
            }
        }
    }
    val w = Store.wallet ?: Wallet(0, 0, 0, 0)
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Bolt, contentDescription = null, tint = Accent, modifier = Modifier.size(18.dp).padding(end = 4.dp))
        Text("${w.balance} nox", color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    }
    NxCard(tr("Всего заработано: ", "Total earned: ", "Insgesamt verdient: ") + w.earned + "\n" +
        tr("Серия входов: ", "Login streak: ", "Login-Serie: ") + w.streak + " / 3 · " + tr("за 3 дня подряд +5 nox", "+5 nox for 3 days in a row", "+5 nox für 3 Tage in Folge"), Txt)
    if (error.isNotEmpty()) NxError(error)

    Text(tr("Свои цвета темы", "Custom theme colors", "Eigene Themenfarben"), color = Txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    Text(tr("10 nox за один цвет. Покупки хранятся на сервере.", "10 nox per color. Purchases are stored on the server.", "10 nox pro Farbe. Käufe werden auf dem Server gespeichert."), color = TextSecondary, fontSize = 11.sp)
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        for (tc in Store.colors) {
            val hex = tc.color
            if (hex != null) {
                val c = 0xFF000000L or java.lang.Long.parseLong(hex.removePrefix("#"), 16)
                Box(
                    Modifier.size(39.dp).clip(CircleShape).background(Color(c))
                        .then(if (Settings.accent == c) Modifier.border(3.dp, Txt, CircleShape) else Modifier)
                        .clickable { Settings.updateAccent(c) }
                )
            } else {
                NxSmallButton(tr("Выбрать цвет", "Pick color", "Farbe wählen"), filled = false) { pickId = tc.id }
            }
        }
    }
    NxSmallButton(tr("Купить цвет · 10 nox", "Buy a color · 10 nox", "Farbe kaufen · 10 nox"), filled = true) {
        act { pickId = Store.buyColor() }
    }

    Text(tr("Уровень: ★ ", "Level: ★ ", "Level: ★ ") + levelStr(w.level) + " / 100.0", color = Txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    Text(tr("Виден всем. 0.01 уровня = 1 nox.", "Visible to everyone. 0.01 level = 1 nox.", "Für alle sichtbar. 0.01 Level = 1 nox."), color = TextSecondary, fontSize = 11.sp)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NxSmallButton("+0.01", filled = false) { act { Store.buyLevel(1) } }
        NxSmallButton("+0.10", filled = false) { act { Store.buyLevel(10) } }
        NxSmallButton("+1.00", filled = false) { act { Store.buyLevel(100) } }
    }

    Text(tr("Таблица лидеров", "Leaderboard", "Bestenliste"), color = Txt, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    if (Store.board.isEmpty()) Text(tr("Пока никого нет", "Nobody yet", "Noch niemand"), color = TextSecondary, fontSize = 12.sp)
    Store.board.forEachIndexed { i, r ->
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(CardBg).padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("${i + 1}", color = TextSecondary, fontSize = 13.sp, modifier = Modifier.width(25.dp))
            Avatar(Profile(r.userId, r.nick, r.avatarUrl, null), 36.dp)
            Text(
                r.nick + (if (r.level > 0) "  ★ " + levelStr(r.level) else ""),
                color = Txt, fontSize = 13.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(start = 10.dp).weight(1f)
            )
            Text("${r.earned} nox", color = Accent, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
    }

    val pid = pickId
    if (pid != null) {
        var h by remember { mutableStateOf(270f) }
        var sat by remember { mutableStateOf(0.6f) }
        var v by remember { mutableStateOf(1f) }
        val col = Color.hsv(h, sat, v)
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { pickId = null },
            title = { Text(tr("Свой цвет", "Custom color", "Eigene Farbe")) },
            text = {
                Column {
                    Text(tr("Цвет выбирается один раз, потом он сохранится в палитре.", "You pick the color once, then it stays in your palette.", "Die Farbe wird einmal gewählt und bleibt in deiner Palette."), fontSize = 11.sp)
                    Box(Modifier.fillMaxWidth().height(49.dp).padding(vertical = 8.dp).clip(RoundedCornerShape(12.dp)).background(col))
                    androidx.compose.material3.Slider(h, { h = it }, valueRange = 0f..360f)
                    androidx.compose.material3.Slider(sat, { sat = it })
                    androidx.compose.material3.Slider(v, { v = it })
                }
            },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    val hex = String.format("#%06x", col.toArgb() and 0xFFFFFF)
                    pickId = null
                    act { Store.setColor(pid, hex); Settings.updateAccent(0xFF000000L or (col.toArgb().toLong() and 0xFFFFFF)) }
                }) { Text(tr("Сохранить", "Save", "Speichern")) }
            },
            dismissButton = { androidx.compose.material3.TextButton(onClick = { pickId = null }) { Text(tr("Позже", "Later", "Später")) } }
        )
    }
}
