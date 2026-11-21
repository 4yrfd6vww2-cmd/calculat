package app.neirox

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun NeiroxApp() {
    var loggedIn by remember { mutableStateOf(Api.isLoggedIn()) }
    MaterialTheme(colorScheme = darkColorScheme(primary = Accent, background = BgTop, surface = BgBottom)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(listOf(BgTop, BgBottom)))
        ) {
            if (loggedIn) {
                HomeScreen(onLogout = {
                    Api.signOut()
                    loggedIn = false
                })
            } else {
                AuthFlow(onLoggedIn = { loggedIn = true })
            }
        }
    }
}

@Composable
fun AuthFlow(onLoggedIn: () -> Unit) {
    var screen by remember { mutableIntStateOf(0) }
    when (screen) {
        0 -> LoginScreen(go = { screen = it }, onLoggedIn = onLoggedIn)
        1 -> RegisterScreen(go = { screen = it }, onLoggedIn = onLoggedIn)
        else -> ForgotScreen(go = { screen = it })
    }
}

@Composable
fun LoginScreen(go: (Int) -> Unit, onLoggedIn: () -> Unit) {
    var nick by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    val version = remember {
        try {
            ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    fun submit() {
        val n = nick.trim().lowercase()
        if (n.isEmpty() || password.isEmpty()) return
        busy = true
        error = ""
        scope.launch {
            try {
                Api.signIn(n, password)
                onLoggedIn()
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(90.dp))
        NxHeader("Умный Чат")
        NxField(nick, { nick = it }, "Ник")
        NxField(password, { password = it }, "Пароль", secret = true)
        NxError(error)
        NxButton("Войти", busy) { submit() }
        NxLink("Забыли пароль?") { go(2) }
        NxLink("Создать аккаунт") { go(1) }
        Text("v$version", color = TextSecondary, fontSize = 12.sp)
        Spacer(Modifier.height(30.dp))
    }
}

@Composable
fun RegisterScreen(go: (Int) -> Unit, onLoggedIn: () -> Unit) {
    var nick by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    fun submit() {
        val n = nick.trim().lowercase()
        val e = email.trim().lowercase()
        if (n.isEmpty() || password.isEmpty()) return
        busy = true
        error = ""
        scope.launch {
            try {
                Api.register(n, password, e)
                Api.signIn(n, password)
                onLoggedIn()
            } catch (ex: Exception) {
                error = friendlyError(ex.message ?: "")
            }
            busy = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(70.dp))
        NxHeader("Создание аккаунта")
        NxField(nick, { nick = it }, "Ник (a–z, цифры, _)")
        NxField(password, { password = it }, "Пароль (от 6 символов)", secret = true)
        NxField(email, { email = it }, "Почта · рекомендуем", keyboard = KeyboardType.Email)
        NxCard(
            "Почта нужна, чтобы восстановить пароль. Без неё забытый пароль вернуть не получится. " +
                "Привязать почту можно и позже в настройках, но изменить её после привязки нельзя.",
            Warn
        )
        NxError(error)
        NxButton("Создать аккаунт", busy) { submit() }
        NxLink("Уже есть аккаунт? Войти") { go(0) }
        Spacer(Modifier.height(30.dp))
    }
}

@Composable
fun ForgotScreen(go: (Int) -> Unit) {
    var nick by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var step by remember { mutableIntStateOf(0) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var done by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun sendCode() {
        val n = nick.trim().lowercase()
        if (n.isEmpty()) {
            error = "Введи ник"
            return
        }
        busy = true
        error = ""
        scope.launch {
            try {
                Api.recoverRequest(n)
                step = 1
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    fun confirm() {
        val n = nick.trim().lowercase()
        busy = true
        error = ""
        scope.launch {
            try {
                Api.recoverConfirm(n, code.trim(), password)
                done = true
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
            busy = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(90.dp))
        NxHeader("Восстановление пароля")
        if (done) {
            NxCard("Пароль изменён. Теперь можно войти с новым паролем.", androidx.compose.ui.graphics.Color.White)
        } else if (step == 0) {
            NxField(nick, { nick = it }, "Ник")
            NxCard("Код придёт на почту, привязанную к аккаунту. Если почта не привязана, пароль восстановить нельзя.")
            NxError(error)
            NxButton("Отправить код", busy) { sendCode() }
        } else {
            NxCard(
                "Если к нику привязана почта, мы отправили на неё 6-значный код. Он действует 15 минут. " +
                    "Проверь и папку «Спам»."
            )
            NxField(code, { code = it }, "Код из письма", keyboard = KeyboardType.Number)
            NxField(password, { password = it }, "Новый пароль", secret = true)
            NxError(error)
            NxButton("Сменить пароль", busy) { confirm() }
            NxLink("Отправить код ещё раз") { sendCode() }
        }
        NxLink("Назад ко входу") { go(0) }
        Spacer(Modifier.height(30.dp))
    }
}

@Composable
fun HomeScreen(onLogout: () -> Unit) {
    var nick by remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        try {
            nick = Api.fetchNick()
        } catch (e: Exception) {
            // профиль подтянется позже
        }
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(120.dp))
        NxHeader(if (nick.isEmpty()) "Вы вошли" else "Вы вошли как $nick")
        NxCard("Каркас Android-версии работает. Чаты, друзья, ИИ и плеер появятся в следующих этапах.")
        NxButton("Выйти", false) { onLogout() }
    }
}
