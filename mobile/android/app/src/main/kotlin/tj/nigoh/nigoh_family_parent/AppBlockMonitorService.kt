// Файл: foreground service барои бастани барномаҳои телефони фарзанд;
// истифодаи рӯзонаро ҳисоб карда, барномаҳои манъшударо бо overlay мепӯшонад.

package tj.nigoh.nigoh_family_parent

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.text.InputType
import android.widget.Toast
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Calendar
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Қоидаҳои волидайнро дар телефони фарзанд татбиқ мекунад: барномаи фаъол ва
 * вақти истифодаашро назорат карда, барои манъ, ҷадвал ё лимит overlay нишон медиҳад.
 */
class AppBlockMonitorService : Service() {
    /** package ва class-и Activity-и ҳозир фаъолро нигоҳ медорад. */
    private data class ForegroundApp(val packageName: String, val className: String?)
    private val handler = Handler(Looper.getMainLooper())
    private var overlay: View? = null
    private var overlayPackage: String? = null
    private lateinit var windowManager: WindowManager
    private lateinit var usageStats: UsageStatsManager
    private var screenOn = true
    private var activePackage: String? = null
    private var activeSessionStartedAt = 0L
    private var activeSessionElapsedSeconds = 0L
    private var activeSessionPersistedSeconds = 0L
    private var lastUsageFlushAt = 0L

