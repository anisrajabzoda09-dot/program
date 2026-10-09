// Файл: Activity-и асосии Flutter ва пули байни Dart ва Android;
// навсозӣ, идораи дастгоҳ, PIN, package event ва огоҳиномаҳоро мепайвандад.

package tj.nigoh.nigoh_family_parent

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.content.pm.ApplicationInfo
import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * platform channel-ҳои Flutter-ро сабт мекунад, хидмати бастани барномаҳоро
 * оғоз менамояд ва кушодашавии занг, SOS ва паёмро ба Dart мерасонад.
 */
class MainActivity : FlutterActivity() {
    /** Сабти муваққатии кушодашавиҳои автоматиро барои пешгирии такрор нигоҳ медорад. */
    companion object {
        /** Занг ё SOS-и аллакай расонидашударо бо elapsedRealtime нигоҳ медорад. */
        private val recentAutoLaunches = HashMap<String, Long>()
        /** Рамзи дархости розигии VPN барои филтри сайтҳо. */
        private const val VPN_REQUEST_CODE = 4242
    }

    /** Натиҷаи тирезаи розигии VPN, ки ба Dart бармегардад. */
    private var pendingVpnResult: MethodChannel.Result? = null

    /** Ҷавоби тирезаи розигии VPN-ро мегирад ва филтрро оғоз мекунад. */
    @Deprecated("FlutterActivity still routes activity results here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_REQUEST_CODE) return
        val granted = resultCode == RESULT_OK
        if (granted) WebFilterVpnService.startIfEnabled(this)
        pendingVpnResult?.success(granted)
        pendingVpnResult = null
    }

