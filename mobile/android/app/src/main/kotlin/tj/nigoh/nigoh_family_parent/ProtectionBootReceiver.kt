package tj.nigoh.nigoh_family_parent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

class ProtectionBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Notifications (independent of app protection): resume when signed in.
        NotifyService.startIfSignedIn(context)
        if (!AppBlockMonitorService.hasUsageAccess(context) ||
            !Settings.canDrawOverlays(context)) return
        val service = Intent(context, AppBlockMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(service)
        } else {
            context.startService(service)
        }
    }
}
