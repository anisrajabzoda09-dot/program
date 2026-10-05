// Файл: хидмати огоҳинома бе Firebase — events API-ро бо long-poll мехонад
// ва паём, SOS, занг ва огоҳии оилавиро бо забони барнома нишон медиҳад.

package tj.nigoh.nigoh_family_parent

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Foreground service-и огоҳиномаҳост: GET /api/mobile/v3/events-ро long-poll карда,
 * event-ҳоро ба паём, SOS, занг ва огоҳии оилавии Android табдил медиҳад.
 */
class NotifyService : Service() {

    /** Калидҳо, action-ҳо, channel-ҳо ва амалиёти идораи хидматро ҷамъ мекунад. */
    companion object {
        private const val TAG = "NotifyService"
        const val PREFS = "nigoh_notify"
        const val KEY_BASE_URL = "nigoh_notify_base_url"
        private const val KEY_CURSOR = "cursor"
        private const val KEY_CURSOR_OWNER = "cursor_owner"
        const val DEFAULT_BASE_URL = "https://nigohfamily.qobus.tj"

        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_TOKEN = "flutter.nigoh.token"
        private const val FLUTTER_ROLE = "flutter.nigoh.role"

        const val ACTION_START = "tj.nigoh.notify.START"
        const val ACTION_STOP_ALARM = "tj.nigoh.notify.STOP_ALARM"
        const val ACTION_DECLINE_CALL = "tj.nigoh.notify.DECLINE_CALL"
        const val ACTION_CALL_TIMEOUT = "tj.nigoh.notify.CALL_TIMEOUT"
        const val EXTRA_BASE_URL = "baseUrl"

        // Extra-ҳое, ки MainActivity барои LaunchAction-и Dart мехонад.
        const val EXTRA_KIND = "nigoh_kind"
        const val EXTRA_CHILD_ID = "nigoh_child_id"
        const val EXTRA_CALL_ID = "nigoh_call_id"
        const val EXTRA_PEER_NAME = "nigoh_peer_name"
        const val EXTRA_ACCEPT = "nigoh_accept"
        const val EXTRA_FULL_SCREEN = "nigoh_full_screen"

        const val CH_SERVICE = "nigoh_service"
        const val CH_MESSAGES = "nigoh_messages"
        const val CH_SOS = "nigoh_sos"
        const val CH_CALLS = "nigoh_calls"
        const val CH_FAMILY = "nigoh_family"

        private const val ID_FOREGROUND = 7301
        private const val CALL_TIMEOUT_MS = 45_000L

        @Volatile
        var instance: NotifyService? = null
            private set

        /** Аз рӯйи token-и Flutter ворид будани корбарро месанҷад. */
        fun hasToken(context: Context): Boolean =
            !context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                .getString(FLUTTER_TOKEN, null).isNullOrBlank()

        /** Хидматро оғоз ё нав мекунад; [baseUrl]-и null қимати пешинаро нигоҳ медорад. */
        fun start(context: Context, baseUrl: String? = null) {
            if (!baseUrl.isNullOrBlank()) {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putString(KEY_BASE_URL, baseUrl.trimEnd('/')).apply()
            }
            val intent = Intent(context, NotifyService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Ҳангоми boot ё кушодани барнома танҳо барои корбари воридшуда хидматро оғоз мекунад. */
        fun startIfSignedIn(context: Context) {
            if (hasToken(context)) runCatching { start(context) }
                .onFailure { Log.w(TAG, "start failed", it) }
        }

        /** Хидмат ва садоро қатъ карда, cursor-и event-ҳоро пок мекунад. */
        fun stop(context: Context) {
            instance?.stopRinging()
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(KEY_CURSOR).remove(KEY_CURSOR_OWNER).apply()
            context.stopService(Intent(context, NotifyService::class.java))
        }

        /** Channel-ҳои огоҳиномаро месозад ё номи онҳоро ба забони ҷорӣ мегардонад. */
        fun createChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(NotificationManager::class.java)
            // ID-ҳо доимӣ буда, сохтани такрорӣ танҳо ном ва тавсифро нав мекунад.
            val s = NotifyStrings(AppLang.of(context))
            val service = NotificationChannel(
                CH_SERVICE, s.chService, NotificationManager.IMPORTANCE_MIN
            ).apply { setShowBadge(false) }
            val messages = NotificationChannel(
                CH_MESSAGES, s.chMessages, NotificationManager.IMPORTANCE_DEFAULT
            )
            val family = NotificationChannel(
                CH_FAMILY, s.chFamily, NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = s.chFamilyDesc }
            // Садои SOS ва зангро худи service такрор мекунад; channel хомӯш мемонад.
            val sos = NotificationChannel(
                CH_SOS, "SOS", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = s.chSosDesc
                setSound(null, null)
                enableVibration(false)
                enableLights(true)
                lightColor = Color.RED
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                if (nm.isNotificationPolicyAccessGranted) setBypassDnd(true)
            }
            val calls = NotificationChannel(
                CH_CALLS, s.chCalls, NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = s.chCallsDesc
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannels(listOf(service, messages, family, sos, calls))
        }
    }

    private val main = Handler(Looper.getMainLooper())
    @Volatile private var running = false
    private var worker: Thread? = null

    // Ҳолати садодиҳӣ, танҳо барои main thread.
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var savedAlarmVolume: Int? = null
    @Volatile private var ringingCallId: Int? = null
    private var ringingSosChild: Int? = null
    private var callWatcher: Thread? = null

    // Забони барнома; channel ва корти ongoing бо он нав мешаванд.
    @Volatile private var lang: String = "tg"
    private val strings get() = NotifyStrings(lang)
    private val langListener =
        android.content.SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == null || key == AppLang.KEY) main.post { refreshLanguage() }
        }

