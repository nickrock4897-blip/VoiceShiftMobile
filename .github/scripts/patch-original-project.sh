#!/usr/bin/env bash
set -euo pipefail

ROOT="source/app/src/main"
PKG="$ROOT/java/de/antiafk/assistant"
mkdir -p "$PKG" source/app/src/test/java/de/antiafk/assistant

python3 - <<'PY'
from pathlib import Path

def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit("Missing patch anchor in " + str(p) + ": " + label)
    p.write_text(text.replace(old, new, 1), encoding="utf-8")

main = Path("source/app/src/main/java/de/antiafk/assistant/MainActivity.kt")
text = main.read_text(encoding="utf-8")
if "import android.content.Context" not in text:
    replace_once(main, "import android.content.Intent\n", "import android.content.Context\nimport android.content.Intent\n", "Context import")

replace_once(
    main,
    "class MainActivity : ComponentActivity() {\n",
    "class MainActivity : ComponentActivity() {\n"
    "    companion object { const val EXTRA_OPEN_SCREEN_ANALYSIS = \"open_screen_analysis\" }\n",
    "screen analysis route"
)
replace_once(
    main,
    "        setContent { AntiAfkApp() }\n    }\n}\n",
    "        setContent { AntiAfkApp() }\n"
    "    }\n\n"
    "    override fun onResume() {\n"
    "        super.onResume()\n"
    "        if (SessionManager.isKeepScreenOn(this)) {\n"
    "            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n"
    "        } else {\n"
    "            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n"
    "        }\n"
    "    }\n"
    "}\n",
    "keep screen on activity flag"
)
replace_once(
    main,
    "    var page by remember { mutableStateOf(AppPage.DASHBOARD) }\n",
    "    var page by remember { mutableStateOf(\n"
    "        if ((context as? Activity)?.intent?.getBooleanExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, false) == true)\n"
    "            AppPage.SCREEN_ANALYSIS else AppPage.DASHBOARD\n"
    "    ) }\n",
    "initial screen page"
)
replace_once(
    main,
    "    var overlay by remember { mutableStateOf(SessionManager.isOverlayEnabled(context)) }\n"
    "    var dark by remember { mutableStateOf(isDark) }\n",
    "    var overlay by remember { mutableStateOf(SessionManager.isOverlayEnabled(context)) }\n"
    "    var keepScreenOn by remember { mutableStateOf(SessionManager.isKeepScreenOn(context)) }\n"
    "    var dark by remember { mutableStateOf(isDark) }\n",
    "keep screen setting state"
)
replace_once(
    main,
    "                SettingSwitch(if (english) \"Vibration\" else \"Vibration\", if (english) \"Vibrate for reminders.\" else \"Bei Erinnerungen vibrieren.\", vibration) {\n"
    "                    vibration = it; SessionManager.setVibrationEnabled(context, it); NotificationHelper.createChannels(context)\n"
    "                }\n",
    "                SettingSwitch(if (english) \"Vibration\" else \"Vibration\", if (english) \"Vibrate for reminders.\" else \"Bei Erinnerungen vibrieren.\", vibration) {\n"
    "                    vibration = it; SessionManager.setVibrationEnabled(context, it); NotificationHelper.createChannels(context)\n"
    "                }\n"
    "                HorizontalDivider()\n"
    "                SettingSwitch(\n"
    "                    if (english) \"Keep screen on\" else \"Bildschirm aktiv halten\",\n"
    "                    if (english) \"Only while this app is visible. It cannot wake a locked screen or keep another app awake.\" else \"Nur solange diese App sichtbar ist. Ein gesperrter Bildschirm wird nicht aufgeweckt und andere Apps werden nicht wach gehalten.\",\n"
    "                    keepScreenOn\n"
    "                ) {\n"
    "                    keepScreenOn = it\n"
    "                    SessionManager.setKeepScreenOn(context, it)\n"
    "                    (context as? Activity)?.window?.let { window ->\n"
    "                        if (it) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n"
    "                        else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n"
    "                    }\n"
    "                    changed()\n"
    "                }\n",
    "keep screen setting switch"
)
replace_once(
    main,
    "        Text(\"Anti-AFK Assistant · Version 1.3.0\",",
    "        Text(\"Anti-AFK Assistant · Version 1.6.2\",",
    "version label"
)
replace_once(
    main,
    "    val frameAt = remember(refresh) { ScreenAnalysisState.lastFrameAt(context) }\n",
    "    val frameAt = remember(refresh) { ScreenAnalysisState.lastFrameAt(context) }\n"
    "    val detectedStatus = remember(refresh) { ScreenAnalysisState.detectedStatus(context) }\n"
    "    val recognizedText = remember(refresh) { ScreenAnalysisState.recognizedText(context) }\n"
    "    val recognitionError = remember(refresh) { ScreenAnalysisState.lastError(context) }\n",
    "screen analysis state labels"
)
replace_once(
    main,
    "                Text(\n"
    "                    if (english) \"Android asks for permission every time. Capture stops automatically after 60 seconds. You can also stop it at any time or use the notification action.\"\n"
    "                    else \"Android fragt bei jedem Start nach deiner Zustimmung. Die Erfassung endet automatisch nach 60 Sekunden. Du kannst sie jederzeit hier oder über die Benachrichtigung beenden.\",",
    "                Text(\n"
    "                    if (english) \"Android asks for permission every time. Capture continues until you press Stop or Android interrupts the projection. You can stop it at any time using this screen or the notification.\"\n"
    "                    else \"Android fragt bei jedem Start nach deiner Zustimmung. Die Erfassung läuft, bis du Beenden drückst oder Android die Freigabe unterbricht. Du kannst sie jederzeit hier oder über die Benachrichtigung beenden.\",",
    "remove 60 sec UI limit"
)
replace_once(
    main,
    "        Text(if (english) \"Local image metrics\" else \"Lokale Bildmesswerte\", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)\n",
    "        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {\n"
    "            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {\n"
    "                Text(if (english) \"Live text recognition\" else \"Live-Texterkennung\", fontWeight = FontWeight.SemiBold)\n"
    "                Text(detectedStatus, color = MaterialTheme.colorScheme.tertiary)\n"
    "                if (recognizedText.isNotBlank()) Text(recognizedText, style = MaterialTheme.typography.bodySmall)\n"
    "                if (recognitionError.isNotBlank()) Text(recognitionError, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)\n"
    "                Text(if (english) \"On-device ML Kit OCR. These are best-effort text hints, not guaranteed game-state detection.\" else \"Lokale ML-Kit-Texterkennung. Das sind Texthinweise und keine garantierte Erkennung des Spielzustands.\", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f))\n"
    "            }\n"
    "        }\n"
    "        Text(if (english) \"Local image metrics\" else \"Lokale Bildmesswerte\", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)\n",
    "show OCR recognition"
)
replace_once(
    main,
    "                    if (english) \"Frames are processed on this device. Only the latest reduced preview is kept temporarily in the app cache and deleted when capture stops. The current build calculates basic brightness values; it does not include a trained AI model, recognize a Roblox avatar, or control another app.\"\n"
    "                    else \"Die Bilder werden nur auf diesem Gerät verarbeitet. Nur die letzte verkleinerte Vorschau liegt vorübergehend im App-Cache und wird beim Beenden gelöscht. Diese Version berechnet einfache Helligkeitswerte. Sie enthält kein trainiertes KI-Modell, erkennt keinen Roblox-Avatar und steuert keine andere App.\",",
    "                    if (english) \"Frames and OCR are processed locally. The latest reduced preview is deleted when capture stops. The app reports text hints only; it does not tap, move characters, rejoin sessions, or automate game actions.\"\n"
    "                    else \"Bilder und Texterkennung werden lokal verarbeitet. Die letzte verkleinerte Vorschau wird beim Beenden gelöscht. Die App meldet nur Texthinweise; sie klickt nicht, bewegt keine Spielfiguren, tritt keinen Sitzungen bei und automatisiert keine Spielaktionen.\",",
    "privacy scope"
)

