// Файл: баъди бозоғозии телефон хидмати огоҳинома ва назорати барномаҳоро барқарор мекунад.

package tj.nigoh.nigoh_family_parent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/**
 * Хидматҳои background-и NIGOH-ро баъди boot, бо дарназардошти иҷозатҳо, оғоз мекунад.
 */
class ProtectionBootReceiver : BroadcastReceiver() {
    /** Пас аз boot огоҳиномаҳоро барқарор ва ҳангоми мавҷуд будани иҷозатҳо blocker-ро оғоз мекунад. */
    override fun onReceive(context: Context, intent: Intent?) {
        // Огоҳиномаҳо аз муҳофизати барнома ҷудоанд ва баъди воридшавӣ барқарор мешаванд.
        NotifyService.startIfSignedIn(context)
        // Филтри сайтҳо пас аз хидмати foreground оғоз мешавад (Android иҷозат медиҳад).
        WebFilterVpnService.startIfEnabled(context)
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
