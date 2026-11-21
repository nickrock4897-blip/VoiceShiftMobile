#!/usr/bin/env bash
set -euo pipefail

ROOT="source/app/src/main"
PKG="$ROOT/java/de/antiafk/assistant"
mkdir -p "$PKG"

python3 - <<'PY'
from pathlib import Path

def patch(path, replacements):
    p = Path(path)
    source = p.read_text(encoding="utf-8")
    for old, new, label in replacements:
        if old not in source:
            raise SystemExit("Patch anchor missing in " + str(p) + ": " + label)
        source = source.replace(old, new, 1)
    p.write_text(source, encoding="utf-8")

screen = "source/app/src/main/java/de/antiafk/assistant/ScreenAnalysisService.kt"
patch(screen, [
(
"import androidx.core.app.NotificationCompat\n",
"import androidx.core.app.NotificationCompat\nimport androidx.core.app.NotificationManagerCompat\nimport com.google.mlkit.vision.common.InputImage\nimport com.google.mlkit.vision.text.TextRecognition\nimport com.google.mlkit.vision.text.TextRecognizer\nimport com.google.mlkit.vision.text.latin.TextRecognizerOptions\n",
"mlkit imports"
),
(
"    private var lastFrameAt = 0L\n    private var stopped = false\n",
"    private var lastFrameAt = 0L\n    private var stopped = false\n    @Volatile private var recognitionBusy = false\n    private var lastErrorNotificationAt = 0L\n    private lateinit var textRecognizer: TextRecognizer\n",
"recognizer fields"
),
(
"    private val autoStop = Runnable { stopCapture() }\n\n",
"",
"remove automatic stop runnable"
),
(
"        worker = Handler(workerThread!!.looper)\n        createChannel()\n",
"        worker = Handler(workerThread!!.looper)\n        textRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)\n        createChannel()\n",
"create on-device recognizer"
),
(
"            ScreenAnalysisState.setActive(this, true)\n            worker?.postDelayed(autoStop, MAX_CAPTURE_MILLIS)\n",
"            ScreenAnalysisState.setActive(this, true)\n            ScreenAnalysisState.setRecognition(this, \"\", \"Lokale Texterkennung aktiv\", \"\", System.currentTimeMillis())\n",
"remove 60 sec hard stop"
),
(
"            val metrics = analyzeBasicPixels(preview)\n            val output = File(cacheDir, FRAME_FILE_NAME)\n            FileOutputStream(output).use { stream ->\n                preview.compress(Bitmap.CompressFormat.JPEG, 68, stream)\n            }\n            ScreenAnalysisState.setMetrics(this, metrics.first, metrics.second, now)\n            lastFrameAt = now\n            preview.recycle()\n",
"            val metrics = analyzeBasicPixels(preview)\n            val output = File(cacheDir, FRAME_FILE_NAME)\n            FileOutputStream(output).use { stream ->\n                preview.compress(Bitmap.CompressFormat.JPEG, 68, stream)\n            }\n            ScreenAnalysisState.setMetrics(this, metrics.first, metrics.second, now)\n            val ocrCopy = runCatching { preview.copy(Bitmap.Config.ARGB_8888, false) }.getOrNull()\n            if (ocrCopy != null) runTextRecognition(ocrCopy, now)\n            lastFrameAt = now\n            preview.recycle()\n",
"run local OCR for each sampled frame"
),
(
"    /** Basic on-device image statistics, not an AI/object-recognition model. */\n",
"    private fun runTextRecognition(bitmap: Bitmap, timestamp: Long) {\n        if (recognitionBusy) {\n            bitmap.recycle()\n            return\n        }\n        recognitionBusy = true\n        try {\n            textRecognizer.process(InputImage.fromBitmap(bitmap, 0))\n                .addOnSuccessListener { result ->\n                    val text = result.text.take(1_200)\n                    val status = ScreenTextClassifier.classify(text)\n                    ScreenAnalysisState.setRecognition(this, text, status, \"\", timestamp)\n                    if (status.startsWith(\"Möglicher Verbindungsfehler\")) notifyConnectionHint()\n                }\n                .addOnFailureListener { error ->\n                    ScreenAnalysisState.setRecognition(\n                        this, \"\", \"Texterkennung fehlgeschlagen\", error.localizedMessage ?: \"Unbekannter ML-Kit-Fehler\", timestamp\n                    )\n                }\n                .addOnCompleteListener {\n                    recognitionBusy = false\n                    if (!bitmap.isRecycled) bitmap.recycle()\n                }\n        } catch (error: Exception) {\n            recognitionBusy = false\n            if (!bitmap.isRecycled) bitmap.recycle()\n            ScreenAnalysisState.setRecognition(\n                this, \"\", \"Texterkennung fehlgeschlagen\", error.localizedMessage ?: \"Unbekannter Fehler\", timestamp\n            )\n        }\n    }\n\n    private fun notifyConnectionHint() {\n        val now = System.currentTimeMillis()\n        if (now - lastErrorNotificationAt < 60_000L) return\n        lastErrorNotificationAt = now\n        val openIntent = Intent(this, MainActivity::class.java)\n            .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)\n            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)\n        val pending = PendingIntent.getActivity(\n            this, 5815, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE\n        )\n        NotificationManagerCompat.from(this).notify(\n            5814,\n            NotificationCompat.Builder(this, ALERT_CHANNEL_ID)\n                .setSmallIcon(android.R.drawable.ic_dialog_info)\n                .setContentTitle(\"Möglicher Verbindungsfehler erkannt\")\n                .setContentText(\"Bitte prüfe die Meldung selbst. Es wird nichts automatisch angeklickt.\")\n                .setContentIntent(pending)\n                .setAutoCancel(true)\n                .setPriority(NotificationCompat.PRIORITY_DEFAULT)\n                .build()\n        )\n    }\n\n    /** Basic on-device image statistics. Text recognition is provided separately by ML Kit. */\n",
"insert OCR helper and passive notification"
),
(
"            manager.createNotificationChannel(\n                    NotificationChannel(CHANNEL_ID, \"Bildschirmanalyse\", NotificationManager.IMPORTANCE_LOW).apply {\n                        description = \"Zeigt an, wenn die ausdrücklich gestartete Bildschirmvorschau aktiv ist.\"\n                    }\n                )\n",
"            manager.createNotificationChannel(\n                    NotificationChannel(CHANNEL_ID, \"Bildschirmanalyse\", NotificationManager.IMPORTANCE_LOW).apply {\n                        description = \"Zeigt an, wenn die ausdrücklich gestartete Bildschirmvorschau aktiv ist.\"\n                    }\n                )\n            }\n            if (manager.getNotificationChannel(ALERT_CHANNEL_ID) == null) {\n                manager.createNotificationChannel(\n                    NotificationChannel(ALERT_CHANNEL_ID, \"Erkannte Bildschirmhinweise\", NotificationManager.IMPORTANCE_DEFAULT).apply {\n                        description = \"Meldet lokal erkannte mögliche Verbindungs- oder Fehlermeldungen.\"\n                    }\n                )\n            }\n",
"add notifications channel"
),
(
"            .setContentText(\"Lokale Analyse · endet automatisch nach 60 Sekunden\")\n",
"            .setContentText(\"Lokale Texterkennung aktiv · Beenden jederzeit über diese Benachrichtigung\")\n",
"update capture notification"
),
(
"        worker?.removeCallbacks(autoStop)\n",
"",
"remove 60 sec callback cleanup"
),
(
"        runCatching { projection?.stop() }\n        projection = null\n",
"        runCatching { projection?.stop() }\n        projection = null\n        runCatching { if (::textRecognizer.isInitialized) textRecognizer.close() }\n",
"release ML Kit resources"
),
(
"        private const val CHANNEL_ID = \"screen_analysis\"\n",
"        private const val CHANNEL_ID = \"screen_analysis\"\n        private const val ALERT_CHANNEL_ID = \"screen_analysis_alerts\"\n",
"alert channel id"
),
(
"        private const val FRAME_INTERVAL_MILLIS = 1_000L\n        private const val MAX_CAPTURE_MILLIS = 60_000L\n",
"        private const val FRAME_INTERVAL_MILLIS = 1_500L\n",
"remove capture duration cap"
),
(
"    fun lastFrameAt(context: Context): Long = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(\"last_frame_at\", 0L)\n",
"    fun lastFrameAt(context: Context): Long = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(\"last_frame_at\", 0L)\n    fun detectedStatus(context: Context): String = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(\"detected_status\", \"Noch keine Analyse\") ?: \"Noch keine Analyse\"\n    fun recognizedText(context: Context): String = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(\"recognized_text\", \"\") ?: \"\"\n    fun lastError(context: Context): String = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(\"last_error\", \"\") ?: \"\"\n",
"expose OCR state"
),
(
"    fun setMetrics(context: Context, brightness: Float, level: String, timestamp: Long) {\n",
"    fun setRecognition(context: Context, text: String, status: String, error: String, timestamp: Long) {\n        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()\n            .putString(\"recognized_text\", text.take(1_200))\n            .putString(\"detected_status\", status.take(160))\n            .putString(\"last_error\", error.take(300))\n            .putLong(\"last_analysis_at\", timestamp)\n            .apply()\n    }\n\n    fun setMetrics(context: Context, brightness: Float, level: String, timestamp: Long) {\n",
"store recognition result"
)
])

