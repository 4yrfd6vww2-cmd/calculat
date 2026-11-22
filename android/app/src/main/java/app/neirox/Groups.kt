package app.neirox

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

@Composable
fun CreateChatDialog(onClose: () -> Unit, onCreated: (String) -> Unit) {
    var channel by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val picked = remember { mutableStateListOf<String>() }
    val scope = rememberCoroutineScope()
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text(tr("Новый чат", "New chat", "Neuer Chat")) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()).heightIn(max = 420.dp)) {
                Row(Arrangement.spacedBy(16.dp)) {
                    Text(
                        (if (!channel) "● " else "○ ") + tr("Группа", "Group", "Gruppe"),
                        color = if (!channel) Accent else TextSecondary, modifier = Modifier.clickable { channel = false }.padding(6.dp)
                    )
                    Text(
                        (if (channel) "● " else "○ ") + tr("Канал", "Channel", "Kanal"),
                        color = if (channel) Accent else TextSecondary, modifier = Modifier.clickable { channel = true }.padding(6.dp)
                    )
                }
                NxField(title, { title = it }, tr("Название", "Title", "Titel"))
                if (!channel) {
                    Text(tr("Участники из друзей:", "Members from friends:", "Mitglieder aus Freunden:"), color = TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 10.dp))
                    for (id in Store.friendIds) {
                        val p = Store.profiles[id] ?: continue
                        Row(
                            Modifier.fillMaxWidth().clickable { if (id in picked) picked.remove(id) else picked.add(id) }.padding(vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(if (id in picked) "☑" else "☐", fontSize = 20.sp, color = Accent, modifier = Modifier.padding(end = 10.dp))
                            Avatar(p, 32.dp)
                            Text(p.nick, color = Txt, modifier = Modifier.padding(start = 10.dp))
                        }
                    }
                }
                if (error.isNotEmpty()) NxError(error)
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val t = title.trim()
                if (t.isEmpty() || busy) return@TextButton
                busy = true
                scope.launch {
                    try {
                        val key = Store.createChat(if (channel) "channel" else "group", t, if (channel) emptyList() else picked.toList())
                        onCreated(key)
                    } catch (e: Exception) {
                        error = if ((e.message ?: "").contains("duplicate") || (e.message ?: "").contains("23505"))
                            tr("Канал с таким названием уже есть", "A channel with this title exists", "Kanal existiert bereits")
                        else friendlyError(e.message ?: "")
                        busy = false
                    }
                }
            }) { Text(tr("Создать", "Create", "Erstellen")) }
        },
        dismissButton = { TextButton(onClick = onClose) { Text(tr("Отмена", "Cancel", "Abbrechen")) } }
    )
}

@Composable
fun FindChannelDialog(onClose: () -> Unit, onOpen: (String) -> Unit) {
    var q by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<Chat>>(emptyList()) }
    val scope = rememberCoroutineScope()
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text(tr("Найти канал", "Find channel", "Kanal suchen")) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()).heightIn(max = 420.dp)) {
                NxField(q, { q = it; scope.launch { results = Store.findChannels(it) } }, tr("Название канала", "Channel title", "Kanaltitel"))
                for (c in results) {
                    val joined = Store.isMember(c.id)
                    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("📢 " + c.title, color = Txt, modifier = Modifier.weight(1f).clickable { onOpen("c:" + c.id) })
                        if (!joined) {
                            TextButton(onClick = {
                                scope.launch { try { Store.joinChat(c.id); onOpen("c:" + c.id) } catch (e: Exception) { } }
                            }) { Text(tr("Подписаться", "Subscribe", "Abonnieren")) }
                        } else Text("✓", color = Accent)
                    }
                }
                if (results.isEmpty() && q.isNotBlank()) Text(tr("Ничего не найдено", "Nothing found", "Nichts gefunden"), color = TextSecondary, modifier = Modifier.padding(top = 10.dp))
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onClose) { Text(tr("Закрыть", "Close", "Schließen")) } }
    )
}