core = Path("source/app/src/main/java/de/antiafk/assistant/SessionCore.kt")
replace_once(
    core,
    "    fun isOverlayEnabled(context: Context) = prefs(context).getBoolean(\"overlay\", false)\n"
    "    fun setOverlayEnabled(context: Context, enabled: Boolean) = prefs(context).edit().putBoolean(\"overlay\", enabled).apply()\n",
    "    fun isOverlayEnabled(context: Context) = prefs(context).getBoolean(\"overlay\", false)\n"
    "    fun setOverlayEnabled(context: Context, enabled: Boolean) = prefs(context).edit().putBoolean(\"overlay\", enabled).apply()\n"
    "    fun isKeepScreenOn(context: Context) = prefs(context).getBoolean(\"keepScreenOn\", false)\n"
    "    fun setKeepScreenOn(context: Context, enabled: Boolean) = prefs(context).edit().putBoolean(\"keepScreenOn\", enabled).apply()\n",
    "screen on preference"
)
replace_once(
    core,
    "        obj.put(\"english\", isEnglish(context))\n",
    "        obj.put(\"english\", isEnglish(context))\n"
    "        obj.put(\"keepScreenOn\", isKeepScreenOn(context))\n",
    "backup screen on preference"
)
replace_once(
    core,
    "            .putBoolean(\"english\", obj.optBoolean(\"english\", false))\n",
    "            .putBoolean(\"english\", obj.optBoolean(\"english\", false))\n"
    "            .putBoolean(\"keepScreenOn\", obj.optBoolean(\"keepScreenOn\", false))\n",
    "restore screen on preference"
)
PY

