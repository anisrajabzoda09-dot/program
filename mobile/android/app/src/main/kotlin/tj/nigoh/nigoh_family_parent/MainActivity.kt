package tj.nigoh.nigoh_family_parent

import android.app.AppOpsManager
import android.app.DownloadManager
import android.app.usage.UsageStatsManager
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val channelName = "tj.nigoh/update"
    private val deviceControlChannelName = "tj.nigoh/device_control"
    private val packageEventsChannelName = "tj.nigoh/package_events"
    private var updateDownloadId: Long? = null
    private var pendingUpdateUrl: String? = null
    private var pendingUpdateVersion: String? = null
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var packageEventSink: EventChannel.EventSink? = null
    private var packageReceiverRegistered = false
    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_PACKAGE_ADDED,
                Intent.ACTION_PACKAGE_REMOVED,
                Intent.ACTION_PACKAGE_REPLACED ->
                    packageEventSink?.success(intent.data?.schemeSpecificPart ?: "")
            }
        }
    }
    private val updateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            if (id != updateDownloadId) return
            val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
            val cursor = manager.query(DownloadManager.Query().setFilterById(id))
            cursor.use {
                if (!it.moveToFirst()) return
                val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                if (status != DownloadManager.STATUS_SUCCESSFUL) return
            }
            val apkUri = manager.getUriForDownloadedFile(id) ?: return
            startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(apkUri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                            // Persist the complete snapshot before starting the monitor.
                            .putString(AppBlockMonitorService.RULES_KEY, rules.toString())
                            .putStringSet(AppBlockMonitorService.BLOCKED_KEY, blocked)
                            .apply()
                        if (isBlockServiceEnabled()) startProtectionService()
                        result.success(true)
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
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, packageEventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
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

                override fun onCancel(arguments: Any?) {
                    packageEventSink = null
                    unregisterPackageReceiver()
                }
            })
    }

    private fun unregisterPackageReceiver() {
        if (packageReceiverRegistered) {
            unregisterReceiver(packageReceiver)
            packageReceiverRegistered = false
        }
    }

    private fun getInstalledAppsAsync(result: MethodChannel.Result) {
        activityScope.launch {
            val apps = withContext(Dispatchers.IO) {
                runCatching { installedLauncherApps() }.getOrDefault(emptyList())
            }
            result.success(apps)
        }
    }

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

    private fun todayUsageStats(): List<Map<String, Any>> {
        val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        // queryUsageStats returns several overlapping buckets per package;
        // the aggregated call gives one entry per app for today.
        val stats = runCatching {
            manager.queryAndAggregateUsageStats(
                calendar.timeInMillis,
                System.currentTimeMillis()
            )
        }.getOrNull() ?: return emptyList()
        return stats.values
            .filter { it.totalTimeInForeground > 0L && it.packageName != packageName }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "minutes" to (it.totalTimeInForeground / 60000L).toInt().coerceIn(0, 1440),
                    "lastUsedAt" to it.lastTimeUsed
                )
            }
    }

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

    private fun isBlockServiceEnabled(): Boolean {
        return AppBlockMonitorService.hasUsageAccess(this) &&
            Settings.canDrawOverlays(this) &&
            AppBlockMonitorService.isAccessibilityEnabled(this)
    }

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

    private fun protectionStatus(): Map<String, Any> {
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

    private fun startProtectionService() {
        val intent = Intent(this, AppBlockMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(updateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(updateReceiver, filter)
        }
        if (isBlockServiceEnabled()) startProtectionService()
    }

    override fun onResume() {
        super.onResume()
        // Special permissions are granted outside the app. Resume monitoring
        // as soon as the user returns, without requiring an app restart.
        if (isBlockServiceEnabled()) runCatching { startProtectionService() }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            pendingUpdateUrl != null && packageManager.canRequestPackageInstalls()
        ) {
            val url = pendingUpdateUrl!!
            val version = pendingUpdateVersion ?: "latest"
            pendingUpdateUrl = null
            pendingUpdateVersion = null
            enqueueUpdate(url, version)
        }
    }

    override fun onDestroy() {
        activityScope.cancel()
        unregisterPackageReceiver()
        try {
            unregisterReceiver(updateReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun versionCode(): Long {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun versionName(): String {
        return packageManager.getPackageInfo(packageName, 0).versionName ?: "0.0.0"
    }

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
        enqueueUpdate(url, version)
        result.success("download_started")
    }

    private fun enqueueUpdate(url: String, version: String) {
        val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val safeVersion = version.replace(Regex("[^A-Za-z0-9._-]"), "-")
        val fileName = "NIGOH-Family-$safeVersion-${System.currentTimeMillis()}.apk"
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("NIGOH Family $version")
            .setDescription("Навсозӣ зеркашӣ мешавад")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, fileName)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
        updateDownloadId = manager.enqueue(request)
    }

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

    private fun jsonObjectToMap(json: JSONObject): HashMap<String, Any?> {
        val map = hashMapOf<String, Any?>()
        json.keys().forEach { key -> map[key] = jsonValue(json.get(key)) }
        return map
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
        else -> value
    }
}
