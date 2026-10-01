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

class AppBlockMonitorService : Service() {
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

    private val screenReceiver = object : android.content.BroadcastReceiver() {
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

    private val monitor = object : Runnable {
        override fun run() {
            checkForegroundApp()
            if (screenOn) handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

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
                .setContentText("Муҳофизати барномаҳо фаъол аст")
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        )
        if (screenOn) handler.post(monitor)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handleAccessibilityRequest(intent)
        return START_STICKY
    }

    private fun handleAccessibilityRequest(intent: Intent?) {
        val target = intent?.getStringExtra(EXTRA_OVERLAY_PACKAGE) ?: return
        val reason = intent.getStringExtra(EXTRA_OVERLAY_REASON)
            ?: "Ин барнома аз ҷониби волидайн маҳкам шудааст"
        if (target.isBlank() || target == packageName || target in SAFE_PACKAGES) return
        // Accessibility may be enabled before Android grants overlay access.
        // Do not let a TYPE_APPLICATION_OVERLAY exception crash the service.
        handler.post { runCatching { showOverlay(target, reason) } }
    }

    override fun onDestroy() {
        handler.removeCallbacks(monitor)
        flushActiveUsage()
        runCatching { unregisterReceiver(screenReceiver) }
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

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
        // UsageEvents has no target intent/URI. A Settings activity class does
        // not identify our app; intercepting it prevents legitimate setup.
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
            isBlocked -> showOverlay(openedPackage, "Ин барнома аз ҷониби волидайн маҳкам шудааст")
            scheduleActive -> showOverlay(openedPackage, "Ҳоло вақти маҳдудшудаи барнома аст")
            limitExceeded -> showOverlay(openedPackage, "Лимити вақти имрӯз ба охир расид")
            else -> removeOverlay()
        }
    }

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
        // A backward clock change must not grant a fresh daily allowance.
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

    private fun finishActiveSession() {
        activePackage = null
        activeSessionStartedAt = 0L
        activeSessionElapsedSeconds = 0L
        activeSessionPersistedSeconds = 0L
        lastUsageFlushAt = 0L
    }

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

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        })
    }

    private fun isScheduleActive(schedule: JSONObject): Boolean {
        if (!schedule.optBoolean("enabled", false)) return false
        val weekdays = schedule.optJSONArray("weekdays") ?: return false
        val now = Calendar.getInstance()
        // App rules use Monday=1 ... Sunday=7; Android Calendar uses Sunday=1.
        val day = ((now.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
        val start = parseMinutes(schedule.optString("start", "16:00")) ?: return false
        val end = parseMinutes(schedule.optString("end", "18:00")) ?: return false
        val current = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        fun enabledOn(targetDay: Int): Boolean {
            for (i in 0 until weekdays.length()) if (weekdays.optInt(i) == targetDay) return true
            return false
        }
        if (start <= end) return enabledOn(day) && current in start until end
        // For an overnight window, the after-midnight portion belongs to the
        // previous selected weekday (e.g. Monday 22:00-01:00).
        return if (current >= start) {
            enabledOn(day)
        } else {
            val previousDay = if (day == 1) 7 else day - 1
            enabledOn(previousDay)
        }
    }

    private fun parseMinutes(value: String): Int? {
        val parts = value.trim().split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return if (hour in 0..23 && minute in 0..59) hour * 60 + minute else null
    }

    private fun latestForegroundPackage(): ForegroundApp? {
        val end = System.currentTimeMillis()
        // Activity events are emitted on resume, not continuously. Keep a
        // useful window and fall back to the most recently used package so the
        // monitor does not silently stop after the first few seconds offline.
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
        fun dp(value: Int) = (value * density).toInt()
        val view = object : LinearLayout(this) {
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
                text = "Барномаи «$label» аз тарафи волидайн назорат мешавад."
                textSize = 16f
                setTextColor(Color.rgb(190, 205, 221))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(26))
            })
            if (tamper) {
                val pin = EditText(context).apply {
                    hint = "PIN-и волидайн"
                    inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
                    setTextColor(Color.WHITE)
                    setHintTextColor(Color.LTGRAY)
                }
                addView(pin, LinearLayout.LayoutParams(-1, dp(54)))
                addView(Button(context).apply {
                    text = "Тасдиқи PIN"
                    setOnClickListener {
                        if (verifyParentPin(pin.text.toString())) {
                            goHome()
                        } else {
                            pin.error = "PIN нодуруст аст"
                            Toast.makeText(context, "PIN нодуруст аст", Toast.LENGTH_SHORT).show()
                        }
                    }
                }, LinearLayout.LayoutParams(-1, dp(52)))
            } else {
                addView(Button(context).apply {
                    text = "Ба экрани асосӣ"
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
            // Permission may be revoked between canDrawOverlays and addView.
            overlayPackage = null
        } catch (_: WindowManager.BadTokenException) {
            overlayPackage = null
        }
    }

    private fun removeOverlay() {
        overlay?.let { runCatching { windowManager.removeView(it) } }
        overlay = null
        overlayPackage = null
    }

    private fun verifyParentPin(pin: String): Boolean {
        if (!Regex("^\\d{4}$").matches(pin)) return false
        return PinSecurity.verify(this, pin).allowed
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Муҳофизати NIGOH",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
    }

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

        fun isDeviceAdminEnabled(context: Context): Boolean {
            val manager = context.getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            return manager.isAdminActive(
                ComponentName(context, TamperDeviceAdminReceiver::class.java)
            )
        }

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
