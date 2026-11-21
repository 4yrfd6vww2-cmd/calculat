package app.neirox

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val BgTop = Color(0xFF040817)
val BgBottom = Color(0xFF060B1F)
val Accent = Color(0xFF4AA8FF)
val Accent2 = Color(0xFF8B6CFF)
val TextSecondary = Color.White.copy(alpha = 0.6f)
val CardBg = Color.White.copy(alpha = 0.05f)
val Warn = Color(0xFFFFC857)
val ErrorRed = Color(0xFFFF6B6B)

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
    keyboard: KeyboardType = KeyboardType.Text
) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(hint, color = Color.White.copy(alpha = 0.45f)) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        visualTransformation = if (secret) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.None,
            keyboardType = if (secret) KeyboardType.Password else keyboard
        ),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedBorderColor = Accent,
            unfocusedBorderColor = Color.White.copy(alpha = 0.15f),
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

fun friendlyError(raw: String): String {
    val s = raw.lowercase()
    return when {
        s.contains("invalid login") || s.contains("invalid_credentials") -> "Неверный ник или пароль"
        s.contains("nick_taken") -> "Этот ник уже занят"
        s.contains("email_taken") -> "Эта почта уже привязана к другому аккаунту"
        s.contains("bad_nick") -> "Ник: 3–20 символов, только a–z, цифры и _"
        s.contains("bad_password") -> "Пароль: минимум 6 символов"
        s.contains("bad_code") -> "Неверный или просроченный код"
        s.contains("too_many") -> "Слишком много попыток, попробуй через час"
        s.contains("mail_failed") || s.contains("mail_not_configured") -> "Не удалось отправить письмо, попробуй позже"
        s.contains("no_profile") -> "Профиль не найден"
        s.contains("bad_email") -> "Проверь адрес почты"
        s.contains("network") -> "Нет связи с сервером"
        else -> raw
    }
}

@Composable
fun Fill(content: @Composable () -> Unit) {
    Box(modifier = Modifier.fillMaxSize()) { content() }
}

val FieldSpacing = Arrangement.spacedBy(14.dp)