    // Занг ё SOS-и охирини мустақим кушодашуда барои пешгирии такрор.
    private var lastDirectLaunch: String? = null

    /** Нишон медиҳад, ки хидмат binding-ро дастгирӣ намекунад. */
    override fun onBind(intent: Intent?): IBinder? = null

    /** Instance-ро сабт карда, channel-ҳо ва listener-и забонро омода мекунад. */
    override fun onCreate() {
        super.onCreate()
        instance = this
        lang = AppLang.of(this)
        createChannels(this)
        flutterPrefs().registerOnSharedPreferenceChangeListener(langListener)
    }

    /** Баъди иваз шудани забон channel ва корти ongoing-ро нав мекунад. */
    private fun refreshLanguage() {
        val now = AppLang.of(this)
        if (now == lang) return
        lang = now
        createChannels(this)
        if (instance === this) runCatching { goForeground() }
    }

    /**
     * Action-ҳои оғоз, хомӯш кардани alarm ва зангро коркард карда, polling thread-ро оғоз мекунад.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        AppLang.of(this).let { if (it != lang) { lang = it; createChannels(this) } }
        goForeground()
        intent?.getStringExtra(EXTRA_BASE_URL)?.takeIf { it.isNotBlank() }?.let {
            prefs().edit().putString(KEY_BASE_URL, it.trimEnd('/')).apply()
        }
        when (intent?.action) {
            ACTION_STOP_ALARM -> {
                stopRinging()
                val child = intent.getIntExtra(EXTRA_CHILD_ID, -1)
                if (child >= 0) NotificationManagerCompat.from(this).cancel(sosId(child))
            }
            ACTION_DECLINE_CALL -> {
                val callId = intent.getIntExtra(EXTRA_CALL_ID, -1)
                if (callId >= 0) declineCall(callId)
            }
            ACTION_CALL_TIMEOUT -> {
                val callId = intent.getIntExtra(EXTRA_CALL_ID, -1)
                if (callId >= 0) endCallUi(callId)
            }
        }
        if (!hasToken(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            worker = Thread(::loop, "nigoh-events").also { it.start() }
        }
        return START_STICKY
    }

    /** Ҳангоми нест шудани хидмат polling, listener ва садоро қатъ мекунад. */
    override fun onDestroy() {
        running = false
        worker?.interrupt()
        runCatching { flutterPrefs().unregisterOnSharedPreferenceChangeListener(langListener) }
        stopRinging()
        instance = null
        super.onDestroy()
    }

    /** Танзимоти хусусии service-ро барои base URL ва cursor медиҳад. */
    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    /** shared preferences-и Flutter-ро барои token, role ва забон медиҳад. */
    private fun flutterPrefs() = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