    private val channelName = "tj.nigoh/update"
    private val deviceControlChannelName = "tj.nigoh/device_control"
    private val packageEventsChannelName = "tj.nigoh/package_events"
    private var pendingUpdateUrl: String? = null
    private var pendingUpdateVersion: String? = null
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var packageEventSink: EventChannel.EventSink? = null
    private var packageReceiverRegistered = false
    private var notifyChannel: MethodChannel? = null
    private var pendingLaunch: Map<String, Any?>? = null
    /** Broadcast-и насб, нест ё нав шудани барномаро ба Dart мефиристад. */
    private val packageReceiver = object : BroadcastReceiver() {
        /** Тағйири package-ро гирифта, номи онро ба package_events мерасонад. */
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_PACKAGE_ADDED,
                Intent.ACTION_PACKAGE_REMOVED,
                Intent.ACTION_PACKAGE_REPLACED ->
                    packageEventSink?.success(intent.data?.schemeSpecificPart ?: "")
            }
        }
    }
    /**
     * Channel-ҳои навсозӣ, идораи дастгоҳ, package event ва огоҳиномаро бо handler-ҳояшон сабт мекунад.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureNotifyChannel(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> {
                        val baseUrl = call.argument<String>("baseUrl")?.trimEnd('/')
                        if (baseUrl.isNullOrBlank()) {
                            result.error("invalid_url", "Update server URL is empty", null)
                        } else {
                            checkForUpdate(baseUrl, result)
                        }
                    }
                    "installUpdate" -> {
                        val url = call.argument<String>("downloadUrl")
                        val version = call.argument<String>("version") ?: "latest"
                        if (url.isNullOrBlank()) {
                            result.error("invalid_url", "APK download URL is empty", null)
                        } else {
                            startUpdate(url, version, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        /** StreamHandler-и пешрафти навсозиро барои пайваст ва қатъ шудани listener идора мекунад. */
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "tj.nigoh/update_progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                /** Listener-и пешрафти навсозиро ба EventChannel мепайвандад. */
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    AppUpdater.listener = { event -> events.success(event) }
                }

                /** Ҳангоми қатъи stream listener-и навсозиро хориҷ мекунад. */
                override fun onCancel(arguments: Any?) {
                    AppUpdater.listener = null
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceControlChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> getInstalledAppsAsync(result)
                    "getUsageStats" -> result.success(runCatching { todayUsageStats() }.getOrDefault(emptyList()))
                    "isAccessibilityEnabled" -> {
                        val enabled = AppBlockMonitorService.isAccessibilityEnabled(this)
                        if (enabled) startProtectionService()
                        result.success(enabled)
                    }
                    "getProtectionStatus" -> result.success(protectionStatus())
                    "getBatteryLevel" -> {
                        val manager = getSystemService(BATTERY_SERVICE) as android.os.BatteryManager
                        val level = manager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        result.success(if (level in 0..100) level else null)
                    }
                    "openAppDetails" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    }
                    "openUsageSettings" -> {
                        openUsageAccessSettings()
                        result.success(true)
                    }
                    "openOverlaySettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
                        result.success(true)
                    }
                    "openAccessibilitySettings" -> {
                        openNextProtectionSetting()
                        result.success(true)
                    }
                    "openAccessibilitySettingsDirect" -> {
                        // Бевосита Accessibility мекушояд; wizard иҷозатҳои дигарро ҷудо идора мекунад.
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "openDeviceAdminSettings" -> {
                        val adminIntent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                            putExtra(
                                DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                                ComponentName(this@MainActivity, TamperDeviceAdminReceiver::class.java)
                            )
                            putExtra(
                                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                getString(R.string.device_admin_description)
                            )
                        }
                        startActivity(adminIntent)
                        result.success(true)
                    }
                    "setBlockedApps" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        getSharedPreferences(
                            AppBlockMonitorService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        ).edit().putStringSet(
                            AppBlockMonitorService.BLOCKED_KEY,
                            packages.toSet()
                        ).apply()
                        if (isBlockServiceEnabled()) startProtectionService()
                        result.success(true)
                    }
                    "setAppControlRules" -> {
                        val rawRules = call.argument<List<Any?>>("rules") ?: emptyList()
                        val rules = JSONArray()
                        val blocked = mutableSetOf<String>()
                        rawRules.forEach { raw ->
                            val map = raw as? Map<*, *> ?: return@forEach
                            val item = JSONObject()
                            map.forEach { (key, value) ->
                                if (key != null) item.put(key.toString(), jsonForRules(value))
                            }
                            val packageName = item.optString("packageName")
                            if (packageName.isNotBlank() && item.optBoolean("blocked", false)) {
                                blocked.add(packageName)
                            }
                            rules.put(item)
                        }
                        getSharedPreferences(
                            AppBlockMonitorService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        ).edit()
                            // Пеш аз monitor snapshot-и пурраи қоидаҳо нигоҳ дошта мешавад.
                            .putString(AppBlockMonitorService.RULES_KEY, rules.toString())
                            .putStringSet(AppBlockMonitorService.BLOCKED_KEY, blocked)
                            .apply()
                        if (isBlockServiceEnabled()) startProtectionService()
                        result.success(true)
                    }
                    "setWebFilter" -> {
                        val level = call.argument<String>("level") ?: WebFilterDns.LEVEL_OFF
                        val blocked = call.argument<List<String>>("blocked") ?: emptyList()
                        result.success(WebFilterVpnService.configure(this, level, blocked))
                    }
                    "getWebFilterStatus" -> result.success(WebFilterVpnService.state(this))
                    "requestWebFilterPermission" -> {
                        val consent = android.net.VpnService.prepare(this)
                        if (consent == null) {
                            WebFilterVpnService.startIfEnabled(this)
                            result.success(true)
                        } else if (pendingVpnResult != null) {
                            result.success(false)
                        } else {
                            // Android тирезаи «NIGOH Family мехоҳад VPN созад»-ро нишон медиҳад.
                            pendingVpnResult = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(consent, VPN_REQUEST_CODE)
                        }
                    }
                    "getLocalPinStatus" -> result.success(PinSecurity.hasPin(this))
                    "verifyLocalPin" -> {
                        val pin = call.argument<String>("pin") ?: ""
                        result.success(PinSecurity.verify(this, pin).allowed)
                    }
                    "setLocalPin" -> {
                        val currentPin = call.argument<String>("currentPin") ?: ""
                        val newPin = call.argument<String>("newPin") ?: ""
                        if (!Regex("^\\d{4}$").matches(newPin)) {
                            result.success(mapOf("ok" to false, "error" to "invalid_new_pin"))
                        } else if (PinSecurity.hasPin(this) &&
                            !PinSecurity.verify(this, currentPin).allowed
                        ) {
                            result.success(mapOf("ok" to false, "error" to "wrong_current_pin"))
                        } else {
                            val saved = PinSecurity.savePin(this, newPin)
                            result.success(
                                mapOf(
                                    "ok" to saved,
                                    "hasPin" to saved,
                                    "error" to if (saved) null else "storage_error",
                                )
                            )
                        }
                    }
                    "requestUninstallWithPin" -> {
                        val pin = call.argument<String>("pin") ?: ""
                        if (!PinSecurity.hasPin(this)) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "error" to "no_pin",
                                    "remainingSeconds" to 0L,
                                )
                            )
                        } else {
                            val verification = PinSecurity.verify(this, pin)
                            if (!verification.allowed) {
                                result.success(
                                    mapOf(
                                        "ok" to false,
                                        "error" to (verification.error ?: "wrong_pin"),
                                        "remainingSeconds" to verification.remainingSeconds,
                                    )
                                )
                            } else {
                                uninstallWithParentPin()
                                result.success(mapOf("ok" to true))
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        /** StreamHandler-и тағйири package-ҳоро сабт ва ҳангоми қатъ receiver-ро хориҷ мекунад. */
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, packageEventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                /** Receiver-и package-ро сабт карда, EventSink-ро барои event-ҳо нигоҳ медорад. */
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    packageEventSink = events
                    if (packageReceiverRegistered) return
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_PACKAGE_ADDED)
                        addAction(Intent.ACTION_PACKAGE_REMOVED)
                        addAction(Intent.ACTION_PACKAGE_REPLACED)
                        addDataScheme("package")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(packageReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    } else {
                        @Suppress("DEPRECATION")
                        registerReceiver(packageReceiver, filter)
                    }
                    packageReceiverRegistered = true
                }

                /** Stream-и package-ро қатъ карда, receiver-ро хориҷ мекунад. */
                override fun onCancel(arguments: Any?) {
                    packageEventSink = null
                    unregisterPackageReceiver()
                }
            })
    }

    /** Агар receiver сабт бошад, шунидани тағйири package-ҳоро қатъ мекунад. */
    private fun unregisterPackageReceiver() {
        if (packageReceiverRegistered) {
            unregisterReceiver(packageReceiver)
            packageReceiverRegistered = false
        }
    }

    /** Барномаҳои launcher-ро берун аз main thread хонда, ба Dart бармегардонад. */
    private fun getInstalledAppsAsync(result: MethodChannel.Result) {
        activityScope.launch {
            val appsResult = withContext(Dispatchers.IO) {
                runCatching { installedLauncherApps() }
            }
            appsResult.fold(
                onSuccess = result::success,
                onFailure = {
                    result.error(
                        "installed_apps_unavailable",
                        "Installed apps could not be read safely",
                        null,
                    )
                },
            )
        }
    }

    /**
     * Барномаҳои launcher-ро бо ном, package, нишони system ва icon-и 48 px ҷамъ мекунад.
     */
    private fun installedLauncherApps(): List<Map<String, Any>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                android.content.pm.PackageManager.ResolveInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }
        return resolved
            .distinctBy { it.activityInfo.packageName }
            .filter { it.activityInfo.packageName != packageName }
            .map {
                val appInfo = it.activityInfo.applicationInfo
                mapOf(
                    "packageName" to it.activityInfo.packageName,
                    "name" to it.loadLabel(packageManager).toString(),
                    "appName" to it.loadLabel(packageManager).toString(),
                    "system" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "iconBase64" to drawableToBase64(appInfo.loadIcon(packageManager))
                )
            }
            .sortedBy { (it["name"] as String).lowercase() }
    }

    /** Icon-и барномаро ба PNG-и 48 px ва Base64 табдил медиҳад. */
    private fun drawableToBase64(drawable: Drawable): String {
        val size = 48
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        return ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
        }.also { bitmap.recycle() }
    }

    /** Дақиқаҳои воқеан foreground-ро аз ҳисобкунаки NIGOH бармегардонад. */
    private fun todayUsageStats(): List<Map<String, Any>> {
        val prefs = getSharedPreferences(AppBlockMonitorService.PREFS_NAME, MODE_PRIVATE)
        val today = SimpleDateFormat(AppBlockMonitorService.DATE_FORMAT, Locale.US)
            .format(System.currentTimeMillis())
        if (prefs.getString(AppBlockMonitorService.USAGE_DATE_KEY, null) != today) return emptyList()
        val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val lastUsedByPackage = runCatching {
            manager.queryAndAggregateUsageStats(
                calendar.timeInMillis,
                System.currentTimeMillis()
            ).mapValues { it.value.lastTimeUsed }
        }.getOrDefault(emptyMap())
        return prefs.all.entries
            .asSequence()
            .filter { it.key.startsWith(AppBlockMonitorService.USAGE_SECONDS_PREFIX) }
            .mapNotNull { entry ->
                val appPackage = entry.key.removePrefix(AppBlockMonitorService.USAGE_SECONDS_PREFIX)
                val seconds = entry.value as? Long ?: return@mapNotNull null
                if (appPackage.isBlank() || appPackage == packageName || seconds <= 0L) {
                    return@mapNotNull null
                }
                mapOf(
                    "packageName" to appPackage,
                    "minutes" to (seconds / 60L).toInt().coerceIn(0, 1440),
                    "lastUsedAt" to (lastUsedByPackage[appPackage] ?: 0L),
                )
            }
            .toList()
    }

    /** map ва list-и қоидаҳои Dart-ро барои blocker ба JSON табдил медиҳад. */
    private fun jsonForRules(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> {
            val objectValue = JSONObject()
            value.forEach { (key, nested) ->
                if (key != null) objectValue.put(key.toString(), jsonForRules(nested))
            }
            objectValue
        }
        is Iterable<*> -> {
            val arrayValue = JSONArray()
            value.forEach { arrayValue.put(jsonForRules(it)) }
            arrayValue
        }
        else -> value
    }

    /** Дода шудани usage access, overlay ва Accessibility-ро якҷо месанҷад. */
    private fun isBlockServiceEnabled(): Boolean {
        return AppBlockMonitorService.hasUsageAccess(this) &&
            Settings.canDrawOverlays(this) &&
            AppBlockMonitorService.isAccessibilityEnabled(this)
    }

    /**
     * Танзими иҷозати навбатии норасоро мекушояд ё баъди пурра будан хидматро оғоз мекунад.
     */
    private fun openNextProtectionSetting() {
        if (!AppBlockMonitorService.hasUsageAccess(this)) {
            openUsageAccessSettings()
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
            return
        }
        if (!AppBlockMonitorService.isAccessibilityEnabled(this)) {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            return
        }
        startProtectionService()
    }

    /** Танзими usage access-и барномаро бо fallback-и экрани умумӣ мекушояд. */
    private fun openUsageAccessSettings() {
        val appIntent = Intent(
            Settings.ACTION_USAGE_ACCESS_SETTINGS,
            Uri.parse("package:$packageName")
        )
        try {
            startActivity(appIntent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
    }

    /**
     * Вазъи ҳамаи иҷозатҳо ва маълумоти дастгоҳро барои экранҳои Flutter ҷамъ мекунад.
     */
    private fun protectionStatus(): Map<String, Any> {
        /** Дода шудани иҷозати Android-ро месанҷад. */
        fun granted(permission: String) =
            checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val location = granted(android.Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(android.Manifest.permission.ACCESS_COARSE_LOCATION)
        val locationManager = getSystemService(LOCATION_SERVICE) as android.location.LocationManager
        val gps = runCatching {
            locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) ||
                locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)
        }.getOrDefault(false)
        return mapOf(
            "usage" to AppBlockMonitorService.hasUsageAccess(this),
            "overlay" to Settings.canDrawOverlays(this),
            "accessibility" to AppBlockMonitorService.isAccessibilityEnabled(this),
            "deviceAdmin" to AppBlockMonitorService.isDeviceAdminEnabled(this),
            "location" to location,
            "backgroundLocation" to (location && (Build.VERSION.SDK_INT < 29 ||
                granted(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION))),
            "gps" to gps,
            "camera" to granted(android.Manifest.permission.CAMERA),
            "notifications" to androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled(),
            "androidVersion" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "sdk" to Build.VERSION.SDK_INT
        )
    }

    /** Monitor-и бастани барномаҳоро ҳамчун foreground service оғоз мекунад. */
    private fun startProtectionService() {
        val intent = Intent(this, AppBlockMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    /** Ҳангоми сохтани Activity муҳофизатро оғоз ва intent-и огоҳиномаро сабт мекунад. */
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (isBlockServiceEnabled()) startProtectionService()
        if (savedInstanceState == null) handleNotifyIntent(intent, deliver = false)
    }

    /** Intent-и нави огоҳиномаро ҳангоми кори барнома ба Flutter мерасонад. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotifyIntent(intent, deliver = true)
    }

    // Пули огоҳиномаҳо байни Android ва Flutter.

    /**
     * Channel-и tj.nigoh/notify-ро барои хидмат, иҷозат, full-screen ва занг танзим мекунад.
     */
    private fun configureNotifyChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tj.nigoh/notify")
        notifyChannel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        NotifyService.start(this, call.argument<String>("baseUrl"))
                        result.success(true)
                    }
                    "stop" -> {
                        NotifyService.stop(this)
                        result.success(true)
                    }
                    "permissionStatus" -> result.success(notifyPermissionStatus())
                    "openFullScreenSettings" -> {
                        result.success(openFullScreenSettings())
                    }
                    "getLaunchAction" -> {
                        result.success(pendingLaunch)
                        pendingLaunch = null
                    }
                    "stopRinging" -> {
                        NotifyService.instance?.stopRinging()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("notify_failed", e.message ?: UiStrings.notifyFailed(this), null)
            }
        }
    }

    /** Иҷозати огоҳинома ва full-screen intent-ро месанҷад. */
    private fun notifyPermissionStatus(): Map<String, Boolean> {
        val enabled = androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled()
        val fullScreen = if (Build.VERSION.SDK_INT >= 34) {
            getSystemService(android.app.NotificationManager::class.java).canUseFullScreenIntent()
        } else {
            true
        }
        return mapOf("notifications" to enabled, "fullScreen" to fullScreen)
    }

    /**
     * Танзими full-screen intent ё экрани наздиктарини огоҳиномаро мекушояд.
     */
    private fun openFullScreenSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= 34) {
            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        return try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        }
    }

    /** Extra-ҳои NotifyService-ро хонда, ба Dart мерасонад ё муваққатан нигоҳ медорад. */
    private fun handleNotifyIntent(intent: Intent?, deliver: Boolean) {
        val kind = intent?.getStringExtra(NotifyService.EXTRA_KIND) ?: return
        val childId = intent.getIntExtra(NotifyService.EXTRA_CHILD_ID, -1)
        val callId = intent.getIntExtra(NotifyService.EXTRA_CALL_ID, -1)
        val accept = intent.getBooleanExtra(NotifyService.EXTRA_ACCEPT, false)
        val fullScreen = intent.getBooleanExtra(NotifyService.EXTRA_FULL_SCREEN, false)
        val action = mapOf<String, Any?>(
            "kind" to kind,
            "childId" to childId.takeIf { it >= 0 },
            "callId" to callId.takeIf { it >= 0 },
            "peerName" to intent.getStringExtra(NotifyService.EXTRA_PEER_NAME),
            "acceptCall" to accept,
            "fullScreen" to fullScreen,
        )
        // Extra пок мешавад, то recreate ё rotation онро такрор накунад.
        intent.removeExtra(NotifyService.EXTRA_KIND)

        // Занг ё SOS метавонад аз service ва full-screen intent ду бор ояд; танҳо якумаш расонида мешавад.
        if (fullScreen && (kind == "call" || kind == "sos")) {
            val key = if (kind == "call") "call:$callId" else "sos:$childId"
            val now = android.os.SystemClock.elapsedRealtime()
            val window = if (kind == "call") 120_000L else 15_000L
            val seen = recentAutoLaunches[key]
            recentAutoLaunches.entries.removeAll { now - it.value > 120_000L }
            if (seen != null && now - seen < window) return
            recentAutoLaunches[key] = now
        }

        if (kind == "call" || kind == "sos") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        }
        // Кушодани корти SOS бо пахш alarm-ро хомӯш мекунад.
        if (kind == "sos" && !fullScreen) NotifyService.instance?.stopAlarm()
        // Баъди «Қабул» экрани занг ringtone ва корти огоҳиномаро мегирад.
        if (kind == "call" && accept) NotifyService.instance?.stopCallRinging(callId.takeIf { it >= 0 })

        val channel = notifyChannel
        if (deliver && channel != null) {
            channel.invokeMethod("launch", action)
        } else {
            pendingLaunch = action
        }
    }

    /**
     * Баъди бозгашт аз Settings муҳофизат ва навсозии мунтазири иҷозати насбро идома медиҳад.
     */
    override fun onResume() {
        super.onResume()
        // Иҷозатҳои махсус берун аз барнома дода мешаванд; monitor баъди бозгашт идома меёбад.
        if (isBlockServiceEnabled()) runCatching { startProtectionService() }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            pendingUpdateUrl != null && packageManager.canRequestPackageInstalls()
        ) {
            val url = pendingUpdateUrl!!
            pendingUpdateUrl = null
            pendingUpdateVersion = null
            AppUpdater.start(this, url)
        }
    }

    /** Кори background-ро қатъ ва package receiver-ро хориҷ мекунад. */
    override fun onDestroy() {
        activityScope.cancel()
        unregisterPackageReceiver()
        super.onDestroy()
    }

    /** version code-и насбшудаи барномаро мегирад. */
    private fun versionCode(): Long {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    /** version name-и насбшудаи барномаро мегирад. */
    private fun versionName(): String {
        return packageManager.getPackageInfo(packageName, 0).versionName ?: "0.0.0"
    }

    /**
     * Версияи охиринро аз сервер гирифта, бо URL-и мутлақи боргирӣ ба Dart медиҳад.
     */
    private fun checkForUpdate(baseUrl: String, result: MethodChannel.Result) {
        activityScope.launch {
            try {
                val map = withContext(Dispatchers.IO) {
                    val endpoint = URL("$baseUrl/api/mobile/version?current_version_code=${versionCode()}")
                    val connection = endpoint.openConnection() as HttpURLConnection
                    try {
                        connection.connectTimeout = 8_000
                        connection.readTimeout = 8_000
                        connection.requestMethod = "GET"
                        connection.setRequestProperty("Accept", "application/json")
                        val status = connection.responseCode
                        if (status !in 200..299) throw IllegalStateException("Update server returned $status")
                        val payload = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                        val update = jsonObjectToMap(payload)
                        update["versionCode"] = payload.optLong("version_code", 0)
                        update["versionName"] = payload.optString("version", "0.0.0")
                        update["notes"] = payload.optString("release_notes", "")
                        val downloadUrl = payload.optString("download_url", "")
                        update["downloadUrl"] = if (downloadUrl.startsWith("http://") || downloadUrl.startsWith("https://")) {
                            downloadUrl
                        } else {
                            URL(URL("$baseUrl/"), downloadUrl.removePrefix("/")).toString()
                        }
                        update["current_version_code"] = versionCode()
                        update["current_version_name"] = versionName()
                        update
                    } finally {
                        connection.disconnect()
                    }
                }
                result.success(map)
            } catch (error: Exception) {
                result.error("update_check_failed", error.message ?: "Update check failed", null)
            }
        }
    }

    /**
     * Навсозии APK-ро оғоз карда, агар лозим бошад иҷозати unknown apps мепурсад.
     */
    private fun startUpdate(url: String, version: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingUpdateUrl = url
            pendingUpdateVersion = version
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
            result.success("install_permission_required")
            return
        }
        AppUpdater.start(this, url)
        result.success("download_started")
    }


    /**
     * Баъди санҷиши PIN ҳифзи device admin-ро гирифта, равзанаи uninstall-ро мекушояд.
     */
    private fun uninstallWithParentPin() {
        val policy = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admin = ComponentName(this, TamperDeviceAdminReceiver::class.java)
        if (policy.isAdminActive(admin)) policy.removeActiveAdmin(admin)
        android.os.Handler(mainLooper).postDelayed({
            startActivity(Intent(Intent.ACTION_UNINSTALL_PACKAGE).apply {
                data = Uri.parse("package:$packageName")
                putExtra(Intent.EXTRA_RETURN_RESULT, true)
            })
        }, 350L)
    }

    /** JSONObject-ро барои Flutter channel ба map табдил медиҳад. */
    private fun jsonObjectToMap(json: JSONObject): HashMap<String, Any?> {
        val map = hashMapOf<String, Any?>()
        json.keys().forEach { key -> map[key] = jsonValue(json.get(key)) }
        return map
    }

    /** Қимати JSON-ро ба навъҳои мувофиқи platform channel табдил медиҳад. */
    private fun jsonValue(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
        else -> value
    }
}