# Apply the capture duration and scope text in the UI; add live OCR status fields.
main = "source/app/src/main/java/de/antiafk/assistant/MainActivity.kt"
patch(main, [
(
"import androidx.compose.runtime.remember\n",
"import androidx.compose.runtime.remember\nimport androidx.compose.runtime.SideEffect\n",
"SideEffect import"
),
(
"class MainActivity : ComponentActivity() {\n    override fun onCreate(savedInstanceState: Bundle?) {\n",
"class MainActivity : ComponentActivity() {\n    companion object { const val EXTRA_OPEN_SCREEN_ANALYSIS = \"open_screen_analysis\" }\n\n    override fun onCreate(savedInstanceState: Bundle?) {\n",
"open screen analysis intent"
),
(
"        setContent { AntiAfkApp() }\n    }\n}\n",
"        setContent { AntiAfkApp() }\n    }\n\n    override fun onResume() {\n        super.onResume()\n        if (SessionManager.isKeepScreenOn(this)) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n        else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n    }\n}\n",
"apply display flag only while activity visible"
),
(
"    var page by remember { mutableStateOf(AppPage.DASHBOARD) }\n",
"    var page by remember { mutableStateOf(if ((context as? Activity)?.intent?.getBooleanExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, false) == true) AppPage.SCREEN_ANALYSIS else AppPage.DASHBOARD) }\n",
"initialize requested screen page"
),
(
"    var overlay by remember { mutableStateOf(SessionManager.isOverlayEnabled(context)) }\n    var dark by remember { mutableStateOf(isDark) }\n",
"    var overlay by remember { mutableStateOf(SessionManager.isOverlayEnabled(context)) }\n    var keepScreenOn by remember { mutableStateOf(SessionManager.isKeepScreenOn(context)) }\n    var dark by remember { mutableStateOf(isDark) }\n",
"keep screen state"
),
(
"    var message by remember { mutableStateOf(\"\") }\n\n    val overlayPermissionLauncher",
"    var message by remember { mutableStateOf(\"\") }\n    SideEffect {\n        val activity = context as? Activity\n        activity?.window?.let { window ->\n            if (keepScreenOn) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n            else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)\n        }\n    }\n\n    val overlayPermissionLauncher",
"apply screen on flag while visible"
),
(
"                SettingSwitch(if (english) \"Vibration\" else \"Vibration\", if (english) \"Vibrate for reminders.\" else \"Bei Erinnerungen vibrieren.\", vibration) {\n                    vibration = it; SessionManager.setVibrationEnabled(context, it); NotificationHelper.createChannels(context)\n                }\n",
"                SettingSwitch(if (english) \"Vibration\" else \"Vibration\", if (english) \"Vibrate for reminders.\" else \"Bei Erinnerungen vibrieren.\", vibration) {\n                    vibration = it; SessionManager.setVibrationEnabled(context, it); NotificationHelper.createChannels(context)\n                }\n                HorizontalDivider()\n                SettingSwitch(\n                    if (english) \"Keep screen on\" else \"Bildschirm aktiv halten\",\n                    if (english) \"Only while this app is visible. It cannot wake a locked screen or control another app.\" else \"Nur solange diese App sichtbar ist. Ein gesperrter Bildschirm wird nicht aufgeweckt und andere Apps werden nicht gesteuert.\",\n                    keepScreenOn\n                ) {\n                    keepScreenOn = it\n                    SessionManager.setKeepScreenOn(context, it)\n                    changed()\n                }\n",
"add safe keep-screen-on setting"
),
(
"        Text(\"Anti-AFK Assistant · Version 1.3.0\",",
"        Text(\"Anti-AFK Assistant · Version 1.6.0\",",
"version label"
),
(
"    val frameAt = remember(refresh) { ScreenAnalysisState.lastFrameAt(context) }\n",
"    val frameAt = remember(refresh) { ScreenAnalysisState.lastFrameAt(context) }\n    val detectedStatus = remember(refresh) { ScreenAnalysisState.detectedStatus(context) }\n    val recognizedText = remember(refresh) { ScreenAnalysisState.recognizedText(context) }\n    val recognitionError = remember(refresh) { ScreenAnalysisState.lastError(context) }\n",
"read live OCR status"
),
(
"                    if (english) \"Android asks for permission every time. Capture stops automatically after 60 seconds. You can also stop it at any time or use the notification action.\"\n                    else \"Android fragt bei jedem Start nach deiner Zustimmung. Die Erfassung endet automatisch nach 60 Sekunden. Du kannst sie jederzeit hier oder über die Benachrichtigung beenden.\",\n",
"                    if (english) \"Android asks for your permission each time. Capture continues until you press Stop or Android ends the projection. A persistent notification remains visible.\"\n                    else \"Android fragt bei jedem Start nach deiner Zustimmung. Die Erfassung läuft bis du Beenden drückst oder Android die Freigabe beendet. Eine dauerhafte Benachrichtigung bleibt sichtbar.\",\n",
"remove 60 sec copy"
),
(
"        Text(if (english) \"Local image metrics\" else \"Lokale Bildmesswerte\", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)\n",
"        Text(if (english) \"Live text analysis\" else \"Live-Texterkennung\", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)\n        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(20.dp)) {\n            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {\n                Text(if (english) \"Detected status\" else \"Erkannter Status\", fontWeight = FontWeight.SemiBold)\n                Text(detectedStatus, color = MaterialTheme.colorScheme.tertiary)\n                if (recognizedText.isNotBlank()) {\n                    Text(if (english) \"Recognized text\" else \"Erkannter Text\", fontWeight = FontWeight.SemiBold)\n                    Text(recognizedText, style = MaterialTheme.typography.bodySmall)\n                }\n                if (recognitionError.isNotBlank()) Text((if (english) \"Analysis error: \" else \"Analysefehler: \") + recognitionError, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)\n                Text(if (english) \"On-device ML Kit text recognition. Status labels are best-effort text hints, not guaranteed game-state detection.\" else \"Lokale ML-Kit-Texterkennung auf dem Gerät. Statusmeldungen sind Texthinweise und keine garantierte Erkennung des Spielzustands.\", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f))\n            }\n        }\n        Text(if (english) \"Local image metrics\" else \"Lokale Bildmesswerte\", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)\n",
"show live OCR info"
),
(
"                    if (english) \"Frames are processed on this device. Only the latest reduced preview is kept temporarily in the app cache and deleted when capture stops. The current build calculates basic brightness values; it does not include a trained AI model, recognize a Roblox avatar, or control another app.\"\n                    else \"Die Bilder werden nur auf diesem Gerät verarbeitet. Nur die letzte verkleinerte Vorschau liegt vorübergehend im App-Cache und wird beim Beenden gelöscht. Diese Version berechnet einfache Helligkeitswerte. Sie enthält kein trainiertes KI-Modell, erkennt keinen Roblox-Avatar und steuert keine andere App.\",\n",
"                    if (english) \"Frames and text recognition are processed locally. The latest reduced preview stays in app cache and is deleted when capture stops. The app reports text hints only; it does not tap, move a character, join sessions, or bypass game rules.\"\n                    else \"Bilder und Texterkennung werden lokal verarbeitet. Die letzte verkleinerte Vorschau bleibt nur vorübergehend im App-Cache und wird beim Beenden gelöscht. Die App meldet nur Texthinweise; sie tippt nicht, bewegt keine Spielfigur, tritt keinen Sitzungen bei und umgeht keine Spielregeln.\",\n",
"update privacy and capability statement"
)
])