    /** Огоҳиномаи хомӯши ongoing-и фаъол будани NIGOH Family-ро нишон медиҳад. */
    private fun goForeground() {
        val open = PendingIntent.getActivity(
            this, 7300,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val notification = NotificationCompat.Builder(this, CH_SERVICE)
            .setSmallIcon(R.drawable.ic_stat_nigoh)
            .setContentTitle(strings.serviceTitle)
            .setContentText(strings.serviceText)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(open)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ID_FOREGROUND, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID_FOREGROUND, notification)
        }
    }

    // Polling-и event-ҳои сервер.

    /** HTTP status-и ғайри 2xx-ро ҳамчун хато нигоҳ медорад. */
    private class HttpStatus(val code: Int) : Exception("HTTP $code")

    /** Дархости authenticated ба сервер фиристода, ҷавоби JSON-ро мехонад. */
    private fun request(method: String, path: String, timeoutMs: Int): JSONObject {
        val token = flutterPrefs().getString(FLUTTER_TOKEN, null)
            ?: throw HttpStatus(401)
        val role = flutterPrefs().getString(FLUTTER_ROLE, null)
        val base = prefs().getString(KEY_BASE_URL, null) ?: DEFAULT_BASE_URL
        val conn = URL(base + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = method
            conn.connectTimeout = 15_000
            conn.readTimeout = timeoutMs
            conn.setRequestProperty("Authorization", "Bearer $token")
            if (!role.isNullOrBlank()) conn.setRequestProperty("X-NIGOH-Role", role)
            conn.setRequestProperty("X-NIGOH-Device", "android")
            conn.setRequestProperty("Accept", "application/json")
            if (method == "POST") {
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write("{}".toByteArray()) }
            }
            val code = conn.responseCode
            if (code !in 200..299) throw HttpStatus(code)
            val text = conn.inputStream.bufferedReader().use { it.readText() }
            return if (text.isBlank()) JSONObject() else JSONObject(text)
        } finally {
            conn.disconnect()
        }
    }

    /**
     * Event-ҳои баъди cursor-ро бо long-poll мегирад; ҳангоми хато backoff мекунад
     * ва баъди sign-out ё 401 қатъ мешавад.
     */
    private fun loop() {
        var backoff = 5_000L
        while (running) {
            val token = flutterPrefs().getString(FLUTTER_TOKEN, null)
            if (token.isNullOrBlank()) break
            val owner = "${flutterPrefs().getString(FLUTTER_ROLE, "")}:${token.hashCode()}"
            try {
                var cursor = prefs().getLong(KEY_CURSOR, -1)
                if (cursor < 0 || prefs().getString(KEY_CURSOR_OWNER, null) != owner) {
                    // Барои ҳисоби нав аз event-и ҷорӣ оғоз мекунад ва backlog намегирад.
                    val first = request("GET", "/api/mobile/v3/events?after_id=0", 40_000)
                    cursor = first.optLong("latest_id", 0)
                    prefs().edit().putLong(KEY_CURSOR, cursor).putString(KEY_CURSOR_OWNER, owner).apply()
                }
                val data = request("GET", "/api/mobile/v3/events?after_id=$cursor&wait=25", 40_000)
                val events = data.optJSONArray("events")
                var next = cursor
                if (events != null) {
                    for (i in 0 until events.length()) {
                        val event = events.optJSONObject(i) ?: continue
                        next = maxOf(next, event.optLong("id", next))
                        runCatching { handleEvent(event) }
                            .onFailure { Log.w(TAG, "event failed", it) }
                    }
                }
                next = maxOf(next, data.optLong("latest_id", next))
                if (next != cursor) prefs().edit().putLong(KEY_CURSOR, next).apply()
                backoff = 5_000L
            } catch (e: HttpStatus) {
                if (e.code == 401) {
                    Log.i(TAG, "unauthorized, stopping")
                    break
                }
                if (!sleep(backoff)) break
                backoff = (backoff * 2).coerceAtMost(60_000L)
            } catch (e: InterruptedException) {
                break
            } catch (e: Exception) {
                Log.w(TAG, "poll failed: ${e.message}")
                if (!sleep(backoff)) break
                backoff = (backoff * 2).coerceAtMost(60_000L)
            }
        }
        running = false
        main.post {
            if (instance === this && !running) {
                stopForegroundCompat()
                stopSelf()
            }
        }
    }

    /** [ms] интизор мешавад; ҳангоми interrupt ё қатъи хидмат false медиҳад. */
    private fun sleep(ms: Long): Boolean = try {
        Thread.sleep(ms); running
    } catch (_: InterruptedException) {
        false
    }

    /** Огоҳиномаи foreground-ро дар ҳамаи версияҳои Android хориҷ мекунад. */
    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    // Сохтан ва нишон додани огоҳиномаҳо.

    /** ID-и огоҳиномаи SOS-и фарзандро месозад. */
    private fun sosId(childId: Int) = 20_000 + childId
    /** ID-и огоҳиномаи занги воридшавандаро месозад. */
    private fun callNotifId(callId: Int) = 30_000 + (callId % 100_000)
    /** ID-и огоҳиномаи паёмҳои фарзандро месозад. */
    private fun messageId(childId: Int) = 10_000 + childId

    /** PendingIntent месозад, ки барномаро бо extra-ҳои Dart мекушояд. */
    private fun launchIntent(
        requestCode: Int,
        kind: String,
        childId: Int?,
        callId: Int? = null,
        peerName: String? = null,
        accept: Boolean = false,
        fullScreen: Boolean = false,
    ): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            action = "tj.nigoh.notify.OPEN.$requestCode"
            putExtra(EXTRA_KIND, kind)
            if (childId != null) putExtra(EXTRA_CHILD_ID, childId)
            if (callId != null) putExtra(EXTRA_CALL_ID, callId)
            if (peerName != null) putExtra(EXTRA_PEER_NAME, peerName)
            putExtra(EXTRA_ACCEPT, accept)
            putExtra(EXTRA_FULL_SCREEN, fullScreen)
        }
        return PendingIntent.getActivity(
            this, requestCode, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    /** PendingIntent месозад, ки action-и хомӯш ё радро ба service мефиристад. */
    private fun serviceIntent(requestCode: Int, action: String, childId: Int? = null, callId: Int? = null): PendingIntent {
        val intent = Intent(this, NotifyService::class.java).apply {
            this.action = action
            if (childId != null) putExtra(EXTRA_CHILD_ID, childId)
            if (callId != null) putExtra(EXTRA_CALL_ID, callId)
        }
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(this, requestCode, intent, flags)
        } else {
            PendingIntent.getService(this, requestCode, intent, flags)
        }
    }

    /** Огоҳиномаро мефиристад; набудани POST_NOTIFICATIONS-ро бехатар коркард мекунад. */
    private fun post(id: Int, notification: Notification) {
        try {
            NotificationManagerCompat.from(this).notify(id, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "POST_NOTIFICATIONS not granted")
        }
    }

    /** Як event-и серверро ба огоҳиномаи мувофиқ табдил медиҳад. */
    private fun handleEvent(event: JSONObject) {
        val kind = event.optString("kind")
        val eventId = event.optLong("id").toInt()
        val childId = if (event.isNull("child_id")) null else event.optInt("child_id")
        val childName = event.optString("child_name").takeIf { it.isNotBlank() && it != "null" }
        val title = event.optString("title").takeIf { it.isNotBlank() && it != "null" } ?: "NIGOH Family"
        val body = event.optString("body").takeIf { it != "null" } ?: ""
        val data = event.optJSONObject("data") ?: JSONObject()
        val current = AppLang.of(this)
        if (current != lang) main.post { refreshLanguage() }
        val s = NotifyStrings(current)
        when (kind) {
            "message" -> {
                // Сарлавҳа фиристанда ва матн худи паёми корбар аст.
                val sender = data.str("sender") ?: title
                showMessage(eventId, childId, childName, sender, body)
            }
            "sos" -> {
                val content = data.str("content") ?: body.takeIf { it.isNotBlank() }
                val sosTitle = childName?.let(s::sosTitle) ?: title
                val text = content ?: s.sosDefault(childName)
                main.post { showSos(childId ?: 0, sosTitle, text, childName, s) }
            }
            "call" -> {
                val callId = data.optInt("call_id", -1)
                if (callId < 0) return
                // Занге, ки аллакай қатъ шудааст, баъди кандашавии шабака нишон дода намешавад.
                val status = runCatching {
                    request("GET", "/api/mobile/v3/calls/$callId", 10_000)
                        .let { it.optJSONObject("call") ?: it }.optString("status", "ringing")
                }.getOrDefault("ringing")
                if (status != "ringing") return
                val peer = data.optString("caller_name").takeIf { it.isNotBlank() && it != "null" }
                    ?: childName ?: title
                main.post { showCall(callId, childId ?: 0, peer, s.voiceCall, s) }
            }
            "call_end" -> {
                val callId = data.optInt("call_id", -1)
                if (callId >= 0) main.post { endCallUi(callId) }
            }
            "missed_call" -> {
                val callId = data.optInt("call_id", -1)
                if (callId >= 0) main.post { endCallUi(callId) }
                val (t, b) = localize(s, kind, childName, data) ?: (title to body)
                showFamily(eventId, kind, childId, t, b, childName)
            }
            else -> {
                val (t, b) = localize(s, kind, childName, data) ?: (title to body)
                showFamily(eventId, kind, childId, t, b, childName)
            }
        }
    }

    /** Қимати String-и холинабудаи [key]-ро ё null медиҳад. */
    private fun JSONObject.str(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf { it.isNotBlank() && it != "null" }

    /**
     * Сарлавҳа ва матни event-и оилавиро аз маълумоти сохторӣ маҳаллӣ мекунад;
     * барои маълумоти нопурраи сервери кӯҳна null медиҳад.
     */
    private fun localize(s: NotifyStrings, kind: String, child: String?, data: JSONObject): Pair<String, String>? =
        when (kind) {
            "time_request" -> {
                val app = data.str("app_name")
                val minutes = data.optInt("minutes", 0)
                if (child == null || app == null || minutes <= 0) null
                else s.timeRequestTitle(child, minutes, app) to (data.str("reason") ?: s.timeRequestDefault)
            }
            "time_decision" -> {
                if (!data.has("approved")) null else {
                    val app = data.str("app_name") ?: ""
                    if (data.optBoolean("approved")) {
                        s.approved to s.approvedBody(app, data.optInt("minutes", 0))
                    } else {
                        s.denied to app
                    }
                }
            }
            "low_battery" -> {
                if (child == null || !data.has("battery")) null
                else s.lowBatteryTitle(child, data.optInt("battery")) to s.lowBatteryBody
            }
            "offline" -> child?.let { s.offlineTitle(it) to s.offlineBody }
            "web_filter_off" -> child?.let { s.webFilterOffTitle(it) to s.webFilterOffBody }
            "place_arrive" -> {
                val place = data.str("place")
                if (child == null || place == null) null else s.placeArriveTitle(child, place) to ""
            }
            "place_leave" -> {
                val place = data.str("place")
                if (child == null || place == null) null else s.placeLeaveTitle(child, place) to ""
            }
            "new_app" -> {
                val apps = data.optJSONArray("apps")
                if (child == null || apps == null || apps.length() == 0) null else {
                    val names = (0 until apps.length()).mapNotNull { apps.optString(it).takeIf(String::isNotBlank) }
                    s.newAppTitle(child) to (names.take(3).joinToString(", ") + if (names.size > 3) "…" else "")
                }
            }
            "missed_call" -> {
                val isParent = flutterPrefs().getString(FLUTTER_ROLE, null) == "parent"
                s.missedCall to (if (isParent) child ?: "" else s.parent)
            }
            else -> null
        }

    /** Огоҳиномаи паёмро сохта, аз рӯйи фарзанд гурӯҳбандӣ мекунад. */
    private fun showMessage(eventId: Int, childId: Int?, childName: String?, sender: String, text: String) {
        val key = childId ?: 0
        val notification = NotificationCompat.Builder(this, CH_MESSAGES)
            .setSmallIcon(R.drawable.ic_stat_nigoh)
            .setContentTitle(sender)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setGroup("nigoh_chat_$key")
            .setAutoCancel(true)
            .setSubText(childName)
            .setContentIntent(launchIntent(100_000 + (eventId % 100_000), "message", childId, peerName = childName ?: sender))
            .build()
        post(messageId(key), notification)
    }

    /** Огоҳии оилавиро барои вақт, батарея, offline ё барномаи нав нишон медиҳад. */
    private fun showFamily(eventId: Int, kind: String, childId: Int?, title: String, body: String, childName: String?) {
        val notification = NotificationCompat.Builder(this, CH_FAMILY)
            .setSmallIcon(R.drawable.ic_stat_nigoh)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setCategory(
                if (kind == "missed_call") NotificationCompat.CATEGORY_MISSED_CALL
                else NotificationCompat.CATEGORY_STATUS
            )
            .setContentIntent(launchIntent(200_000 + (eventId % 100_000), kind, childId, peerName = childName))
            .build()
        post(40_000 + (eventId % 100_000), notification)
    }

    /** SOS-и full-screen-ро нишон дода, то хомӯш кардан alarm менавозад. */
    private fun showSos(childId: Int, title: String, text: String, childName: String?, s: NotifyStrings) {
        val notification = NotificationCompat.Builder(this, CH_SOS)
            .setSmallIcon(R.drawable.ic_stat_nigoh)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setColor(Color.RED)
            .setColorized(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)
            .setContentIntent(launchIntent(300_000 + childId, "sos", childId, peerName = childName))
            .setFullScreenIntent(launchIntent(310_000 + childId, "sos", childId, peerName = childName, fullScreen = true), true)
            .setDeleteIntent(serviceIntent(320_000 + childId, ACTION_STOP_ALARM, childId = childId))
            .addAction(0, s.silence, serviceIntent(330_000 + childId, ACTION_STOP_ALARM, childId = childId))
            .build()
        post(sosId(childId), notification)
        stopRinging()
        ringingSosChild = childId
        startRinging(alarm = true)
        bringToFront("sos:$childId:${System.currentTimeMillis()}", "sos", childId, peerName = childName)
    }

    /** Занги воридшавандаро бо қабул, рад, ringtone ва timeout нишон медиҳад. */
    private fun showCall(callId: Int, childId: Int, peer: String, text: String, s: NotifyStrings) {
        val notification = NotificationCompat.Builder(this, CH_CALLS)
            .setSmallIcon(R.drawable.ic_stat_nigoh)
            .setContentTitle(peer)
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(true)
            .setTimeoutAfter(CALL_TIMEOUT_MS)
            .setContentIntent(launchIntent(400_000 + (callId % 100_000), "call", childId, callId, peer))
            .setFullScreenIntent(
                launchIntent(500_000 + (callId % 100_000), "call", childId, callId, peer, fullScreen = true), true
            )
            .addAction(0, s.decline, serviceIntent(600_000 + (callId % 100_000), ACTION_DECLINE_CALL, callId = callId))
            .addAction(0, s.accept, launchIntent(700_000 + (callId % 100_000), "call", childId, callId, peer, accept = true))
            .build()
        post(callNotifId(callId), notification)
        stopRinging()
        ringingCallId = callId
        startRinging(alarm = false)
        main.postDelayed({ if (ringingCallId == callId) endCallUi(callId) }, CALL_TIMEOUT_MS)
        watchCall(callId)
        bringToFront("call:$callId", "call", childId, callId, peer)
    }

    /**
     * Ҳангоми истифодаи телефон ва иҷозати overlay экрани занг ё SOS-ро мустақим мекушояд;
     * дар экрани қулф full-screen intent ин корро мекунад. [key] такрорро пешгирӣ менамояд.
     */
    private fun bringToFront(key: String, kind: String, childId: Int, callId: Int? = null, peerName: String? = null) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return
        // Дар экрани қулф ё хомӯш full-screen intent аллакай ин корро мекунад.
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!power.isInteractive || keyguard.isKeyguardLocked) return
        if (lastDirectLaunch == key) return
        lastDirectLaunch = key
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            action = "tj.nigoh.notify.FRONT.$key"
            putExtra(EXTRA_KIND, kind)
            putExtra(EXTRA_CHILD_ID, childId)
            if (callId != null) putExtra(EXTRA_CALL_ID, callId)
            if (peerName != null) putExtra(EXTRA_PEER_NAME, peerName)
            putExtra(EXTRA_ACCEPT, false)
            putExtra(EXTRA_FULL_SCREEN, true)
        }
        runCatching { startActivity(intent) }
            .onFailure { Log.w(TAG, "direct launch failed: ${it.message}") }
    }

    /** Вазъи зангро назорат карда, баъди қабул ё рад садоро қатъ мекунад. */
    private fun watchCall(callId: Int) {
        callWatcher?.interrupt()
        callWatcher = Thread({
            while (ringingCallId == callId) {
                try {
                    Thread.sleep(2_000)
                } catch (_: InterruptedException) {
                    return@Thread
                }
                val status = runCatching {
                    request("GET", "/api/mobile/v3/calls/$callId", 10_000)
                        .let { it.optJSONObject("call") ?: it }.optString("status", "ringing")
                }.getOrNull() ?: continue
                if (status != "ringing") {
                    // Ҳангоми қабул дар ҳамин телефон садо, дар дигар ҳолат корт ҳам қатъ мешавад.
                    main.post {
                        if (status == "active" || status == "accepted") {
                            if (ringingCallId == callId) stopRinging()
                            NotificationManagerCompat.from(this).cancel(callNotifId(callId))
                        } else {
                            endCallUi(callId)
                        }
                    }
                    return@Thread
                }
            }
        }, "nigoh-call-watch").also { it.start() }
    }

    /** Садоро қатъ ва огоҳиномаи зангро хориҷ мекунад. */
    fun endCallUi(callId: Int) {
        if (ringingCallId == callId) stopRinging()
        NotificationManagerCompat.from(this).cancel(callNotifId(callId))
    }

    /** Зангро дар сервер рад карда, огоҳиномаи онро хориҷ мекунад. */
    private fun declineCall(callId: Int) {
        endCallUi(callId)
        Thread {
            runCatching { request("POST", "/api/mobile/v3/calls/$callId/decline", 15_000) }
                .onFailure { Log.w(TAG, "decline failed: ${it.message}") }
        }.start()
    }

    // Навохтани alarm, ringtone ва vibration.

    /**
     * Alarm-и SOS ё ringtone-и зангро бо vibration менавозад ва CPU-ро бедор нигоҳ медорад.
     */
    private fun startRinging(alarm: Boolean) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val uri = RingtoneManager.getDefaultUri(
            if (alarm) RingtoneManager.TYPE_ALARM else RingtoneManager.TYPE_RINGTONE
        ) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        if (alarm) {
            runCatching {
                savedAlarmVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                audio.setStreamVolume(
                    AudioManager.STREAM_ALARM, audio.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0
                )
            }
        }
        val silentMode = !alarm && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL
        if (uri != null && !silentMode) {
            player = runCatching {
                MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(
                                if (alarm) AudioAttributes.USAGE_ALARM
                                else AudioAttributes.USAGE_NOTIFICATION_RINGTONE
                            )
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(this@NotifyService, uri)
                    isLooping = true
                    prepare()
                    start()
                }
            }.onFailure { Log.w(TAG, "ringtone failed", it) }.getOrNull()
        }
        if (alarm || audio.ringerMode != AudioManager.RINGER_MODE_SILENT) {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val pattern = if (alarm) longArrayOf(0, 800, 400, 800, 400) else longArrayOf(0, 1000, 1000)
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(pattern, 0)
                }
            }
        }
        runCatching {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "nigoh:ringing").apply {
                acquire(if (alarm) 10 * 60_000L else CALL_TIMEOUT_MS + 5_000L)
            }
        }
    }

    /** Alarm, ringtone ва vibration-ро аз ҳар thread бехатар қатъ мекунад. */
    fun stopRinging() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            main.post { stopRinging() }
            return
        }
        player?.let { runCatching { it.stop() }; it.release() }
        player = null
        vibrator?.cancel()
        vibrator = null
        savedAlarmVolume?.let { volume ->
            runCatching {
                (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                    .setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
            }
        }
        savedAlarmVolume = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        ringingCallId = null
        ringingSosChild = null
        callWatcher?.interrupt()
        callWatcher = null
    }

    /** Садои SOS-ро хомӯш карда, корти огоҳиномаро нигоҳ медорад. */
    fun stopAlarm() {
        main.post {
            if (ringingSosChild != null) stopRinging()
        }
    }

    /** Ҳангоми кушодани UI-и занг садо ва корти зангро қатъ мекунад. */
    fun stopCallRinging(callId: Int?) {
        main.post {
            if (ringingCallId != null && (callId == null || ringingCallId == callId)) stopRinging()
            if (callId != null) NotificationManagerCompat.from(this).cancel(callNotifId(callId))
        }
    }
}