cat > "$PKG/ScreenAnalysisService.kt" <<'KOTLIN'
package de.antiafk.assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.DisplayMetrics
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.io.FileOutputStream
import kotlin.math.roundToInt

/** Explicitly authorized, read-only, local screen capture and text recognition. */
class ScreenAnalysisService : Service() {
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var workerThread: HandlerThread? = null
    private var worker: Handler? = null
    private var lastFrameAt = 0L
    @Volatile private var stopped = false
    @Volatile private var recognitionBusy = false
    private lateinit var textRecognizer: TextRecognizer

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() { stopCapture() }
    }

    override fun onCreate() {
        super.onCreate()
        workerThread = HandlerThread("screen-analysis-capture").also { it.start() }
        worker = Handler(workerThread!!.looper)
        textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopCapture()
            return START_NOT_STICKY
        }
        if (projection != null) return START_NOT_STICKY

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        val resultData = if (Build.VERSION.SDK_INT >= 33) {
            intent?.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        if (resultCode == 0 || resultData == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        stopped = false
        startAsForeground()
        try {
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val activeProjection = requireNotNull(manager.getMediaProjection(resultCode, resultData))
            projection = activeProjection
            activeProjection.registerCallback(projectionCallback, worker)
            startCapture(activeProjection)
            ScreenAnalysisState.setActive(this, true)
            ScreenAnalysisState.setRecognition(this, "", "Lokale Texterkennung aktiv", "", System.currentTimeMillis())
        } catch (error: Exception) {
            ScreenAnalysisState.setRecognition(this, "", "Aufnahme konnte nicht starten", error.localizedMessage ?: "MediaProjection-Fehler", System.currentTimeMillis())
            stopCapture()
        }
        return START_NOT_STICKY
    }

    private fun startCapture(activeProjection: MediaProjection) {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (getSystemService(WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels.coerceAtLeast(1)
        val height = metrics.heightPixels.coerceAtLeast(1)
        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2).also { reader ->
            reader.setOnImageAvailableListener({ source -> saveLatestFrame(source) }, worker)
        }
        virtualDisplay = activeProjection.createVirtualDisplay(
            "Anti-AFK Assistant read-only screen analysis",
            width,
            height,
            metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader!!.surface,
            null,
            worker
        )
    }

    private fun saveLatestFrame(reader: ImageReader) {
        if (stopped) {
            runCatching { reader.acquireLatestImage()?.close() }
            return
        }
        val now = System.currentTimeMillis()
        if (now - lastFrameAt < FRAME_INTERVAL_MILLIS) {
            runCatching { reader.acquireLatestImage()?.close() }
            return
        }
        val image = runCatching { reader.acquireLatestImage() }.getOrNull() ?: return
        try {
            val bitmap = image.toBitmap() ?: return
            val preview = if (bitmap.width > PREVIEW_MAX_WIDTH) {
                val scaledHeight = (bitmap.height * (PREVIEW_MAX_WIDTH.toFloat() / bitmap.width)).roundToInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(bitmap, PREVIEW_MAX_WIDTH, scaledHeight, true).also { if (it !== bitmap) bitmap.recycle() }
            } else bitmap

            val metrics = analyzeBasicPixels(preview)
            FileOutputStream(File(cacheDir, FRAME_FILE_NAME)).use { stream ->
                preview.compress(Bitmap.CompressFormat.JPEG, 68, stream)
            }
            ScreenAnalysisState.setMetrics(this, metrics.first, metrics.second, now)
            val ocrBitmap = runCatching { preview.copy(Bitmap.Config.ARGB_8888, false) }.getOrNull()
            if (ocrBitmap != null) runTextRecognition(ocrBitmap, now)
            preview.recycle()
            lastFrameAt = now
        } catch (error: Exception) {
            ScreenAnalysisState.setRecognition(this, "", "Bildanalyse unterbrochen", error.localizedMessage ?: "Frame-Fehler", now)
        } finally {
            image.close()
        }
    }

    private fun runTextRecognition(bitmap: Bitmap, timestamp: Long) {
        if (recognitionBusy || stopped) {
            bitmap.recycle()
            return
        }
        recognitionBusy = true
        try {
            textRecognizer.process(InputImage.fromBitmap(bitmap, 0))
                .addOnSuccessListener { result ->
                    val recognized = result.text.take(MAX_RECOGNIZED_TEXT)
                    val status = ScreenTextClassifier.classify(recognized)
                    ScreenAnalysisState.setRecognition(this, recognized, status, "", timestamp)
                    if (status.startsWith("Möglicher Verbindungsfehler")) notifyConnectionHint()
                }
                .addOnFailureListener { error ->
                    ScreenAnalysisState.setRecognition(this, "", "Texterkennung fehlgeschlagen", error.localizedMessage ?: "ML Kit-Fehler", timestamp)
                }
                .addOnCompleteListener {
                    recognitionBusy = false
                    if (!bitmap.isRecycled) bitmap.recycle()
                }
        } catch (error: Exception) {
            recognitionBusy = false
            if (!bitmap.isRecycled) bitmap.recycle()
            ScreenAnalysisState.setRecognition(this, "", "Texterkennung fehlgeschlagen", error.localizedMessage ?: "ML Kit-Fehler", timestamp)
        }
    }

    private fun notifyConnectionHint() {
        val now = System.currentTimeMillis()
        if (now - lastAlertAt < ALERT_COOLDOWN_MILLIS) return
        lastAlertAt = now
        val openIntent = Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = PendingIntent.getActivity(
            this, ALERT_REQUEST_CODE, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Möglicher Verbindungsfehler erkannt")
            .setContentText("Bitte prüfe die Meldung selbst. Es wird nichts automatisch angeklickt.")
            .setContentIntent(openPending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        runCatching { NotificationManagerCompat.from(this).notify(ALERT_NOTIFICATION_ID, notification) }
    }

    private fun analyzeBasicPixels(bitmap: Bitmap): Pair<Float, String> {
        var total = 0L
        var count = 0L
        val stepX = (bitmap.width / 48).coerceAtLeast(1)
        val stepY = (bitmap.height / 48).coerceAtLeast(1)
        for (y in 0 until bitmap.height step stepY) for (x in 0 until bitmap.width step stepX) {
            val pixel = bitmap.getPixel(x, y)
            val red = (pixel shr 16) and 0xFF
            val green = (pixel shr 8) and 0xFF
            val blue = pixel and 0xFF
            total += (0.2126 * red + 0.7152 * green + 0.0722 * blue).toLong()
            count++
        }
        val brightness = if (count == 0L) 0f else total.toFloat() / count.toFloat()
        val level = when { brightness < 70f -> "Dunkel"; brightness < 165f -> "Mittel"; else -> "Hell" }
        return brightness to level
    }

    private fun Image.toBitmap(): Bitmap? {
        val plane = planes.firstOrNull() ?: return null
        val pixelStride = plane.pixelStride
        val rowPadding = plane.rowStride - pixelStride * width
        val paddedWidth = width + (rowPadding / pixelStride)
        val padded = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
        plane.buffer.rewind()
        padded.copyPixelsFromBuffer(plane.buffer)
        val cropped = Bitmap.createBitmap(padded, 0, 0, width, height)
        if (cropped !== padded) padded.recycle()
        return cropped
    }

    private fun startAsForeground() {
        val notification = buildCaptureNotification()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else startForeground(NOTIFICATION_ID, notification)
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Bildschirmanalyse", NotificationManager.IMPORTANCE_LOW))
        }
        if (manager.getNotificationChannel(ALERT_CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(ALERT_CHANNEL_ID, "Erkannte Bildschirmhinweise", NotificationManager.IMPORTANCE_DEFAULT))
        }
    }

    private fun buildCaptureNotification(): Notification {
        val stopIntent = Intent(this, ScreenAnalysisService::class.java).setAction(ACTION_STOP)
        val stopPending = PendingIntent.getService(this, STOP_REQUEST_CODE, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val openIntent = Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = PendingIntent.getActivity(this, OPEN_REQUEST_CODE, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("Bildschirmanalyse aktiv")
            .setContentText("Lokale Texterkennung aktiv · Beenden jederzeit möglich")
            .setContentIntent(openPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Beenden", stopPending)
            .build()
    }

    private fun stopCapture() {
        if (stopped) return
        stopped = true
        runCatching { virtualDisplay?.release() }
        virtualDisplay = null
        runCatching { imageReader?.setOnImageAvailableListener(null, null) }
        runCatching { imageReader?.close() }
        imageReader = null
        runCatching { projection?.unregisterCallback(projectionCallback) }
        runCatching { projection?.stop() }
        projection = null
        ScreenAnalysisState.setActive(this, false)
        ScreenAnalysisState.setRecognition(this, "", "Bildschirmaufnahme beendet", "", System.currentTimeMillis())
        runCatching { File(cacheDir, FRAME_FILE_NAME).delete() }
        runCatching { if (::textRecognizer.isInitialized) textRecognizer.close() }
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopCapture()
        workerThread?.quitSafely()
        workerThread = null
        worker = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val EXTRA_RESULT_CODE = "screen_result_code"
        const val EXTRA_RESULT_DATA = "screen_result_data"
        const val ACTION_STOP = "de.antiafk.assistant.screen.STOP"
        const val FRAME_FILE_NAME = "screen_analysis_latest.jpg"
        private const val CHANNEL_ID = "screen_analysis"
        private const val ALERT_CHANNEL_ID = "screen_analysis_alerts"
        private const val NOTIFICATION_ID = 5811
        private const val ALERT_NOTIFICATION_ID = 5814
        private const val PREVIEW_MAX_WIDTH = 720
        private const val FRAME_INTERVAL_MILLIS = 1_500L
        private const val MAX_RECOGNIZED_TEXT = 1_200
        private const val ALERT_COOLDOWN_MILLIS = 60_000L
        private const val STOP_REQUEST_CODE = 5812
        private const val OPEN_REQUEST_CODE = 5813
        private const val ALERT_REQUEST_CODE = 5815
        private var lastAlertAt = 0L

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenAnalysisService::class.java))
        }
    }
}

internal object ScreenAnalysisState {
    private const val PREFS = "screen_analysis_state"
    fun isActive(context: Context) = prefs(context).getBoolean("active", false)
    fun brightness(context: Context) = prefs(context).getFloat("brightness", 0f)
    fun level(context: Context) = prefs(context).getString("level", "–") ?: "–"
    fun lastFrameAt(context: Context) = prefs(context).getLong("last_frame_at", 0L)
    fun detectedStatus(context: Context) = prefs(context).getString("detected_status", "Noch keine Analyse") ?: "Noch keine Analyse"
    fun recognizedText(context: Context) = prefs(context).getString("recognized_text", "") ?: ""
    fun lastError(context: Context) = prefs(context).getString("last_error", "") ?: ""
    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun setActive(context: Context, active: Boolean) { prefs(context).edit().putBoolean("active", active).apply() }
    fun setRecognition(context: Context, text: String, status: String, error: String, timestamp: Long) {
        prefs(context).edit()
            .putString("recognized_text", text.take(1_200))
            .putString("detected_status", status.take(160))
            .putString("last_error", error.take(300))
            .putLong("last_analysis_at", timestamp)
            .apply()
    }
    fun setMetrics(context: Context, brightness: Float, level: String, timestamp: Long) {
        prefs(context).edit()
            .putFloat("brightness", brightness)
            .putString("level", level)
            .putLong("last_frame_at", timestamp)
            .apply()
    }
}
KOTLIN

cat > "$PKG/ScreenTextClassifier.kt" <<'KOTLIN'
package de.antiafk.assistant

import java.util.Locale

internal object ScreenTextClassifier {
    fun classify(rawText: String): String {
        val text = rawText.lowercase(Locale.ROOT).replace('\n', ' ').replace(Regex("\\s+"), " ").trim()
        if (text.isBlank()) return "Kein lesbarer Text erkannt"
        val connection = listOf("disconnected", "connection error", "lost connection", "connection lost", "error code", "removed from the experience", "verbindung getrennt", "verbindung verloren", "verbindungsfehler", "sitzung beendet", "aus dem spiel entfernt")
        if (connection.any(text::contains)) return "Möglicher Verbindungsfehler – bitte selbst prüfen"
        val loading = listOf("loading", "joining server", "connecting", "teleporting", "wird geladen", "verbindung wird hergestellt", "server wird gesucht", "wird verbunden")
        if (loading.any(text::contains)) return "Möglicher Lade- oder Verbindungsbildschirm"
        val ui = listOf("chat", "players", "settings", "avatar", "inventory", "friends", "discover", "home", "spieler", "einstellungen")
        if (ui.count(text::contains) >= 2) return "Mögliche Spieloberfläche – Menütitel erkannt"
        if (text.contains("roblox")) return "Roblox-Text erkannt"
        return "Text erkannt – kein bekannter Status"
    }
}
KOTLIN

cat > "$PKG/FloatingAssistantService.kt" <<'KOTLIN'
package de.antiafk.assistant

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.util.Locale

/** Movable, read-only session overlay. It does not generate input in other apps. */
class FloatingAssistantService : Service() {
    private lateinit var windowManager: WindowManager
    private val prefs by lazy { getSharedPreferences("floating_assistant", Context.MODE_PRIVATE) }
    private val handler = Handler(Looper.getMainLooper())
    private var panel: LinearLayout? = null
    private var bubble: TextView? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var timer: TextView? = null
    private var status: TextView? = null
    private var analysis: TextView? = null
    private var reminderDeadline: Long? = null
    private var reminderDone = false

    private val ticker = object : Runnable {
        override fun run() {
            refreshPanel()
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createChannels(this)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(4103, NotificationHelper.overlayForegroundNotification(this), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(4103, NotificationHelper.overlayForegroundNotification(this))
        }
        if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        showPanel()
        handler.post(ticker)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY

    private fun showPanel() {
        if (panel != null) return
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(13), dp(12), dp(13), dp(13))
            background = rounded(0xF01A2032.toInt(), 18)
            elevation = dp(12).toFloat()
        }
        val heading = label("ANTI-AFK ASSISTANT", 13, Color.WHITE, true)
        heading.setPadding(dp(4), dp(3), dp(4), dp(9))
        root.addView(heading, matchWrap())

        status = label("AFK AUS", 14, 0xFFFFC56B.toInt(), true).apply { gravity = Gravity.CENTER }
        root.addView(status, matchWrap())
        timer = label("00:00:00", 27, Color.WHITE, true).apply { gravity = Gravity.CENTER }
        root.addView(timer, matchWrap())

        val sessionRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        root.addView(sessionRow, top(matchWrap(), 8))
        addButton(sessionRow, "AFK EIN", 0xFF246D54.toInt(), 1f) {
            SessionManager.start(this)
            NotificationHelper.showSessionStatus(this)
            refreshPanel()
        }
        addButton(sessionRow, "AFK AUS", 0xFF8B3E4A.toInt(), 1f) {
            SessionManager.stop(this)
            NotificationHelper.cancelStatus(this)
            refreshPanel()
        }

        val pauseRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        root.addView(pauseRow, top(matchWrap(), 5))
        addButton(pauseRow, "Pause / Weiter", 0xFF46506B.toInt(), 1f) {
            when (SessionManager.snapshot(this).status) {
                SessionManager.RUNNING -> SessionManager.pause(this)
                SessionManager.PAUSED -> SessionManager.resume(this)
            }
            NotificationHelper.showSessionStatus(this)
            refreshPanel()
        }

        analysis = label("LIVE-TEXTERKENNUNG: AUS", 12, 0xFFC3CEE8.toInt(), false).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(5))
        }
        root.addView(analysis, matchWrap())
        addButton(root, "Bildschirm-Analyse öffnen", 0xFF38435E.toInt(), 1f) {
            val intent = Intent(this, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        }
        addButton(root, "60-Sekunden-Erinnerung", 0xFF3B4560.toInt(), 1f) { toggleReminder() }
        addButton(root, "NOT-AUS · TIMER UND ANALYSE STOPPEN", 0xFF9A3545.toInt(), 1f) {
            SessionManager.stop(this)
            NotificationHelper.cancelStatus(this)
            ScreenAnalysisService.stop(this)
            refreshPanel()
        }
        addButton(root, "Menü einklappen", 0xFF303A52.toInt(), 1f) { minimizePanel() }

        panel = root
        val layout = WindowManager.LayoutParams(
            dp(278), WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("panel_x", dp(14))
            y = prefs.getInt("panel_y", dp(90))
        }
        panelParams = layout
        heading.setOnTouchListener { view, event -> drag(view, event, layout, "panel") }
        runCatching { windowManager.addView(root, layout) }.onFailure {
            panel = null
            panelParams = null
            stopSelf()
        }
        refreshPanel()
    }

    private fun minimizePanel() {
        panel?.let { runCatching { windowManager.removeView(it) } }
        panel = null
        panelParams = null
        timer = null
        status = null
        analysis = null
        showBubble()
    }

    private fun showBubble() {
        if (bubble != null) return
        val view = label("AFK", 12, Color.WHITE, true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(13), dp(12), dp(13), dp(12))
            background = rounded(0xFF2B304F.toInt(), 28)
            elevation = dp(8).toFloat()
        }
        bubble = view
        val layout = WindowManager.LayoutParams(
            dp(58), dp(58),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("bubble_x", dp(16))
            y = prefs.getInt("bubble_y", dp(180))
        }
        bubbleParams = layout
        view.setOnTouchListener { target, event ->
            drag(target, event, layout, "bubble")
        }
        runCatching { windowManager.addView(view, layout) }.onFailure {
            bubble = null
            bubbleParams = null
            stopSelf()
        }
    }

    private fun drag(view: View, event: MotionEvent, params: WindowManager.LayoutParams, key: String): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                view.setTag(floatArrayOf(event.rawX, event.rawY, params.x.toFloat(), params.y.toFloat()))
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val origin = view.tag as? FloatArray ?: return true
                params.x = (origin[2] + event.rawX - origin[0]).toInt().coerceAtLeast(0)
                params.y = (origin[3] + event.rawY - origin[1]).toInt().coerceAtLeast(0)
                runCatching { windowManager.updateViewLayout(view, params) }
                return true
            }
            MotionEvent.ACTION_UP -> {
                val origin = view.tag as? FloatArray
                if (origin != null) {
                    val moved = kotlin.math.abs(event.rawX - origin[0]) > dp(5) || kotlin.math.abs(event.rawY - origin[1]) > dp(5)
                    if (moved) {
                        prefs.edit().putInt(key + "_x", params.x).putInt(key + "_y", params.y).apply()
                    } else if (key == "bubble") {
                        removeBubble()
                        showPanel()
                    }
                }
                view.tag = null
                return true
            }
        }
        return true
    }

    private fun removeBubble() {
        bubble?.let { runCatching { windowManager.removeView(it) } }
        bubble = null
        bubbleParams = null
    }

    private fun refreshPanel() {
        val snapshot = SessionManager.snapshot(this)
        val running = snapshot.status == SessionManager.RUNNING
        val paused = snapshot.status == SessionManager.PAUSED
        status?.text = when {
            running -> "AFK AKTIV"
            paused -> "AFK PAUSIERT"
            else -> "AFK AUS"
        }
        status?.setTextColor(if (running) 0xFF70D5A0.toInt() else 0xFFFFC56B.toInt())
        val seconds = snapshot.elapsedMillis.coerceAtLeast(0L) / 1_000L
        val formatted = String.format(Locale.getDefault(), "%02d:%02d:%02d", seconds / 3600L, (seconds % 3600L) / 60L, seconds % 60L)
        timer?.text = formatted
        analysis?.text = if (ScreenAnalysisState.isActive(this)) {
            "LIVE-TEXTERKENNUNG: AKTIV\n" + ScreenAnalysisState.detectedStatus(this)
        } else {
            "LIVE-TEXTERKENNUNG: AUS\n" + ScreenAnalysisState.detectedStatus(this)
        }
        bubble?.text = if (running) "AFK\n" + formatted else "AFK"
        val deadline = reminderDeadline
        if (deadline != null) {
            val remaining = ManualReminderCountdown.remainingSeconds(deadline, SystemClock.elapsedRealtime())
            if (remaining <= 0) {
                reminderDeadline = null
                reminderDone = true
                NotificationHelper.sendManualOverlayReminder(this)
            } else {
                // The reminder countdown remains a separate manual reminder, not simulated activity.
            }
        }
    }

    private fun toggleReminder() {
        if (reminderDeadline != null) {
            reminderDeadline = null
            reminderDone = false
        } else {
            reminderDeadline = SystemClock.elapsedRealtime() + ManualReminderCountdown.DURATION_MS
            reminderDone = false
        }
        refreshPanel()
    }

    private fun addButton(parent: LinearLayout, text: String, color: Int, weight: Float, action: () -> Unit) {
        val button = Button(this).apply {
            this.text = text
            isAllCaps = false
            textSize = 12f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = rounded(color, 12)
            minHeight = dp(43)
            setPadding(dp(4), dp(2), dp(4), dp(2))
            setOnClickListener { action() }
        }
        val params = if (parent.orientation == LinearLayout.HORIZONTAL) {
            LinearLayout.LayoutParams(0, dp(44), weight)
        } else {
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(44))
        }
        if (parent.childCount > 0) params.topMargin = dp(5)
        if (parent.orientation == LinearLayout.HORIZONTAL && parent.childCount > 0) params.marginStart = dp(7)
        parent.addView(button, params)
    }

    private fun label(text: String, size: Int, color: Int, bold: Boolean) = TextView(this).apply {
        this.text = text
        textSize = size.toFloat()
        setTextColor(color)
        if (bold) typeface = Typeface.DEFAULT_BOLD
    }

    private fun rounded(color: Int, radius: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radius).toFloat()
    }

    private fun matchWrap() = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
    private fun top(params: LinearLayout.LayoutParams, margin: Int): LinearLayout.LayoutParams { params.topMargin = dp(margin); return params }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        removeBubble()
        panel?.let { runCatching { windowManager.removeView(it) } }
        panel = null
        NotificationHelper.cancelOverlayNotification(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, FloatingAssistantService::class.java))
        }
    }
}
KOTLIN

cat > source/app/src/test/java/de/antiafk/assistant/ScreenTextClassifierTest.kt <<'KOTLIN'
package de.antiafk.assistant

import org.junit.Assert.assertTrue
import org.junit.Test

class ScreenTextClassifierTest {
    @Test fun detectsConnectionHint() {
        assertTrue(ScreenTextClassifier.classify("Connection lost Error code 277").contains("Verbindungsfehler"))
    }
    @Test fun detectsLoadingHint() {
        assertTrue(ScreenTextClassifier.classify("Joining server").contains("Lade"))
    }
    @Test fun reportsEmptyTextHonestly() {
        assertTrue(ScreenTextClassifier.classify("").contains("Kein lesbarer Text"))
    }
}
KOTLIN

grep -q 'ScreenAnalysisService' "$ROOT/AndroidManifest.xml"
grep -q 'FloatingAssistantService' "$ROOT/AndroidManifest.xml"
echo "Patched original Kotlin app without deleting dashboard, profiles, statistics or existing reminders."