# Store the screen-on preference with the other local settings/backups.
core = "source/app/src/main/java/de/antiafk/assistant/SessionCore.kt"
patch(core, [
(
"    fun isOverlayEnabled(context: Context) = prefs(context).getBoolean(\"overlay\", false)\n    fun setOverlayEnabled(context: Context, enabled: Boolean) = prefs(context).edit().putBoolean(\"overlay\", enabled).apply()\n",
"    fun isOverlayEnabled(context: Context) = prefs(context).getBoolean(\"overlay\", false)\n    fun setOverlayEnabled(context: Context, enabled: Boolean) = prefs(context).edit().putBoolean(\"overlay\", enabled).apply()\n    fun isKeepScreenOn(context: Context) = prefs(context).getBoolean(\"keepScreenOn\", false)\n    fun setKeepScreenOn(context: Context, enabled: Boolean) = prefs(context).edit().putBoolean(\"keepScreenOn\", enabled).apply()\n",
"keep screen preference"
),
(
"        obj.put(\"english\", isEnglish(context))\n",
"        obj.put(\"english\", isEnglish(context))\n        obj.put(\"keepScreenOn\", isKeepScreenOn(context))\n",
"backup keep screen"
),
(
"            .putBoolean(\"english\", obj.optBoolean(\"english\", false))\n",
"            .putBoolean(\"english\", obj.optBoolean(\"english\", false))\n            .putBoolean(\"keepScreenOn\", obj.optBoolean(\"keepScreenOn\", false))\n",
"restore keep screen"
)
])
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

