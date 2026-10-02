package tj.nigoh.nigoh_family_parent

import android.accessibilityservice.AccessibilityService
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

/** Event-driven foreground detection for the linked child profile. */
class NIGOHAccessibilityService : AccessibilityService() {
    private var lastPackage: String? = null
    private var lastDecisionAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) return

        val target = event.packageName?.toString() ?: return
        if (target == packageName || target in SAFE_PACKAGES) return

        val now = SystemClock.elapsedRealtime()
        if (target == lastPackage && now - lastDecisionAt < DECISION_DEBOUNCE_MS) return
        lastPackage = target
        lastDecisionAt = now

        val prefs = getSharedPreferences(AppBlockMonitorService.PREFS_NAME, MODE_PRIVATE)
        val rule = findRule(prefs.getString(AppBlockMonitorService.RULES_KEY, null), target)
        val blocked = rule?.optBoolean("blocked", false) == true ||
            target in (prefs.getStringSet(AppBlockMonitorService.BLOCKED_KEY, emptySet()) ?: emptySet())
        val scheduleActive = rule?.optJSONObject("schedule")?.let(::isScheduleActive) == true
        val limit = rule?.optInt("dailyLimitMinutes", 0) ?: 0
        val usedSeconds = prefs.getLong("usage_seconds:$target", 0L)
        val limitExceeded = limit > 0 && usedSeconds >= limit * 60L

        val reason = when {
            blocked -> UiStrings.reasonBlocked(this)
            scheduleActive -> UiStrings.reasonSchedule(this)
            limitExceeded -> UiStrings.reasonLimit(this)
            else -> null
        } ?: return

        AppBlockMonitorService.requestOverlayFromAccessibility(this, target, reason)
    }

    override fun onInterrupt() = Unit

    private fun findRule(raw: String?, target: String): JSONObject? = runCatching {
        val rules = JSONArray(raw ?: return null)
        for (index in 0 until rules.length()) {
            val item = rules.optJSONObject(index) ?: continue
            if (item.optString("packageName") == target) return item
        }
        null
    }.getOrNull()

    private fun isScheduleActive(schedule: JSONObject): Boolean {
        if (!schedule.optBoolean("enabled", false)) return false
        val weekdays = schedule.optJSONArray("weekdays") ?: return false
        val now = Calendar.getInstance()
        val day = ((now.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
        val start = parseMinutes(schedule.optString("start", "16:00")) ?: return false
        val end = parseMinutes(schedule.optString("end", "18:00")) ?: return false
        val current = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        fun enabledOn(value: Int): Boolean = (0 until weekdays.length()).any {
            weekdays.optInt(it) == value
        }
        if (start <= end) return enabledOn(day) && current in start until end
        return if (current >= start) enabledOn(day)
        else enabledOn(if (day == 1) 7 else day - 1)
    }

    private fun parseMinutes(value: String): Int? {
        val parts = value.trim().split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        return if (hour in 0..23 && minute in 0..59) hour * 60 + minute else null
    }

    companion object {
        private const val DECISION_DEBOUNCE_MS = 250L
        private val SAFE_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.settings",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller",
        )
    }
}
