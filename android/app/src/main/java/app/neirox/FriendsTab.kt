package app.neirox

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun FriendsTab() {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<Profile>>(emptyList()) }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    LaunchedEffect(query) {
        if (query.trim().length < 2) {
            results = emptyList()
        } else {
            delay(300)
            results = Store.search(query)
        }
    }

    fun run(block: suspend () -> Unit) {
        error = ""
        scope.launch {
            try {
                block()
            } catch (e: Exception) {
                error = friendlyError(e.message ?: "")
            }
        }
    }

    @Composable
    fun Section(title: String) {
        Text(title, color = TextSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 10.dp))
    }

    @Composable
    fun PersonRow(p: Profile?, content: @Composable () -> Unit) {
        Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Avatar(p, 44.dp)
            Text(Store.dname(p) + (if (p != null && Store.alias.containsKey(p.id)) " (${p.nick})" else ""), color = Txt, fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(start = 12.dp).weight(1f))
            content()
        }
    }

    Column(Modifier.fillMaxSize()) {
        ScreenTitle(tr("Друзья", "Friends", "Freunde"))
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            NxField(query, { query = it }, tr("Найти по нику", "Search by nick", "Nach Nick suchen"), clearable = true)
            NxError(error)

            if (query.trim().length >= 2) {
                Section(tr("Результаты", "Results", "Ergebnisse"))
                if (results.isEmpty()) {
                    Text(tr("Никого не найдено", "Nobody found", "Niemand gefunden"), color = TextSecondary, fontSize = 12.sp)
                }
                for (p in results) {
                    val f = Store.friendship(p.id)
                    PersonRow(p) {
                        if (f != null) {
                            Text(
                                if (f.status == "accepted") tr("Друг", "Friend", "Freund") else tr("Заявка", "Pending", "Anfrage"),
                                color = TextSecondary, fontSize = 11.sp
                            )
                        } else {
                            NxSmallButton(tr("Добавить", "Add", "Hinzufügen")) { run { Store.sendRequest(p.id) } }
                        }
                    }
                }
            }

            if (Store.incoming.isNotEmpty()) {
                Section(tr("Заявки в друзья", "Friend requests", "Freundschaftsanfragen"))
                for (f in Store.incoming) {
                    PersonRow(Store.profiles[f.requester]) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            NxSmallButton(tr("Принять", "Accept", "Annehmen")) { run { Store.accept(f) } }
                            NxSmallButton(tr("Отклонить", "Decline", "Ablehnen"), filled = false) { run { Store.removeFriendship(f) } }
                        }
                    }
                }
            }

            Section(tr("Друзья", "Friends", "Freunde"))
            if (Store.friendIds.isEmpty()) {
                Text(
                    tr("Пока нет друзей. Найди человека по нику и отправь заявку.",
                        "No friends yet. Find someone by nick and send a request.",
                        "Noch keine Freunde. Suche jemanden per Nick und sende eine Anfrage."),
                    color = TextSecondary, fontSize = 12.sp
                )
            }
            for (id in Store.friendIds) {
                val f = Store.friendship(id)
                PersonRow(Store.profiles[id]) {
                    if (f != null) NxSmallButton(tr("Удалить", "Remove", "Entfernen"), filled = false) { run { Store.removeFriendship(f) } }
                }
            }

            if (Store.outgoing.isNotEmpty()) {
                Section(tr("Отправленные заявки", "Sent requests", "Gesendete Anfragen"))
                for (f in Store.outgoing) {
                    PersonRow(Store.profiles[f.addressee]) {
                        NxSmallButton(tr("Отменить", "Cancel", "Abbrechen"), filled = false) { run { Store.removeFriendship(f) } }
                    }
                }
            }
            androidx.compose.foundation.layout.Spacer(Modifier.padding(bottom = 20.dp))
        }
    }
}
