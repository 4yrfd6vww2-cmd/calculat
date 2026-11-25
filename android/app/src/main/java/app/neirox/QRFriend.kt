package app.neirox

import android.graphics.Bitmap
import android.graphics.Color as AColor
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.launch

private const val QR_PREFIX = "neirox:add:"

/** Генерирует QR-код пикселями через ZXing, без сторонних Android-зависимостей. */
fun makeQRBitmap(text: String, size: Int = 512): Bitmap? = try {
    val matrix = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.RGB_565)
    for (x in 0 until size) {
        for (y in 0 until size) {
            bmp.setPixel(x, y, if (matrix.get(x, y)) AColor.BLACK else AColor.WHITE)
        }
    }
    bmp
} catch (e: Exception) {
    null
}

@Composable
fun AddFriendQRScreen(onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var mode by remember { mutableIntStateOf(0) }
    var error by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var scannedNick by remember { mutableStateOf<String?>(null) }

    BackHandler(onBack = onBack)

    fun startScan() {
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        GmsBarcodeScanning.getClient(ctx, options).startScan()
            .addOnSuccessListener { barcode ->
                val value = barcode.rawValue ?: ""
                val nick = if (value.startsWith(QR_PREFIX)) value.removePrefix(QR_PREFIX) else ""
                if (nick.isNotEmpty()) {
                    error = ""
                    scannedNick = nick
                } else {
                    error = tr("Это не код друга Neirox", "Not a Neirox friend code", "Kein Neirox-Freundescode")
                }
            }
            .addOnFailureListener { e -> error = friendlyError(e.message ?: "") }
    }

    Column(Modifier.fillMaxSize()) {
        ScreenTitle(tr("Добавить по QR", "Add by QR", "Per QR hinzufügen"))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            NxSmallButton(tr("Мой код", "My code", "Mein Code"), filled = mode == 0) { mode = 0 }
            NxSmallButton(tr("Сканировать", "Scan", "Scannen"), filled = mode == 1) {
                mode = 1; scannedNick = null; error = ""; startScan()
            }
        }
        Column(
            Modifier.fillMaxSize().padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            if (mode == 0) {
                val bmp = remember(Store.me?.nick) { makeQRBitmap(QR_PREFIX + (Store.me?.nick ?: "")) }
                if (bmp != null) {
                    Image(
                        bitmap = bmp.asImageBitmap(),
                        contentDescription = null,
                        modifier = Modifier
                            .size(220.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.White)
                            .padding(16.dp)
                    )
                }
                Box(Modifier.padding(top = 12.dp)) {
                    Text("@" + (Store.me?.nick ?: ""), color = TextSecondary, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
                Box(Modifier.padding(top = 16.dp)) {
                    Text(
                        tr("Покажи этот код другу — пусть отсканирует во вкладке «Сканировать»",
                            "Show this code to a friend — have them scan it under “Scan”",
                            "Zeig diesen Code einem Freund – er scannt ihn unter „Scannen“"),
                        color = TextSecondary, fontSize = 12.sp
                    )
                }
            } else {
                NxError(error)
                if (scannedNick == null) {
                    NxSmallButton(tr("Сканировать снова", "Scan again", "Erneut scannen")) { startScan() }
                } else {
                    Text("@" + scannedNick, color = Txt, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Box(Modifier.padding(top = 10.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            NxSmallButton(tr("Добавить в друзья", "Add friend", "Freund hinzufügen")) {
                                val nick = scannedNick
                                if (nick != null) {
                                    busy = true
                                    scope.launch {
                                        try {
                                            Store.sendRequestByNick(nick)
                                            onBack()
                                        } catch (e: Exception) {
                                            error = friendlyError(e.message ?: "")
                                            scannedNick = null
                                        }
                                        busy = false
                                    }
                                }
                            }
                            NxSmallButton(tr("Ещё раз", "Rescan", "Erneut"), filled = false) {
                                scannedNick = null
                                startScan()
                            }
                        }
                    }
                }
            }
        }
    }
}
