package app.neirox

// Лёгкий мост без зависимостей от Firebase: основной (main) код задаёт эти
// коллбэки здесь, а реальную FCM-реализацию подключает только push-only
// исходный набор (см. build.gradle.kts), который компилируется лишь для
// обычной (не android_old) сборки. Так main-код не знает про Firebase
// напрямую, и замороженная android_old сборка остаётся без изменений.
object PushHook {
    var onReady: (() -> Unit)? = null
    var onLogout: (() -> Unit)? = null
}
