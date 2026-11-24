package app.neirox

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun NeiroxApp() {
    val base = LocalDensity.current
    val scale = when (Settings.textSize) {
        0 -> 0.9f
        2 -> 1.15f
        else -> 1f
    }
    val scheme = if (Settings.mode == 2) {
        lightColorScheme(primary = Accent, background = BgTop, surface = BgBottom)
    } else {
        darkColorScheme(primary = Accent, background = BgTop, surface = BgBottom)
    }
    CompositionLocalProvider(LocalDensity provides Density(base.density, base.fontScale * scale)) {
        MaterialTheme(colorScheme = scheme) {
            Box(Modifier.fillMaxSize()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Brush.verticalGradient(listOf(BgTop, BgBottom)))
                ) {
                    if (Store.loggedIn) MainScreen() else AuthFlow()
                }
                if (Store.loggedIn) Box(Modifier.align(androidx.compose.ui.Alignment.TopCenter)) { UpdateBanner() }
                if (Store.loggedIn && Calls.state != CallState.IDLE) CallScreen()
            }
        }
    }
}

@Composable
fun MainScreen() {
    var tab by remember { mutableIntStateOf(0) }
    var openChat by remember { mutableStateOf<String?>(null) }
    var openAI by remember { mutableStateOf(false) }
    var aiInitial by remember { mutableStateOf("") }

    val chatId = openChat
    if (openAI) {
        BackHandler { openAI = false; aiInitial = "" }
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            AIChatScreen(onBack = { openAI = false; aiInitial = "" }, initial = aiInitial)
        }
        return
    }
    if (chatId != null) {
        BackHandler { openChat = null }
        Column(Modifier.fillMaxSize().statusBarsPadding()) { ChatScreen(
                chatId,
                onBack = { openChat = null },
                onForwardToAI = { text ->
                    aiInitial = text
                    openChat = null
                    openAI = true
                }
            ) }
        return
    }

    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f).statusBarsPadding()) {
            when (tab) {
                0 -> ChatsTab(onOpen = { openChat = it }, onAI = { openAI = true })
                1 -> FriendsTab()
                2 -> PlayerTab()
                else -> SettingsTab()
            }
        }
        val labels = listOf(
            tr("Чаты", "Chats", "Chats"),
            tr("Друзья", "Friends", "Freunde"),
            tr("Плеер", "Player", "Player"),
            tr("Настройки", "Settings", "Einstellungen")
        )
        val icons = listOf(Icons.Filled.ChatBubble, Icons.Filled.People, Icons.Filled.MusicNote, Icons.Filled.Settings)
        NavigationBar(containerColor = BgBottom) {
            for (i in labels.indices) {
                val badge = when (i) {
                    0 -> Store.totalUnread
                    1 -> Store.incoming.size
                    else -> 0
                }
                NavigationBarItem(
                    selected = tab == i,
                    onClick = { tab = i },
                    icon = {
                        BadgedBox(badge = { if (badge > 0) Badge { Text("$badge") } }) {
                            Icon(icons[i], contentDescription = null, modifier = Modifier.size(20.dp))
                        }
                    },
                    label = { Text(labels[i], fontSize = 11.sp) },
                    colors = NavigationBarItemDefaults.colors(
                        selectedTextColor = Accent,
                        unselectedTextColor = TextSecondary,
                        indicatorColor = Accent.copy(alpha = 0.18f)
                    )
                )
            }
        }
    }
}