    /** Ҳангоми хомӯшии экран истифодаи ҷориро сабт ва назоратро муваққатан қатъ мекунад. */
    private val screenReceiver = object : android.content.BroadcastReceiver() {
        /** Ба тағйири ҳолати экран ҷавоб дода, monitor ва overlay-ро идора мекунад. */
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    screenOn = false
                    flushActiveUsage()
                    finishActiveSession()
                    handler.removeCallbacks(monitor)
                    removeOverlay()
                }
                Intent.ACTION_SCREEN_ON -> {
                    screenOn = true
                    handler.removeCallbacks(monitor)
                    handler.post(monitor)
                }
            }
        }
    }

    /** Санҷиши даврии барномаи фаъолро то фурӯзон будани экран такрор мекунад. */
    private val monitor = object : Runnable {
        /** Як даври назоратро иҷро ва даври навбатиро ба навбат мегузорад. */
        override fun run() {
            checkForegroundApp()
            if (screenOn) handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    /**
     * Хидматҳои система, receiver-и экран ва огоҳиномаи foreground-ро омода карда,
     * назоратро оғоз мекунад.
     */
    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        usageStats = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        screenOn = (getSystemService(POWER_SERVICE) as PowerManager).isInteractive
        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, screenFilter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenReceiver, screenFilter)
        }
        rolloverLocalUsageIfNeeded()
        createNotificationChannel()
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("NIGOH Family")
                .setContentText(UiStrings.protectionActive(this))
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        )
        if (screenOn) handler.post(monitor)
    }

    /** Дархости overlay-и Accessibility-ро коркард карда, хидматро sticky нигоҳ медорад. */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handleAccessibilityRequest(intent)
        return START_STICKY
    }

    /** Барои барномаи аз Accessibility омада overlay-и басташавиро нишон медиҳад. */
    private fun handleAccessibilityRequest(intent: Intent?) {
        val target = intent?.getStringExtra(EXTRA_OVERLAY_PACKAGE) ?: return
        val reason = intent.getStringExtra(EXTRA_OVERLAY_REASON)
            ?: UiStrings.reasonBlocked(this)
        if (target.isBlank() || target == packageName || target in SAFE_PACKAGES) return
        // Accessibility метавонад пеш аз иҷозати overlay фаъол шавад; хато набояд хидматро бандад.
        handler.post { runCatching { showOverlay(target, reason) } }
    }

    /** Назоратро қатъ, истифодаи ҷориро сабт ва overlay-ро хориҷ мекунад. */
    override fun onDestroy() {
        handler.removeCallbacks(monitor)
        flushActiveUsage()
        runCatching { unregisterReceiver(screenReceiver) }
        removeOverlay()
        super.onDestroy()
    }

    /** Нишон медиҳад, ки ин хидмат binding-ро дастгирӣ намекунад. */
    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Барномаи фаъолро ёфта, истифодаашро сабт мекунад ва мувофиқи қоида overlay-ро идора менамояд.
     */
    private fun checkForegroundApp() {
        if (!screenOn) return
        if (!hasUsageAccess(this) || !Settings.canDrawOverlays(this)) {
            flushActiveUsage()
            removeOverlay()
            return
        }
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        rolloverLocalUsageIfNeeded(prefs)
        val foreground = latestForegroundPackage() ?: run {
            finishActiveSession()
            return
        }
        val openedPackage = foreground.packageName
        // UsageEvents intent ё URI надорад; бастани Settings ба танзими дурусти барнома халал мерасонад.
        if (openedPackage == packageName || openedPackage in SAFE_PACKAGES) {
            flushActiveUsage()
            finishActiveSession()
            removeOverlay()
            return
        }
        if (overlay == null) recordForegroundSession(prefs, openedPackage)
        val rule = ruleFor(prefs, openedPackage)
        val blocked = prefs.getStringSet(BLOCKED_KEY, emptySet()) ?: emptySet()
        val isBlocked = rule?.optBoolean("blocked", false) == true || openedPackage in blocked
        val scheduleActive = rule?.optJSONObject("schedule")?.let(::isScheduleActive) == true
        val limitExceeded = rule?.optInt("dailyLimitMinutes", 0)?.let {
            it > 0 && todayUsageMillis(prefs, openedPackage) >= it * 60_000L
        } == true
        when {
            isBlocked -> showOverlay(openedPackage, UiStrings.reasonBlocked(this))
            scheduleActive -> showOverlay(openedPackage, UiStrings.reasonSchedule(this))
            limitExceeded -> showOverlay(openedPackage, UiStrings.reasonLimit(this))
            else -> removeOverlay()
        }
    }

    /**
     * Дар нисфи шаб ҳисобкунакҳои рӯзи навро оғоз мекунад; ақиб бурдани соат
     * лимити рӯзонаро аз нав намекунад.
     */
    private fun rolloverLocalUsageIfNeeded(
        prefs: android.content.SharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE),
    ) {
        val now = System.currentTimeMillis()
        val today = SimpleDateFormat(DATE_FORMAT, Locale.US).format(System.currentTimeMillis())
        val storedDate = prefs.getString(USAGE_DATE_KEY, null)
        val lastWallClock = prefs.getLong(LAST_WALL_CLOCK_KEY, 0L)
        if (storedDate == today) {
            if (lastWallClock == 0L || now >= lastWallClock) {
                lastWallClockMillis = now
            }
            return
        }
        // Ақиб бурдани соат набояд лимити нави рӯзона диҳад.
        if (lastWallClock > now + CLOCK_ROLLBACK_TOLERANCE_MS) {
            lastWallClockMillis = now
            return
        }
        flushActiveUsage(prefs)
        finishActiveSession()
        val editor = prefs.edit().putString(USAGE_DATE_KEY, today)
        prefs.all.keys.filter { it.startsWith(USAGE_SECONDS_PREFIX) || it.startsWith(USED_MINUTES_PREFIX) }
            .forEach(editor::remove)
        editor.apply()
        lastWallClockMillis = now
        activePackage = null
        activeSessionStartedAt = 0L
        activeSessionElapsedSeconds = 0L
        activeSessionPersistedSeconds = 0L
    }

    private var lastWallClockMillis = 0L

    /**
     * Давомнокии кори барномаи фаъолро ҳисоб карда, давра ба давра нигоҳ медорад.
     */
    private fun recordForegroundSession(
        prefs: android.content.SharedPreferences,
        packageName: String,
    ) {
        val now = SystemClock.elapsedRealtime()
        if (activePackage != packageName) {
            flushActiveUsage(prefs)
            finishActiveSession()
            activePackage = packageName
            activeSessionStartedAt = now
            activeSessionElapsedSeconds = 0L
            activeSessionPersistedSeconds = prefs.getLong(USAGE_SECONDS_PREFIX + packageName, 0L)
            lastUsageFlushAt = now
        }
        activeSessionElapsedSeconds = ((now - activeSessionStartedAt) / 1000L).coerceAtLeast(0L)
        lastWallClockMillis = System.currentTimeMillis()
        if (now - lastUsageFlushAt >= USAGE_FLUSH_INTERVAL_MS) flushActiveUsage(prefs)
    }

    /** Сония ва дақиқаҳои ҷамъшудаи барномаи фаъолро ба shared preferences менависад. */
    private fun flushActiveUsage(
        prefs: android.content.SharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE),
    ) {
        val packageName = activePackage ?: run {
            if (lastWallClockMillis > 0L) prefs.edit().putLong(LAST_WALL_CLOCK_KEY, lastWallClockMillis).apply()
            return
        }
        val totalSeconds = activeSessionPersistedSeconds + activeSessionElapsedSeconds
        prefs.edit()
            .putLong(USAGE_SECONDS_PREFIX + packageName, totalSeconds)
            .putInt(USED_MINUTES_PREFIX + packageName, (totalSeconds / 60L).toInt())
            .putLong(LAST_WALL_CLOCK_KEY, lastWallClockMillis.takeIf { it > 0L } ?: System.currentTimeMillis())
            .apply()
        activeSessionPersistedSeconds = totalSeconds
        activeSessionStartedAt = SystemClock.elapsedRealtime()
        activeSessionElapsedSeconds = 0L
        lastUsageFlushAt = activeSessionStartedAt
    }

    /** session-и дар memory будаи барномаи фаъолро ба охир мерасонад. */
    private fun finishActiveSession() {
        activePackage = null
        activeSessionStartedAt = 0L
        activeSessionElapsedSeconds = 0L
        activeSessionPersistedSeconds = 0L
        lastUsageFlushAt = 0L
    }

    /** Қоидаи [packageName]-ро аз JSON-и нигоҳдошта меёбад. */
    private fun ruleFor(prefs: android.content.SharedPreferences, packageName: String): JSONObject? {
        val raw = prefs.getString(RULES_KEY, null) ?: return null
        return runCatching {
            val rules = org.json.JSONArray(raw)
            for (index in 0 until rules.length()) {
                val item = rules.optJSONObject(index) ?: continue
                if (item.optString("packageName") == packageName) return item
            }
            null
        }.getOrNull()
    }

    /**
     * Истифодаи имрӯзаи барномаро аз қимати калонтарини Android ва ҳисобкунаки NIGOH мегирад.
     */
    private fun todayUsageMillis(
        prefs: android.content.SharedPreferences,
        packageName: String,
    ): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val systemMillis = usageStats.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            calendar.timeInMillis,
            System.currentTimeMillis()
        ).firstOrNull { it.packageName == packageName }?.let {
            it.totalTimeInForeground
        } ?: 0L
        val localMillis = prefs.getLong(USAGE_SECONDS_PREFIX + packageName, 0L) * 1000L
        return maxOf(systemMillis, localMillis)
    }

    /** Корбарро ба экрани Home-и Android мебарад. */
    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        })
    }

    /**
     * Фаъол будани фосилаи ҷадвалро муайян мекунад; фосилаи шабгузар ба рӯзи оғоз тааллуқ дорад.
     */
    private fun isScheduleActive(schedule: JSONObject): Boolean {
        if (!schedule.optBoolean("enabled", false)) return false
        val weekdays = schedule.optJSONArray("weekdays") ?: return false
        val now = Calendar.getInstance()
        // Қоидаҳо Душанбе=1…Якшанбе=7, аммо Android Calendar аз Якшанбе оғоз мекунад.
        val day = ((now.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
        val start = parseMinutes(schedule.optString("start", "16:00")) ?: return false
        val end = parseMinutes(schedule.optString("end", "18:00")) ?: return false
        val current = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        /** Интихоб шудани рӯзи додашударо дар ҷадвал месанҷад. */
        fun enabledOn(targetDay: Int): Boolean {
            for (i in 0 until weekdays.length()) if (weekdays.optInt(i) == targetDay) return true
            return false
        }
        if (start <= end) return enabledOn(day) && current in start until end
        // Қисми баъди нисфи шаб ба рӯзи интихобшудаи пешина тааллуқ дорад.
        return if (current >= start) {
            enabledOn(day)
        } else {
            val previousDay = if (day == 1) 7 else day - 1
            enabledOn(previousDay)
        }
    }

    /** Вақти «HH:mm»-ро ба дақиқаҳои баъди нисфи шаб табдил медиҳад. */
    private fun parseMinutes(value: String): Int? {
        val parts = value.trim().split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return if (hour in 0..23 && minute in 0..59) hour * 60 + minute else null
    }

    /**
     * Барномаи охирини foreground-ро аз UsageEvents ё аз истифодаи охирин меёбад.
     */
    private fun latestForegroundPackage(): ForegroundApp? {
        val end = System.currentTimeMillis()
        // Event-и Activity танҳо ҳангоми resume меояд; fallback назоратро баъди чанд сония нигоҳ медорад.
        val events = usageStats.queryEvents(end - 60_000, end)
        val event = UsageEvents.Event()
        var latestPackage: ForegroundApp? = null
        var latestTime = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val foreground = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (foreground && event.timeStamp >= latestTime) {
                latestTime = event.timeStamp
                latestPackage = ForegroundApp(event.packageName, event.className)
            }
        }
        if (latestPackage != null) return latestPackage
        return usageStats.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            end - 15 * 60_000L,
            end,
        )?.maxByOrNull { it.lastTimeUsed }?.let { ForegroundApp(it.packageName, null) }
    }

    /**
     * Барои [blockedPackage] overlay-и пурраро бо [reason] нишон медиҳад;
     * дар ҳолати [tamper] PIN-и волидайнро мепурсад.
     */
    private fun showOverlay(blockedPackage: String, reason: String, tamper: Boolean = false) {
        if (overlay != null && overlayPackage == blockedPackage) return
        removeOverlay()
        overlayPackage = blockedPackage
        val label = runCatching {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(blockedPackage, 0)
            ).toString()
        }.getOrDefault(blockedPackage)

        val density = resources.displayMetrics.density
        /** dp-ро барои зичии экран ба pixel табдил медиҳад. */
        fun dp(value: Int) = (value * density).toInt()
        /** View-и overlay-ро месозад ва пахши Back-ро ба Home равона мекунад. */
        val view = object : LinearLayout(this) {
            /** Тугмаи Back-ро гирифта, корбарро ба Home мебарад. */
            override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {
                if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                    goHome()
                    return true
                }
                return super.onKeyPreIme(keyCode, event)
            }
        }.apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            isFocusableInTouchMode = true
            requestFocus()
            setPadding(dp(30), dp(30), dp(30), dp(30))
            setBackgroundColor(Color.rgb(8, 25, 47))
            addView(TextView(context).apply {
                text = "🛡"
                textSize = 64f
                gravity = Gravity.CENTER
            })
            addView(TextView(context).apply {
                text = reason
                textSize = 25f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, dp(18), 0, dp(10))
            })
            addView(TextView(context).apply {
                text = UiStrings.overlayManaged(this@AppBlockMonitorService, label)
                textSize = 16f
                setTextColor(Color.rgb(190, 205, 221))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(26))
            })
            if (tamper) {
                val pin = EditText(context).apply {
                    hint = UiStrings.parentPinHint(this@AppBlockMonitorService)
                    inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
                    setTextColor(Color.WHITE)
                    setHintTextColor(Color.LTGRAY)
                }
                addView(pin, LinearLayout.LayoutParams(-1, dp(54)))
                addView(Button(context).apply {
                    text = UiStrings.confirmPin(this@AppBlockMonitorService)
                    setOnClickListener {
                        if (verifyParentPin(pin.text.toString())) {
                            goHome()
                        } else {
                            pin.error = UiStrings.wrongPinShort(this@AppBlockMonitorService)
                            Toast.makeText(context, UiStrings.wrongPinShort(context), Toast.LENGTH_SHORT).show()
                        }
                    }
                }, LinearLayout.LayoutParams(-1, dp(52)))
            } else {
                addView(Button(context).apply {
                    text = UiStrings.toHome(this@AppBlockMonitorService)
                    setOnClickListener { goHome() }
                }, LinearLayout.LayoutParams(-1, dp(52)))
            }
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.OPAQUE
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
        try {
            windowManager.addView(view, params)
            overlay = view
        } catch (_: SecurityException) {
            // Иҷозат метавонад байни canDrawOverlays ва addView бекор шавад.
            overlayPackage = null
        } catch (_: WindowManager.BadTokenException) {
            overlayPackage = null
        }
    }

    /** Overlay-и басташавиро, агар намоён бошад, хориҷ мекунад. */
    private fun removeOverlay() {
        overlay?.let { runCatching { windowManager.removeView(it) } }
        overlay = null
        overlayPackage = null
    }

    /** PIN-и чоррақамаи волидайнро бо [PinSecurity] месанҷад. */
    private fun verifyParentPin(pin: String): Boolean {
        if (!Regex("^\\d{4}$").matches(pin)) return false
        return PinSecurity.verify(this, pin).allowed
    }

    /** Channel-и аҳамияташ пастро барои огоҳиномаи муҳофизати фаъол месозад. */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    UiStrings.protectionChannel(this),
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
    }

    /** Калидҳои нигоҳдорӣ, фосилаҳои назорат ва package-ҳои бехатарро ҷамъ мекунад. */
    companion object {
        const val PREFS_NAME = "nigoh_app_control"
        const val BLOCKED_KEY = "blocked_packages"
        const val RULES_KEY = "app_control_rules_json"
        const val EXTRA_OVERLAY_PACKAGE = "overlay_package"
        const val EXTRA_OVERLAY_REASON = "overlay_reason"
        private const val USAGE_DATE_KEY = "usage_date"
        private const val USAGE_SECONDS_PREFIX = "usage_seconds:"
        private const val USED_MINUTES_PREFIX = "used_today_minutes:"
        private const val DATE_FORMAT = "yyyy-MM-dd"
        private const val POLL_INTERVAL_MS = 1_200L
        private const val USAGE_FLUSH_INTERVAL_MS = 60_000L
        private const val LAST_WALL_CLOCK_KEY = "last_wall_clock_millis"
        private const val CLOCK_ROLLBACK_TOLERANCE_MS = 5_000L
        private const val CHANNEL_ID = "nigoh_protection"
        private const val NOTIFICATION_ID = 2401
        private val SAFE_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.settings",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller"
        )

        /** Фаъол будани NIGOH-ро ҳамчун device admin месанҷад. */
        fun isDeviceAdminEnabled(context: Context): Boolean {
            val manager = context.getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            return manager.isAdminActive(
                ComponentName(context, TamperDeviceAdminReceiver::class.java)
            )
        }

        /** Мавҷуд будани usage access-ро барои дидани барномаи фаъол месанҷад. */
        fun hasUsageAccess(context: Context): Boolean {
            val appOps = context.getSystemService(APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            ) else appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
            return mode == AppOpsManager.MODE_ALLOWED
        }

        /** Фаъол будани Accessibility service-и NIGOH-ро месанҷад. */
        fun isAccessibilityEnabled(context: Context): Boolean {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ).orEmpty()
            return enabled.split(':').any { value ->
                ComponentName.unflattenFromString(value)?.let { component ->
                    component.packageName == context.packageName &&
                        component.className == NIGOHAccessibilityService::class.java.name
                } == true
            }
        }

        /**
         * Аз хидмат барои [targetPackage] overlay-и фаврии басташавиро дархост мекунад.
         */
        fun requestOverlayFromAccessibility(
            context: Context,
            targetPackage: String,
            reason: String,
        ) {
            if (
                targetPackage.isBlank() ||
                targetPackage == context.packageName ||
                !Settings.canDrawOverlays(context)
            ) return
            val intent = Intent(context, AppBlockMonitorService::class.java).apply {
                putExtra(EXTRA_OVERLAY_PACKAGE, targetPackage)
                putExtra(EXTRA_OVERLAY_REASON, reason)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
