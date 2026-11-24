package app.neirox

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun AuthFlow() {
    var screen by remember { mutableIntStateOf(0) }
    when (screen) {
        0 -> LoginScreen(go = { screen = it })
        1 -> RegisterScreen(go = { screen = it })
        else -> ForgotScreen(go = { screen = it })
    }
}

@Composable
fun LoginScreen(go: (Int) -> Unit) {
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
                Store.onLogin()
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
            .padding(horizontal = 25.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(90.dp))
        NxHeader(tr("Умный Чат", "Smart Chat", "Smarter Chat"))
        NxField(nick, { nick = it }, tr("Ник", "Nick", "Nick"))
        NxField(password, { password = it }, tr("Пароль", "Password", "Passwort"), secret = true)
        NxError(error)
        NxButton(tr("Войти", "Sign in", "Anmelden"), busy) { submit() }
        NxLink(tr("Забыли пароль?", "Forgot password?", "Passwort vergessen?")) { go(2) }
        NxLink(tr("Создать аккаунт", "Create account", "Konto erstellen")) { go(1) }
        Text("v$version", color = TextSecondary, fontSize = 12.sp)
        Spacer(Modifier.height(26.dp))
    }
}

@Composable
fun RegisterScreen(go: (Int) -> Unit) {
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
                Store.onLogin()
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
            .padding(horizontal = 25.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(70.dp))
        NxHeader(tr("Создание аккаунта", "Create account", "Konto erstellen"))
        NxField(nick, { nick = it }, tr("Ник (a–z, цифры, _)", "Nick (a–z, digits, _)", "Nick (a–z, Ziffern, _)"))
        NxField(password, { password = it }, tr("Пароль (от 6 символов)", "Password (6+ chars)", "Passwort (ab 6 Zeichen)"), secret = true)
        NxField(email, { email = it }, tr("Почта · рекомендуем", "Email · recommended", "E-Mail · empfohlen"), keyboard = KeyboardType.Email)
        NxCard(
            tr(
                "Почта нужна, чтобы восстановить пароль. Без неё забытый пароль вернуть не получится. Привязать почту можно и позже в настройках, но изменить её после привязки нельзя.",
                "Email is used to recover your password. Without it a forgotten password cannot be restored. You can bind it later in settings, but it cannot be changed afterwards.",
                "Die E-Mail dient zur Passwort-Wiederherstellung. Ohne sie kann ein vergessenes Passwort nicht zurückgesetzt werden. Du kannst sie später in den Einstellungen hinzufügen, aber nicht mehr ändern."
            ),
            Warn
        )
        NxError(error)
        NxButton(tr("Создать аккаунт", "Create account", "Konto erstellen"), busy) { submit() }
        NxLink(tr("Уже есть аккаунт? Войти", "Have an account? Sign in", "Schon ein Konto? Anmelden")) { go(0) }
        Spacer(Modifier.height(26.dp))
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
            error = tr("Введи ник", "Enter your nick", "Nick eingeben")
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
            .padding(horizontal = 25.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = FieldSpacing
    ) {
        Spacer(Modifier.height(90.dp))
        NxHeader(tr("Восстановление пароля", "Password recovery", "Passwort zurücksetzen"))
        if (done) {
            NxCard(
                tr(
                    "Пароль изменён. Теперь можно войти с новым паролем.",
                    "Password changed. You can sign in with the new password now.",
                    "Passwort geändert. Du kannst dich jetzt mit dem neuen Passwort anmelden."
                ),
                Txt
            )
        } else if (step == 0) {
            NxField(nick, { nick = it }, tr("Ник", "Nick", "Nick"))
            NxCard(
                tr(
                    "Код придёт на почту, привязанную к аккаунту. Если почта не привязана, пароль восстановить нельзя.",
                    "The code is sent to the email bound to the account. If none is bound, the password cannot be recovered.",
                    "Der Code geht an die verknüpfte E-Mail. Ist keine verknüpft, kann das Passwort nicht wiederhergestellt werden."
                )
            )
            NxError(error)
            NxButton(tr("Отправить код", "Send code", "Code senden"), busy) { sendCode() }
        } else {
            NxCard(
                tr(
                    "Если к нику привязана почта, мы отправили на неё 6-значный код. Он действует 15 минут. Проверь и папку «Спам».",
                    "If an email is bound to this nick, a 6-digit code was sent. It is valid for 15 minutes. Check Spam too.",
                    "Ist eine E-Mail verknüpft, wurde ein 6-stelliger Code gesendet. Er gilt 15 Minuten. Prüfe auch den Spam-Ordner."
                )
            )
            NxField(code, { code = it }, tr("Код из письма", "Code from email", "Code aus der E-Mail"), keyboard = KeyboardType.Number)
            NxField(password, { password = it }, tr("Новый пароль", "New password", "Neues Passwort"), secret = true)
            NxError(error)
            NxButton(tr("Сменить пароль", "Change password", "Passwort ändern"), busy) { confirm() }
            NxLink(tr("Отправить код ещё раз", "Send code again", "Code erneut senden")) { sendCode() }
        }
        NxLink(tr("Назад ко входу", "Back to sign in", "Zurück zur Anmeldung")) { go(0) }
        Spacer(Modifier.height(26.dp))
    }
}
