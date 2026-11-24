package app.neirox

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private fun fmt(s: Float): String {
    val t = s.toInt()
    return "%d:%02d".format(t / 60, t % 60)
}

@Composable
fun PlayerTab() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var importing by remember { mutableStateOf(false) }
    var info by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        while (true) {
            Player.tick()
            delay(500)
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isNotEmpty()) {
            importing = true
            scope.launch {
                val (added, failed) = withContext(Dispatchers.IO) { Player.import(ctx, uris) }
                info = if (failed > 0) {
                    tr("Добавлено: $added. Не добавлено: $failed (принимаются MP3, M4A и MP4).",
                        "Added: $added. Skipped: $failed (MP3, M4A and MP4 only).",
                        "Hinzugefügt: $added. Übersprungen: $failed (nur MP3, M4A und MP4).")
                } else {
                    tr("Добавлено: $added", "Added: $added", "Hinzugefügt: $added")
                }
                importing = false
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.weight(1f)) { ScreenTitle(tr("Плеер", "Player", "Player")) }
            Box(Modifier.padding(end = 20.dp)) {
                NxSmallButton("+ " + tr("Добавить", "Add", "Hinzufügen")) { picker.launch(arrayOf("audio/mpeg", "audio/*", "video/mp4")) }
            }
        }
        if (importing || info.isNotEmpty()) {
            Text(
                if (importing) tr("Копирую файлы…", "Copying files…", "Dateien werden kopiert …") else info,
                color = TextSecondary, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)
            )
        }

        if (Player.tracks.isEmpty()) {
            Text(
                tr("Добавь MP3- или MP4-файлы с телефона. Они сохранятся в приложении и не пропадут после перезапуска.",
                    "Add MP3 or MP4 files from your device. They are stored in the app and stay after restart.",
                    "Füge MP3- oder MP4-Dateien von deinem Gerät hinzu. Sie bleiben in der App gespeichert."),
                color = TextSecondary, fontSize = 12.sp, modifier = Modifier.padding(20.dp).weight(1f)
            )
        } else {
            LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
                itemsIndexed(Player.tracks, key = { _, f -> f.name }) { i, f ->
                    val current = i == Player.currentIndex
                    Row(
                        Modifier.fillMaxWidth().clickable { Player.play(i) }.padding(horizontal = 20.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(if (current && Player.playing) "▶" else "♪", color = if (current) Accent else TextSecondary, fontSize = 16.sp)
                        Text(
                            f.nameWithoutExtension,
                            color = if (current) Accent else Txt,
                            fontSize = 14.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(start = 12.dp).weight(1f)
                        )
                        Icon(Icons.Filled.Delete, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(18.dp).clickable { Player.delete(i) }.padding(8.dp))
                    }
                }
            }
        }

        Column(
            Modifier.fillMaxWidth().background(BgBottom).padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                Player.currentTitle ?: tr("Ничего не играет", "Nothing playing", "Nichts läuft"),
                color = Txt, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis
            )
            Slider(
                value = Player.position.coerceIn(0f, maxOf(Player.duration, 0.1f)),
                onValueChange = { Player.seek(it) },
                valueRange = 0f..maxOf(Player.duration, 0.1f),
                colors = SliderDefaults.colors(thumbColor = Accent, activeTrackColor = Accent)
            )
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(fmt(Player.position), color = TextSecondary, fontSize = 12.sp)
                Text(fmt(Player.duration), color = TextSecondary, fontSize = 12.sp)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(36.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("⏮", fontSize = 24.sp, modifier = Modifier.clickable { Player.prev() }.padding(8.dp))
                Text(if (Player.playing) "⏸" else "▶️", fontSize = 32.sp, modifier = Modifier.clickable { Player.toggle() }.padding(8.dp))
                Text("⏭", fontSize = 24.sp, modifier = Modifier.clickable { Player.next() }.padding(8.dp))
            }
        }
    }
}
