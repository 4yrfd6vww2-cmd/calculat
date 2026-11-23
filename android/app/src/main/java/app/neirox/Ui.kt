package app.neirox

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val isLight: Boolean get() = Settings.mode == 2

val Accent: Color get() = Color(Settings.accent)
val Accent2 = Color(0xFF8B6CFF)
val BgTop: Color
    get() = when (Settings.mode) {
        1 -> Color(0xFF000000)
        2 -> Color(0xFFF3F6FF)
        else -> Color(0xFF040817)
    }
val BgBottom: Color
    get() = when (Settings.mode) {
        1 -> Color(0xFF05060A)
        2 -> Color(0xFFE6ECFF)
        else -> Color(0xFF060B1F)
    }
val Txt: Color get() = if (isLight) Color(0xFF0F1530) else Color.White
val TextSecondary: Color get() = if (isLight) Color(0xFF0F1530).copy(alpha = 0.55f) else Color.White.copy(alpha = 0.6f)
val CardBg: Color get() = if (isLight) Color.White.copy(alpha = 0.75f) else Color.White.copy(alpha = 0.05f)
val StrokeColor: Color get() = if (isLight) Color.Black.copy(alpha = 0.08f) else Color.White.copy(alpha = 0.10f)
val Warn = Color(0xFFFFC857)
val ErrorRed = Color(0xFFFF6B6B)

val FieldSpacing = Arrangement.spacedBy(14.dp)

@Composable
fun NxHeader(subtitle: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(bottom = 20.dp)) {
        Text(
            "neirox",
            style = TextStyle(
                brush = Brush.horizontalGradient(listOf(Accent, Accent2)),
                fontSize = 40.sp,
                fontWeight = FontWeight.Bold
            )
        )
        Text(subtitle, color = TextSecondary, fontSize = 15.sp)
    }
}

@Composable
fun NxField(
    value: String,
    onChange: (String) -> Unit,
    hint: String,
    secret: Boolean = false,
    keyboard: KeyboardType = KeyboardType.Text,
    modifier: Modifier = Modifier.fillMaxWidth(),
    singleLine: Boolean = true,
    clearable: Boolean = false
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(hint, color = TextSecondary) },
        singleLine = singleLine,
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        visualTransformation = if (secret) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(
            capitalization = if (singleLine) KeyboardCapitalization.None else KeyboardCapitalization.Sentences,
            keyboardType = if (secret) KeyboardType.Password else keyboard
        ),
        trailingIcon = if (clearable && value.isNotEmpty()) {
            { Text("✕", color = TextSecondary, modifier = Modifier.clickable { onChange("") }.padding(10.dp)) }
        } else null,
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Txt,
            unfocusedTextColor = Txt,
            focusedBorderColor = Accent,
            unfocusedBorderColor = StrokeColor,
            cursorColor = Accent,
            focusedContainerColor = CardBg,
            unfocusedContainerColor = CardBg
        )
    )
}

@Composable
fun NxButton(title: String, busy: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.horizontalGradient(listOf(Accent, Accent2)))
            .clickable(enabled = !busy, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (busy) {
            CircularProgressIndicator(modifier = Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
        } else {
            Text(title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
    }
}

@Composable
fun NxSmallButton(title: String, filled: Boolean = true, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Box(
        modifier = Modifier
            .clip(shape)
            .background(if (filled) Brush.horizontalGradient(listOf(Accent, Accent2)) else Brush.horizontalGradient(listOf(CardBg, CardBg)))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(title, color = if (filled) Color.White else Txt, fontSize = 13.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun NxCard(text: String, color: Color = TextSecondary) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .padding(14.dp)
    ) {
        Text(text, color = color, fontSize = 13.sp)
    }
}

@Composable
fun NxError(text: String) {
    if (text.isNotEmpty()) {
        Text(text, color = ErrorRed, fontSize = 14.sp, modifier = Modifier.fillMaxWidth())
    }
}

@Composable
fun NxLink(title: String, onClick: () -> Unit) {
    Text(
        title,
        color = Accent,
        fontSize = 15.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(8.dp)
    )
}

@Composable
fun ScreenTitle(text: String) {
    Text(
        text,
        color = Txt,
        fontSize = 28.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(start = 20.dp, top = 18.dp, bottom = 10.dp)
    )
}

@Composable
fun Avatar(profile: Profile?, size: Dp = 48.dp) {
    val url = profile?.avatarUrl
    if (url != null) {
        RemoteImage(
            key = url,
            loader = { Api.download(url) },
            modifier = Modifier.size(size).clip(CircleShape)
        )
    } else {
        val letter = (profile?.nick ?: "?").take(1).uppercase()
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(Brush.linearGradient(listOf(Accent, Accent2))),
            contentAlignment = Alignment.Center
        ) {
            Text(letter, color = Color.White, fontWeight = FontWeight.Bold, fontSize = (size.value * 0.42f).sp)
        }
    }
}

fun friendlyError(raw: String): String {
    val s = raw.lowercase()
    return when {
        s.contains("invalid login") || s.contains("invalid_credentials") ->
            tr("Неверный ник или пароль", "Wrong nick or password", "Nick oder Passwort falsch")
        s.contains("nick_taken") -> tr("Этот ник уже занят", "This nick is taken", "Dieser Nick ist vergeben")
        s.contains("email_taken") ->
            tr("Эта почта уже привязана к другому аккаунту", "This email is already used", "Diese E-Mail wird bereits verwendet")
        s.contains("bad_nick") ->
            tr("Ник: 3–20 символов, только a–z, цифры и _", "Nick: 3–20 chars, a–z, digits and _", "Nick: 3–20 Zeichen, a–z, Ziffern und _")
        s.contains("bad_password") ->
            tr("Пароль: минимум 6 символов", "Password: at least 6 characters", "Passwort: mindestens 6 Zeichen")
        s.contains("bad_code") ->
            tr("Неверный или просроченный код", "Wrong or expired code", "Code falsch oder abgelaufen")
        s.contains("blocked") ->
            tr("Нельзя написать: пользователь заблокировал переписку", "Can't send: the user has blocked this chat", "Kann nicht senden: der Nutzer hat den Chat blockiert")
        s.contains("too_many") ->
            tr("Слишком много попыток, попробуй через час", "Too many attempts, try again in an hour", "Zu viele Versuche, versuche es in einer Stunde erneut")
        s.contains("mail_failed") || s.contains("mail_not_configured") ->
            tr("Не удалось отправить письмо, попробуй позже", "Could not send the email, try later", "E-Mail konnte nicht gesendet werden")
        s.contains("no_profile") -> tr("Профиль не найден", "Profile not found", "Profil nicht gefunden")
        s.contains("bad_email") -> tr("Проверь адрес почты", "Check the email address", "E-Mail prüfen")
        s.contains("network") -> tr("Нет связи с сервером", "No connection to server", "Keine Verbindung zum Server")
        else -> raw
    }
}
