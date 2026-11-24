package app.neirox

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Search
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.launch

/** Фото, которыми обменивались в этом личном чате. */
private fun sharedMedia(friendId: String): List<Message> =
    Store.thread(friendId).filter { it.kind == "image" && it.mediaPath != null && !isSticker(it) }

@Composable
fun ContactProfileDialog(friendId: String, onClose: () -> Unit, onCall: () -> Unit, onSearch: () -> Unit) {
    val friend = Store.profiles[friendId] ?: run { onClose(); return }
    val scope = rememberCoroutineScope()
    var showName by remember { mutableStateOf(false) }
    var nameText by remember { mutableStateOf(Store.alias[friendId] ?: "") }
    var showAllMedia by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val blockedByMe = Store.iBlocked(friendId)
    val media = remember(Store.messages.size) { sharedMedia(friendId) }
    val thread = Store.thread(friendId)
    val msgCount = thread.size

    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().background(BgTop)) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 32.dp)) {
                Row(Modifier.fillMaxWidth().padding(8.dp)) {
                    Text("‹", color = Accent, fontSize = 27.sp, modifier = Modifier.clickable { onClose() }.padding(horizontal = 12.dp))
                }
                Spacer(Modifier.height(8.dp))
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Box(
                        Modifier.size(150.dp).clip(CircleShape)
                            .background(Brush.radialGradient(listOf(Accent.copy(alpha = 0.55f), Accent.copy(alpha = 0f))))
                    )
                    Avatar(friend, 108.dp)
                }
                Spacer(Modifier.height(14.dp))
                Text(Store.dname(friend), color = Txt, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                if (friend.nick != Store.dname(friend)) {
                    Text("@" + friend.nick, color = TextSecondary, fontSize = 11.sp, modifier = Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                }
                val lb = Store.levelBadge(friendId)
                if (lb.isNotEmpty()) {
                    Text(lb, color = Accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, modifier = Modifier.fillMaxWidth().padding(top = 4.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                }
                Text(Store.statusLine(friend), color = TextSecondary, fontSize = 11.sp, modifier = Modifier.fillMaxWidth().padding(top = 2.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)

                Spacer(Modifier.height(18.dp))
                Row(Modifier.fillMaxWidth().padding(horizontal = 21.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    ProfilePill(Icons.Filled.Call, tr("Звонок", "Call", "Anruf"), enabled = !blockedByMe) { onCall(); onClose() }
                    ProfilePill(
                        if (Store.isMuted(friendId)) Icons.Filled.NotificationsActive else Icons.Filled.NotificationsOff,
                        if (Store.isMuted(friendId)) tr("Звук", "Unmute", "Ton an") else tr("Без звука", "Mute", "Stumm"),
                        enabled = true
                    ) { scope.launch { try { Store.setPref(friendId, "muted", !Store.isMuted(friendId)) } catch (e: Exception) { } } }
                    ProfilePill(Icons.Filled.Search, tr("Поиск", "Search", "Suche"), enabled = true) { onSearch(); onClose() }
                    ProfilePill(
                        if (blockedByMe) Icons.Filled.CheckCircle else Icons.Filled.Block,
                        if (blockedByMe) tr("Разблок.", "Unblock", "Entsperren") else tr("Блок.", "Block", "Blockieren"),
                        enabled = true,
                        danger = !blockedByMe
                    ) {
                        scope.launch {
                            try {
                                if (blockedByMe) Store.unblockUser(friendId) else Store.blockUser(friendId)
                            } catch (e: Exception) { error = friendlyError(e.message ?: "") }
                        }
                    }
                }
                if (error.isNotEmpty()) Text(error, color = ErrorRed, fontSize = 11.sp, modifier = Modifier.padding(top = 8.dp, start = 24.dp))

                Spacer(Modifier.height(20.dp))
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(CardBg)) {
                        Column(Modifier.fillMaxWidth().padding(16.dp)) {
                            Row(Modifier.fillMaxWidth().clickable { nameText = Store.alias[friendId] ?: ""; showName = true }, horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(tr("Имя контакта", "Contact name", "Kontaktname"), color = TextSecondary, fontSize = 11.sp)
                                Text(Store.alias[friendId] ?: tr("не задано", "not set", "nicht gesetzt"), color = Accent, fontSize = 11.sp)
                            }
                            Spacer(Modifier.height(10.dp))
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text(tr("Сообщений", "Messages", "Nachrichten"), color = TextSecondary, fontSize = 11.sp)
                                Text("$msgCount", color = Txt, fontSize = 11.sp)
                            }
                        }
                    }
                }

                if (media.isNotEmpty()) {
                    Spacer(Modifier.height(18.dp))
                    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(tr("Общие медиа", "Shared media", "Geteilte Medien"), color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        if (media.size > 8) Text(tr("Показать все", "Show all", "Alle anzeigen"), color = Accent, fontSize = 11.sp, modifier = Modifier.clickable { showAllMedia = true })
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        media.takeLast(12).reversed().forEach { m ->
                            RemoteImage(
                                key = "pm:${m.mediaPath}",
                                loader = { Api.download(Api.signedUrl("chat-media", m.mediaPath!!)) },
                                modifier = Modifier.size(84.dp).clip(RoundedCornerShape(10.dp)),
                                contentScale = ContentScale.Crop
                            )
                        }
                    }
                }
            }
        }
    }

    if (showName) {
        AlertDialog(
            onDismissRequest = { showName = false },
            title = { Text(tr("Имя контакта", "Contact name", "Kontaktname")) },
            text = { NxField(nameText, { nameText = it }, tr("Имя", "Name", "Name")) },
            confirmButton = {
                TextButton(onClick = {
                    showName = false
                    scope.launch { try { Store.setAlias(friendId, nameText) } catch (e: Exception) { } }
                }) { Text(tr("Сохранить", "Save", "Speichern")) }
            },
            dismissButton = { TextButton(onClick = { showName = false }) { Text(tr("Отмена", "Cancel", "Abbrechen")) } }
        )
    }

    if (showAllMedia) {
        Dialog(onDismissRequest = { showAllMedia = false }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(Modifier.fillMaxSize().background(BgTop)) {
                Column(Modifier.fillMaxSize()) {
                    Row(Modifier.fillMaxWidth().padding(8.dp)) {
                        Text("‹", color = Accent, fontSize = 27.sp, modifier = Modifier.clickable { showAllMedia = false }.padding(horizontal = 12.dp))
                        Text(tr("Общие медиа", "Shared media", "Geteilte Medien"), color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, modifier = Modifier.padding(top = 6.dp))
                    }
                    LazyVerticalGrid(columns = GridCells.Fixed(3), contentPadding = androidx.compose.foundation.layout.PaddingValues(4.dp)) {
                        items(media.reversed()) { m ->
                            RemoteImage(
                                key = "pm2:${m.mediaPath}",
                                loader = { Api.download(Api.signedUrl("chat-media", m.mediaPath!!)) },
                                modifier = Modifier.padding(2.dp).fillMaxWidth().height(120.dp).clip(RoundedCornerShape(6.dp)),
                                contentScale = ContentScale.Crop
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfilePill(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, enabled: Boolean, danger: Boolean = false, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(CardBg)
            .then(if (enabled) Modifier.clickable { onClick() } else Modifier)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, contentDescription = null, tint = if (danger) ErrorRed else Txt, modifier = Modifier.size(18.dp))
        Spacer(Modifier.height(4.dp))
        Text(label, color = if (danger) ErrorRed else TextSecondary, fontSize = 11.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}