@Composable
fun ChatInfoDialog(key: String, onClose: () -> Unit, onLeft: () -> Unit) {
    val chat = Store.chatByKey(key) ?: return
    val cid = chat.id
    val mine = Store.myMember(key)?.role
    val isOwner = chat.owner == Store.myId
    val isAdmin = isOwner || mine == "admin"
    val mem = Store.members.filter { it.chatId == cid }
    var addNick by remember { mutableStateOf("") }
    var showAdd by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text(chat.title) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()).heightIn(max = 460.dp)) {
                Text(
                    (if (chat.kind == "channel") tr("Канал", "Channel", "Kanal") else tr("Группа", "Group", "Gruppe")) + " · " + mem.size,
                    color = TextSecondary, fontSize = 13.sp
                )
                if (chat.kind == "group" && isAdmin) {
                    Text(
                        "＋ " + tr("Добавить участника", "Add member", "Mitglied hinzufügen"), color = Accent,
                        modifier = Modifier.clickable { showAdd = !showAdd }.padding(vertical = 10.dp)
                    )
                    if (showAdd) {
                        val have = mem.map { it.userId }.toSet()
                        for (id in Store.friendIds.filter { it !in have }) {
                            val p = Store.profiles[id] ?: continue
                            Text(
                                "＋ " + p.nick, color = Txt,
                                modifier = Modifier.fillMaxWidth().clickable { scope.launch { try { Store.addMember(cid, id) } catch (e: Exception) { error = friendlyError(e.message ?: "") } } }.padding(vertical = 6.dp)
                            )
                        }
                        NxField(addNick, { addNick = it }, tr("Или ник", "Or nick", "Oder Nick"))
                        TextButton(onClick = {
                            val n = addNick.trim().lowercase()
                            scope.launch {
                                try {
                                    val r = Store.search(n).firstOrNull { it.nick.lowercase() == n }
                                    if (r == null) error = tr("Пользователь не найден", "User not found", "Nutzer nicht gefunden")
                                    else { Store.addMember(cid, r.id); addNick = ""; error = "" }
                                } catch (e: Exception) { error = friendlyError(e.message ?: "") }
                            }
                        }) { Text(tr("Добавить по нику", "Add by nick", "Per Nick hinzufügen")) }
                    }
                }
                if (error.isNotEmpty()) NxError(error)
                if (chat.kind == "group" || isAdmin) {
                    for (m in mem) {
                        val p = Store.profiles[m.userId]
                        Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
                            Avatar(p, 32.dp)
                            Text(
                                (if (m.userId == Store.myId) tr("Вы", "You", "Du") else p?.nick ?: "") +
                                    (if (m.role == "owner") " 👑" else if (m.role == "admin") " ★" else ""),
                                color = Txt, modifier = Modifier.padding(start = 10.dp).weight(1f)
                            )
                            if (isOwner && m.userId != Store.myId) {
                                Text("✕", color = TextSecondary, modifier = Modifier.clickable {
                                    scope.launch { try { Store.kickMember(cid, m.userId) } catch (e: Exception) { } }
                                }.padding(8.dp))
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (isOwner) TextButton(onClick = {
                scope.launch { try { Store.deleteChat(cid); onLeft() } catch (e: Exception) { error = friendlyError(e.message ?: "") } }
            }) { Text(tr("Удалить", "Delete", "Löschen"), color = androidx.compose.ui.graphics.Color(0xFFE5484D)) }
            else TextButton(onClick = {
                scope.launch { try { Store.leaveChat(cid); onLeft() } catch (e: Exception) { error = friendlyError(e.message ?: "") } }
            }) { Text(if (chat.kind == "channel") tr("Отписаться", "Unsubscribe", "Abbestellen") else tr("Выйти", "Leave", "Verlassen")) }
        },
        dismissButton = { TextButton(onClick = onClose) { Text(tr("Закрыть", "Close", "Schließen")) } }
    )
}