/**
 * Explicitly authorized, read-only, on-device screen capture and text recognition.
 * No touch events are generated and no recognized state triggers gameplay actions.
 * Android can still interrupt MediaProjection at any time.
 */
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
        override fun onStop() {
            stopCapture()
        }
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
            ScreenAnalysisState.setRecognition(
                this,
                "",
                "Lokale Texterkennung aktiv",
                "",
                System.currentTimeMillis()
            )
        } catch (error: Exception) {
            ScreenAnalysisState.setRecognition(
                this,
                "",
                "Bildschirmaufnahme konnte nicht starten",
                error.localizedMessage ?: "Unbekannter MediaProjection-Fehler",
                System.currentTimeMillis()
            )
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
                val scaledHeight = (bitmap.height * (PREVIEW_MAX_WIDTH.toFloat() / bitmap.width))
                    .roundToInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(bitmap, PREVIEW_MAX_WIDTH, scaledHeight, true)
                    .also { if (it !== bitmap) bitmap.recycle() }
            } else {
                bitmap
            }

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
            ScreenAnalysisState.setRecognition(
                this,
                "",
                "Bildanalyse unterbrochen",
                error.localizedMessage ?: "Fehler beim Verarbeiten eines Frames",
                now
            )
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
                    val text = result.text.take(MAX_RECOGNIZED_TEXT)
                    val status = ScreenTextClassifier.classify(text)
                    ScreenAnalysisState.setRecognition(this, text, status, "", timestamp)
                    if (status.startsWith("Möglicher Verbindungsfehler")) {
                        notifyConnectionHint()
                    }
                }
                .addOnFailureListener { error ->
                    ScreenAnalysisState.setRecognition(
                        this,
                        "",
                        "Texterkennung fehlgeschlagen",
                        error.localizedMessage ?: "ML Kit konnte den Frame nicht lesen",
                        timestamp
                    )
                }
                .addOnCompleteListener {
                    recognitionBusy = false
                    if (!bitmap.isRecycled) bitmap.recycle()
                }
        } catch (error: Exception) {
            recognitionBusy = false
            if (!bitmap.isRecycled) bitmap.recycle()
            ScreenAnalysisState.setRecognition(
                this,
                "",
                "Texterkennung fehlgeschlagen",
                error.localizedMessage ?: "Unbekannter Texterkennungsfehler",
                timestamp
            )
        }
    }

    private fun notifyConnectionHint() {
        val now = System.currentTimeMillis()
        if (now - lastErrorNotificationAt < ALERT_COOLDOWN_MILLIS) return
        lastErrorNotificationAt = now

        val openIntent = Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = PendingIntent.getActivity(
            this,
            ALERT_REQUEST_CODE,
            openIntent,
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
        for (y in 0 until bitmap.height step stepY) {
            for (x in 0 until bitmap.width step stepX) {
                val pixel = bitmap.getPixel(x, y)
                val red = (pixel shr 16) and 0xFF
                val green = (pixel shr 8) and 0xFF
                val blue = pixel and 0xFF
                total += (0.2126 * red + 0.7152 * green + 0.0722 * blue).toLong()
                count++
            }
        }
        val brightness = if (count == 0L) 0f else total.toFloat() / count.toFloat()
        val level = when {
            brightness < 70f -> "Dunkel"
            brightness < 165f -> "Mittel"
            else -> "Hell"
        }
        return brightness to level
    }

    private fun Image.toBitmap(): Bitmap? {
        val plane = planes.firstOrNull() ?: return null
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val paddedWidth = width + (rowPadding / pixelStride)
        val padded = Bitmap.createBitmap(paddedWidth, height, Bitmap.Config.ARGB_8888)
        val buffer = plane.buffer
        buffer.rewind()
        padded.copyPixelsFromBuffer(buffer)
        val cropped = Bitmap.createBitmap(padded, 0, 0, width, height)
        if (cropped !== padded) padded.recycle()
        return cropped
    }

    private fun startAsForeground() {
        val notification = buildCaptureNotification()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Bildschirmanalyse",
                        NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "Zeigt eine ausdrücklich freigegebene Bildschirmaufnahme an."
                    }
                )
            }
            if (manager.getNotificationChannel(ALERT_CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        ALERT_CHANNEL_ID,
                        "Erkannte Bildschirmhinweise",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "Meldet lokal erkannte mögliche Verbindungs- oder Fehlermeldungen."
                    }
                )
            }
        }
    }

    private fun buildCaptureNotification(): Notification {
        val stopIntent = Intent(this, ScreenAnalysisService::class.java).setAction(ACTION_STOP)
        val stopPending = PendingIntent.getService(
            this,
            STOP_REQUEST_CODE,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val openIntent = Intent(this, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val openPending = PendingIntent.getActivity(
            this,
            OPEN_REQUEST_CODE,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("Bildschirmanalyse aktiv")
            .setContentText("Lokale Texterkennung aktiv · Beenden jederzeit möglich")
            .setContentIntent(openPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Beenden",
                stopPending
            )
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
        ScreenAnalysisState.setRecognition(
            this,
            "",
            "Bildschirmaufnahme beendet",
            "",
            System.currentTimeMillis()
        )
        runCatching { File(cacheDir, FRAME_FILE_NAME).delete() }
        runCatching { if (::textRecognizer.isInitialized) textRecognizer.close() }

        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
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

        fun stop(context: Context) {
            context.startService(
                Intent(context, ScreenAnalysisService::class.java).setAction(ACTION_STOP)
            )
        }
    }
}

internal object ScreenAnalysisState {
    private const val PREFS = "screen_analysis_state"

    fun isActive(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("active", false)

    fun brightness(context: Context): Float =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getFloat("brightness", 0f)

    fun level(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("level", "–") ?: "–"

    fun lastFrameAt(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("last_frame_at", 0L)

    fun detectedStatus(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("detected_status", "Noch keine Analyse") ?: "Noch keine Analyse"

    fun recognizedText(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("recognized_text", "") ?: ""

    fun lastError(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("last_error", "") ?: ""

    fun setActive(context: Context, active: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("active", active)
            .apply()
    }

    fun setRecognition(context: Context, text: String, status: String, error: String, timestamp: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("recognized_text", text.take(1_200))
            .putString("detected_status", status.take(160))
            .putString("last_error", error.take(300))
            .putLong("last_analysis_at", timestamp)
            .apply()
    }

    fun setMetrics(context: Context, brightness: Float, level: String, timestamp: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putFloat("brightness", brightness)
            .putString("level", level)
            .putLong("last_frame_at", timestamp)
            .apply()
    }
}
KOTLIN

# MainActivity uses Context for the screen-analysis preview composable.
MAIN="$ROOT/java/de/antiafk/assistant/MainActivity.kt"
if ! grep -q '^import android.content.Contextpackage de.antiafk.assistant

import java.util.Locale

/**
 * Classifies OCR snippets as informational hints only.
 * It never initiates a game action or changes any app state outside this assistant.
 */
internal object ScreenTextClassifier {
    fun classify(rawText: String): String {
        val text = rawText.lowercase(Locale.ROOT)
            .replace('\n', ' ')
            .replace(Regex("\\s+"), " ")
            .trim()

        if (text.isBlank()) return "Kein lesbarer Text erkannt"

        val connectionHints = listOf(
            "disconnected", "connection error", "lost connection", "connection lost",
            "error code", "removed from the experience", "server connection",
            "verbindung getrennt", "verbindung verloren", "verbindungsfehler",
            "sitzung beendet", "aus dem spiel entfernt"
        )
        if (connectionHints.any(text::contains)) {
            return "Möglicher Verbindungsfehler – bitte selbst prüfen"
        }

        val loadingHints = listOf(
            "loading", "joining server", "connecting", "teleporting",
            "wird geladen", "verbindung wird hergestellt", "server wird gesucht",
            "wird verbunden"
        )
        if (loadingHints.any(text::contains)) return "Möglicher Lade- oder Verbindungsbildschirm"

        val interfaceHints = listOf(
            "chat", "players", "settings", "avatar", "inventory",
            "friends", "discover", "home", "spieler", "einstellungen"
        )
        if (interfaceHints.count(text::contains) >= 2) {
            return "Mögliche Spieloberfläche – Menütitel erkannt"
        }

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
import android.content.SharedPreferences
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

/**
 * Floating session-control menu. It starts/stops the user's own timer and displays
 * passive screen-analysis status. It does not inject input into other applications.
 */
class FloatingAssistantService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var preferences: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())

    private var bubble: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panel: LinearLayout? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private var statusView: TextView? = null
    private var timerView: TextView? = null
    private var screenView: TextView? = null
    private var reminderView: TextView? = null

    private var reminderDeadlineElapsed: Long? = null
    private var reminderFinished = false

    private val updateTask = object : Runnable {
        override fun run() {
            refreshPanel()
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createChannels(this)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                4103,
                NotificationHelper.overlayForegroundNotification(this),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(4103, NotificationHelper.overlayForegroundNotification(this))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        preferences = getSharedPreferences("floating_assistant", Context.MODE_PRIVATE)
        showBubble()
        handler.post(updateTask)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    private fun showBubble() {
        if (bubble != null) return
        val view = TextView(this).apply {
            text = "AFK"
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(15), dp(12), dp(15), dp(12))
            background = rounded(0xFF2B304F.toInt(), 26)
            elevation = dp(8).toFloat()
            contentDescription = "Anti-AFK Assistant öffnen"
        }
        val layout = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = preferences.getInt("bubble_x", dp(16))
            y = preferences.getInt("bubble_y", dp(180))
        }
        bubble = view
        bubbleParams = layout
        bindDrag(view, layout, "bubble") { showPanel() }
        runCatching { windowManager.addView(view, layout) }
            .onFailure { bubble = null; bubbleParams = null; stopSelf() }
    }

    private fun showPanel() {
        if (panel != null) return
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(14))
            background = rounded(0xF01A2032.toInt(), 20)
            elevation = dp(12).toFloat()
        }

        val heading = label("ANTI-AFK ASSISTANT", 13, Color.WHITE, true)
        heading.setPadding(dp(4), dp(3), dp(4), dp(10))
        root.addView(heading, matchWrap())
        val status = label("", 13, 0xFF70D5A0.toInt(), true)
        status.gravity = Gravity.CENTER
        root.addView(status, matchWrap())
        val timer = label("00:00:00", 28, Color.WHITE, true)
        timer.gravity = Gravity.CENTER
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
            NotificationHelper.showSessionStatus(this)
            refreshPanel()
        }

        val pauseRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        root.addView(pauseRow, top(matchWrap(), 6))
        addButton(pauseRow, "Pause / Weiter", 0xFF46506B.toInt(), 1f) {
            when (SessionManager.snapshot(this).status) {
                SessionManager.RUNNING -> SessionManager.pause(this)
                SessionManager.PAUSED -> SessionManager.resume(this)
            }
            NotificationHelper.showSessionStatus(this)
            refreshPanel()
        }

        val screen = label("", 12, 0xFFC3CEE8.toInt(), false)
        screen.gravity = Gravity.CENTER
        screen.setPadding(0, dp(8), 0, dp(6))
        root.addView(screen, matchWrap())

        addButton(root, "Bildschirm-Analyse öffnen", 0xFF38435E.toInt(), 1f) {
            val open = Intent(this, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(open)
        }

        val reminder = label("", 12, 0xFFFFD18A.toInt(), false)
        reminder.gravity = Gravity.CENTER
        reminder.setPadding(0, dp(7), 0, dp(2))
        root.addView(reminder, matchWrap())
        addButton(root, "60-Sekunden-Erinnerung", 0xFF3B4560.toInt(), 1f) {
            toggleManualReminder()
        }

        addButton(root, "NOT-AUS · TIMER UND ANALYSE STOPPEN", 0xFF9A3545.toInt(), 1f) {
            SessionManager.stop(this)
            NotificationHelper.showSessionStatus(this)
            stopService(Intent(this, ScreenAnalysisService::class.java))
            ScreenAnalysisService.stop(this)
            refreshPanel()
        }

        addButton(root, "Menü einklappen", 0xFF303A52.toInt(), 1f) {
            minimizePanel()
        }

        statusView = status
        timerView = timer
        screenView = screen
        reminderView = reminder
        panel = root

        val layout = WindowManager.LayoutParams(
            dp(278),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = preferences.getInt("panel_x", dp(14))
            y = preferences.getInt("panel_y", dp(90))
        }
        panelParams = layout
        bindDrag(heading, layout, "panel") {}
        runCatching { windowManager.addView(root, layout) }
            .onFailure { panel = null; panelParams = null }
        refreshPanel()
    }

    private fun minimizePanel() {
        panel?.let { view -> runCatching { windowManager.removeView(view) } }
        panel = null
        panelParams = null
        statusView = null
        timerView = null
        screenView = null
        reminderView = null
        showBubble()
    }

    private fun bindDrag(
        view: View,
        layout: WindowManager.LayoutParams,
        key: String,
        onTap: () -> Unit
    ) {
        var downX = 0f
        var downY = 0f
        var initialX = 0
        var initialY = 0
        var moved = false
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    initialX = layout.x
                    initialY = layout.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (kotlin.math.abs(dx) > dp(4) || kotlin.math.abs(dy) > dp(4)) moved = true
                    layout.x = (initialX + dx).coerceAtLeast(0)
                    layout.y = (initialY + dy).coerceAtLeast(0)
                    val target = if (key == "bubble") bubble else panel
                    if (target != null) runCatching { windowManager.updateViewLayout(target, layout) }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) onTap()
                    else {
                        preferences.edit()
                            .putInt(key + "_x", layout.x)
                            .putInt(key + "_y", layout.y)
                            .apply()
                    }
                    true
                }
                else -> true
            }
        }
    }

    private fun refreshPanel() {
        val state = SessionManager.snapshot(this)
        statusView?.text = when (state.status) {
            SessionManager.RUNNING -> "AFK AKTIV"
            SessionManager.PAUSED -> "AFK PAUSIERT"
            else -> "AFK AUS"
        }
        statusView?.setTextColor(
            if (state.status == SessionManager.RUNNING) 0xFF70D5A0.toInt() else 0xFFFFC56B.toInt()
        )
        timerView?.text = formatClock(state.elapsedMillis)

        val screenStatus = ScreenAnalysisState.detectedStatus(this)
        screenView?.text = if (ScreenAnalysisState.isActive(this)) {
            "LIVE-TEXTERKENNUNG: AKTIV\n" + screenStatus
        } else {
            "LIVE-TEXTERKENNUNG: AUS\n" + screenStatus
        }

        val deadline = reminderDeadlineElapsed
        if (deadline != null) {
            val remaining = ManualReminderCountdown.remainingSeconds(deadline, SystemClock.elapsedRealtime())
            if (remaining <= 0) {
                reminderDeadlineElapsed = null
                reminderFinished = true
                NotificationHelper.sendManualOverlayReminder(this)
            } else {
                reminderView?.text = "Erinnerung: " + ManualReminderCountdown.format(remaining)
                bubble?.text = "AFK"
                return
            }
        }
        reminderView?.text = if (reminderFinished) "Erinnerung abgeschlossen" else "Erinnerung nicht aktiv"
        bubble?.text = if (state.status == SessionManager.RUNNING) "AFK " + formatClock(state.elapsedMillis) else "AFK"
    }

    private fun toggleManualReminder() {
        val current = reminderDeadlineElapsed
        if (current != null) {
            reminderDeadlineElapsed = null
            reminderFinished = false
        } else {
            reminderDeadlineElapsed = SystemClock.elapsedRealtime() + ManualReminderCountdown.DURATION_MS
            reminderFinished = false
        }
        refreshPanel()
    }

    private fun formatClock(durationMillis: Long): String {
        val seconds = durationMillis.coerceAtLeast(0L) / 1_000L
        return String.format(
            Locale.getDefault(),
            "%02d:%02d:%02d",
            seconds / 3_600L,
            (seconds % 3_600L) / 60L,
            seconds % 60L
        )
    }

    private fun addButton(
        parent: LinearLayout,
        text: String,
        color: Int,
        weight: Float,
        action: () -> Unit
    ) {
        val button = Button(this).apply {
            this.text = text
            isAllCaps = false
            textSize = 12f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = rounded(color, 12)
            setPadding(dp(4), dp(2), dp(4), dp(2))
            minHeight = dp(43)
            setOnClickListener { action() }
        }
        val params = if (weight == 1f && parent.orientation == LinearLayout.VERTICAL) {
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(44))
        } else {
            LinearLayout.LayoutParams(0, dp(44), weight)
        }
        if (parent.childCount > 0) params.topMargin = dp(5)
        if (parent.orientation == LinearLayout.HORIZONTAL && parent.childCount > 0) params.marginStart = dp(7)
        parent.addView(button, params)
    }

    private fun label(text: String, size: Int, color: Int, bold: Boolean): TextView =
        TextView(this).apply {
            this.text = text
            textSize = size.toFloat()
            setTextColor(color)
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

    private fun rounded(color: Int, radiusDp: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
    }

    private fun matchWrap() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )

    private fun top(params: LinearLayout.LayoutParams, marginDp: Int): LinearLayout.LayoutParams {
        params.topMargin = dp(marginDp)
        return params
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        handler.removeCallbacks(updateTask)
        bubble?.let { runCatching { windowManager.removeView(it) } }
        panel?.let { runCatching { windowManager.removeView(it) } }
        bubble = null
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

cat > "$PKG/ScreenTextClassifier.kt" <<'KOTLIN'
package de.antiafk.assistant

import java.util.Locale

internal object ScreenTextClassifier {
    fun classify(rawText: String): String {
        val text = rawText.lowercase(Locale.ROOT)
            .replace('\n', ' ')
            .replace(Regex("\\s+"), " ")
            .trim()
        if (text.isBlank()) return "Kein lesbarer Text erkannt"

        val disconnect = listOf(
            "disconnected", "connection error", "lost connection", "connection lost",
            "error code", "removed from the experience", "verbindung getrennt",
            "verbindung verloren", "verbindungsfehler", "sitzung beendet",
            "aus dem spiel entfernt"
        )
        if (disconnect.any(text::contains)) return "Möglicher Verbindungsfehler – bitte selbst prüfen"

        val loading = listOf(
            "loading", "joining server", "connecting", "teleporting",
            "wird geladen", "verbindung wird hergestellt", "server wird gesucht",
            "wird verbunden"
        )
        if (loading.any(text::contains)) return "Möglicher Lade- oder Verbindungsbildschirm"

        val uiWords = listOf(
            "chat", "players", "settings", "avatar", "inventory",
            "friends", "discover", "home", "spieler", "einstellungen"
        )
        if (uiWords.count(text::contains) >= 2) return "Mögliche Spieloberfläche – Menütitel erkannt"
        if (text.contains("roblox")) return "Roblox-Text erkannt"
        return "Text erkannt – kein bekannter Status"
    }
}
KOTLIN

# Keep the source project's existing app/resources/tests. Add only the local OCR classifier tests.
mkdir -p source/app/src/test/java/de/antiafk/assistant
cat > source/app/src/test/java/de/antiafk/assistant/ScreenTextClassifierTest.kt <<'KOTLIN'
package de.antiafk.assistant

import org.junit.Assert.assertTrue
import org.junit.Test

class ScreenTextClassifierTest {
    @Test
    fun detectsConnectionHintAsInformationalText() {
        assertTrue(ScreenTextClassifier.classify("Connection lost. Error code 277").contains("Verbindungsfehler"))
    }

    @Test
    fun detectsPossibleLoadingScreen() {
        assertTrue(ScreenTextClassifier.classify("Joining server...").contains("Lade"))
    }

    @Test
    fun doesNotInventStateWhenNoTextExists() {
        assertTrue(ScreenTextClassifier.classify("").contains("Kein lesbarer Text"))
    }
}
KOTLIN
 "$MAIN"; then
    sed -i '/^import android.content.Intent$/i import android.content.Context' "$MAIN"
fi

cat > "$PKG/ScreenTextClassifier.kt" <<'KOTLIN'
package de.antiafk.assistant

import java.util.Locale

/**
 * Classifies OCR snippets as informational hints only.
 * It never initiates a game action or changes any app state outside this assistant.
 */
internal object ScreenTextClassifier {
    fun classify(rawText: String): String {
        val text = rawText.lowercase(Locale.ROOT)
            .replace('\n', ' ')
            .replace(Regex("\\s+"), " ")
            .trim()

        if (text.isBlank()) return "Kein lesbarer Text erkannt"

        val connectionHints = listOf(
            "disconnected", "connection error", "lost connection", "connection lost",
            "error code", "removed from the experience", "server connection",
            "verbindung getrennt", "verbindung verloren", "verbindungsfehler",
            "sitzung beendet", "aus dem spiel entfernt"
        )
        if (connectionHints.any(text::contains)) {
            return "Möglicher Verbindungsfehler – bitte selbst prüfen"
        }

        val loadingHints = listOf(
            "loading", "joining server", "connecting", "teleporting",
            "wird geladen", "verbindung wird hergestellt", "server wird gesucht",
            "wird verbunden"
        )
        if (loadingHints.any(text::contains)) return "Möglicher Lade- oder Verbindungsbildschirm"

        val interfaceHints = listOf(
            "chat", "players", "settings", "avatar", "inventory",
            "friends", "discover", "home", "spieler", "einstellungen"
        )
        if (interfaceHints.count(text::contains) >= 2) {
            return "Mögliche Spieloberfläche – Menütitel erkannt"
        }

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
import android.content.SharedPreferences
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

/**
 * Floating session-control menu. It starts/stops the user's own timer and displays
 * passive screen-analysis status. It does not inject input into other applications.
 */
class FloatingAssistantService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var preferences: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())

    private var bubble: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panel: LinearLayout? = null
    private var panelParams: WindowManager.LayoutParams? = null
    private var statusView: TextView? = null
    private var timerView: TextView? = null
    private var screenView: TextView? = null
    private var reminderView: TextView? = null

    private var reminderDeadlineElapsed: Long? = null
    private var reminderFinished = false

    private val updateTask = object : Runnable {
        override fun run() {
            refreshPanel()
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createChannels(this)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                4103,
                NotificationHelper.overlayForegroundNotification(this),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(4103, NotificationHelper.overlayForegroundNotification(this))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        preferences = getSharedPreferences("floating_assistant", Context.MODE_PRIVATE)
        showBubble()
        handler.post(updateTask)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    private fun showBubble() {
        if (bubble != null) return
        val view = TextView(this).apply {
            text = "AFK"
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(15), dp(12), dp(15), dp(12))
            background = rounded(0xFF2B304F.toInt(), 26)
            elevation = dp(8).toFloat()
            contentDescription = "Anti-AFK Assistant öffnen"
        }
        val layout = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = preferences.getInt("bubble_x", dp(16))
            y = preferences.getInt("bubble_y", dp(180))
        }
        bubble = view
        bubbleParams = layout
        bindDrag(view, layout, "bubble") { showPanel() }
        runCatching { windowManager.addView(view, layout) }
            .onFailure { bubble = null; bubbleParams = null; stopSelf() }
    }

    private fun showPanel() {
        if (panel != null) return
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(14))
            background = rounded(0xF01A2032.toInt(), 20)
            elevation = dp(12).toFloat()
        }

        val heading = label("ANTI-AFK ASSISTANT", 13, Color.WHITE, true)
        heading.setPadding(dp(4), dp(3), dp(4), dp(10))
        root.addView(heading, matchWrap())
        val status = label("", 13, 0xFF70D5A0.toInt(), true)
        status.gravity = Gravity.CENTER
        root.addView(status, matchWrap())
        val timer = label("00:00:00", 28, Color.WHITE, true)
        timer.gravity = Gravity.CENTER
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
            NotificationHelper.showSessionStatus(this)
            refreshPanel()
        }

        val pauseRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        root.addView(pauseRow, top(matchWrap(), 6))
        addButton(pauseRow, "Pause / Weiter", 0xFF46506B.toInt(), 1f) {
            when (SessionManager.snapshot(this).status) {
                SessionManager.RUNNING -> SessionManager.pause(this)
                SessionManager.PAUSED -> SessionManager.resume(this)
            }
            NotificationHelper.showSessionStatus(this)
            refreshPanel()
        }

        val screen = label("", 12, 0xFFC3CEE8.toInt(), false)
        screen.gravity = Gravity.CENTER
        screen.setPadding(0, dp(8), 0, dp(6))
        root.addView(screen, matchWrap())

        addButton(root, "Bildschirm-Analyse öffnen", 0xFF38435E.toInt(), 1f) {
            val open = Intent(this, MainActivity::class.java)
                .putExtra(MainActivity.EXTRA_OPEN_SCREEN_ANALYSIS, true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(open)
        }

        val reminder = label("", 12, 0xFFFFD18A.toInt(), false)
        reminder.gravity = Gravity.CENTER
        reminder.setPadding(0, dp(7), 0, dp(2))
        root.addView(reminder, matchWrap())
        addButton(root, "60-Sekunden-Erinnerung", 0xFF3B4560.toInt(), 1f) {
            toggleManualReminder()
        }

        addButton(root, "NOT-AUS · TIMER UND ANALYSE STOPPEN", 0xFF9A3545.toInt(), 1f) {
            SessionManager.stop(this)
            NotificationHelper.showSessionStatus(this)
            stopService(Intent(this, ScreenAnalysisService::class.java))
            ScreenAnalysisService.stop(this)
            refreshPanel()
        }

        addButton(root, "Menü einklappen", 0xFF303A52.toInt(), 1f) {
            minimizePanel()
        }

        statusView = status
        timerView = timer
        screenView = screen
        reminderView = reminder
        panel = root

        val layout = WindowManager.LayoutParams(
            dp(278),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = preferences.getInt("panel_x", dp(14))
            y = preferences.getInt("panel_y", dp(90))
        }
        panelParams = layout
        bindDrag(heading, layout, "panel") {}
        runCatching { windowManager.addView(root, layout) }
            .onFailure { panel = null; panelParams = null }
        refreshPanel()
    }

    private fun minimizePanel() {
        panel?.let { view -> runCatching { windowManager.removeView(view) } }
        panel = null
        panelParams = null
        statusView = null
        timerView = null
        screenView = null
        reminderView = null
        showBubble()
    }

    private fun bindDrag(
        view: View,
        layout: WindowManager.LayoutParams,
        key: String,
        onTap: () -> Unit
    ) {
        var downX = 0f
        var downY = 0f
        var initialX = 0
        var initialY = 0
        var moved = false
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    initialX = layout.x
                    initialY = layout.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (kotlin.math.abs(dx) > dp(4) || kotlin.math.abs(dy) > dp(4)) moved = true
                    layout.x = (initialX + dx).coerceAtLeast(0)
                    layout.y = (initialY + dy).coerceAtLeast(0)
                    val target = if (key == "bubble") bubble else panel
                    if (target != null) runCatching { windowManager.updateViewLayout(target, layout) }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) onTap()
                    else {
                        preferences.edit()
                            .putInt(key + "_x", layout.x)
                            .putInt(key + "_y", layout.y)
                            .apply()
                    }
                    true
                }
                else -> true
            }
        }
    }

    private fun refreshPanel() {
        val state = SessionManager.snapshot(this)
        statusView?.text = when (state.status) {
            SessionManager.RUNNING -> "AFK AKTIV"
            SessionManager.PAUSED -> "AFK PAUSIERT"
            else -> "AFK AUS"
        }
        statusView?.setTextColor(
            if (state.status == SessionManager.RUNNING) 0xFF70D5A0.toInt() else 0xFFFFC56B.toInt()
        )
        timerView?.text = formatClock(state.elapsedMillis)

        val screenStatus = ScreenAnalysisState.detectedStatus(this)
        screenView?.text = if (ScreenAnalysisState.isActive(this)) {
            "LIVE-TEXTERKENNUNG: AKTIV\n" + screenStatus
        } else {
            "LIVE-TEXTERKENNUNG: AUS\n" + screenStatus
        }

        val deadline = reminderDeadlineElapsed
        if (deadline != null) {
            val remaining = ManualReminderCountdown.remainingSeconds(deadline, SystemClock.elapsedRealtime())
            if (remaining <= 0) {
                reminderDeadlineElapsed = null
                reminderFinished = true
                NotificationHelper.sendManualOverlayReminder(this)
            } else {
                reminderView?.text = "Erinnerung: " + ManualReminderCountdown.format(remaining)
                bubble?.text = "AFK"
                return
            }
        }
        reminderView?.text = if (reminderFinished) "Erinnerung abgeschlossen" else "Erinnerung nicht aktiv"
        bubble?.text = if (state.status == SessionManager.RUNNING) "AFK " + formatClock(state.elapsedMillis) else "AFK"
    }

    private fun toggleManualReminder() {
        val current = reminderDeadlineElapsed
        if (current != null) {
            reminderDeadlineElapsed = null
            reminderFinished = false
        } else {
            reminderDeadlineElapsed = SystemClock.elapsedRealtime() + ManualReminderCountdown.DURATION_MS
            reminderFinished = false
        }
        refreshPanel()
    }

    private fun formatClock(durationMillis: Long): String {
        val seconds = durationMillis.coerceAtLeast(0L) / 1_000L
        return String.format(
            Locale.getDefault(),
            "%02d:%02d:%02d",
            seconds / 3_600L,
            (seconds % 3_600L) / 60L,
            seconds % 60L
        )
    }

    private fun addButton(
        parent: LinearLayout,
        text: String,
        color: Int,
        weight: Float,
        action: () -> Unit
    ) {
        val button = Button(this).apply {
            this.text = text
            isAllCaps = false
            textSize = 12f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = rounded(color, 12)
            setPadding(dp(4), dp(2), dp(4), dp(2))
            minHeight = dp(43)
            setOnClickListener { action() }
        }
        val params = if (weight == 1f && parent.orientation == LinearLayout.VERTICAL) {
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(44))
        } else {
            LinearLayout.LayoutParams(0, dp(44), weight)
        }
        if (parent.childCount > 0) params.topMargin = dp(5)
        if (parent.orientation == LinearLayout.HORIZONTAL && parent.childCount > 0) params.marginStart = dp(7)
        parent.addView(button, params)
    }

    private fun label(text: String, size: Int, color: Int, bold: Boolean): TextView =
        TextView(this).apply {
            this.text = text
            textSize = size.toFloat()
            setTextColor(color)
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

    private fun rounded(color: Int, radiusDp: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
    }

    private fun matchWrap() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )

    private fun top(params: LinearLayout.LayoutParams, marginDp: Int): LinearLayout.LayoutParams {
        params.topMargin = dp(marginDp)
        return params
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        handler.removeCallbacks(updateTask)
        bubble?.let { runCatching { windowManager.removeView(it) } }
        panel?.let { runCatching { windowManager.removeView(it) } }
        bubble = null
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

cat > "$PKG/ScreenTextClassifier.kt" <<'KOTLIN'
package de.antiafk.assistant

import java.util.Locale

internal object ScreenTextClassifier {
    fun classify(rawText: String): String {
        val text = rawText.lowercase(Locale.ROOT)
            .replace('\n', ' ')
            .replace(Regex("\\s+"), " ")
            .trim()
        if (text.isBlank()) return "Kein lesbarer Text erkannt"

        val disconnect = listOf(
            "disconnected", "connection error", "lost connection", "connection lost",
            "error code", "removed from the experience", "verbindung getrennt",
            "verbindung verloren", "verbindungsfehler", "sitzung beendet",
            "aus dem spiel entfernt"
        )
        if (disconnect.any(text::contains)) return "Möglicher Verbindungsfehler – bitte selbst prüfen"

        val loading = listOf(
            "loading", "joining server", "connecting", "teleporting",
            "wird geladen", "verbindung wird hergestellt", "server wird gesucht",
            "wird verbunden"
        )
        if (loading.any(text::contains)) return "Möglicher Lade- oder Verbindungsbildschirm"

        val uiWords = listOf(
            "chat", "players", "settings", "avatar", "inventory",
            "friends", "discover", "home", "spieler", "einstellungen"
        )
        if (uiWords.count(text::contains) >= 2) return "Mögliche Spieloberfläche – Menütitel erkannt"
        if (text.contains("roblox")) return "Roblox-Text erkannt"
        return "Text erkannt – kein bekannter Status"
    }
}
KOTLIN

# Keep the source project's existing app/resources/tests. Add only the local OCR classifier tests.
mkdir -p source/app/src/test/java/de/antiafk/assistant
cat > source/app/src/test/java/de/antiafk/assistant/ScreenTextClassifierTest.kt <<'KOTLIN'
package de.antiafk.assistant

import org.junit.Assert.assertTrue
import org.junit.Test

class ScreenTextClassifierTest {
    @Test
    fun detectsConnectionHintAsInformationalText() {
        assertTrue(ScreenTextClassifier.classify("Connection lost. Error code 277").contains("Verbindungsfehler"))
    }

    @Test
    fun detectsPossibleLoadingScreen() {
        assertTrue(ScreenTextClassifier.classify("Joining server...").contains("Lade"))
    }

    @Test
    fun doesNotInventStateWhenNoTextExists() {
        assertTrue(ScreenTextClassifier.classify("").contains("Kein lesbarer Text"))
    }
}
KOTLIN
