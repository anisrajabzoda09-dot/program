// Файл: NIGOH-ро аз хомӯш ё нест кардан бе PIN-и волидайн муҳофизат мекунад.

package tj.nigoh.nigoh_family_parent

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Ҳангоми кӯшиши бекор кардани ҳуқуқи device admin экрани PIN-ро мекушояд.
 */
class TamperDeviceAdminReceiver : DeviceAdminReceiver() {
    /** Хомӯш кардани device admin-ро боздошта, санҷиши PIN-и волидайнро мекушояд. */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        runCatching {
            context.startActivity(Intent(context, PinVerificationActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            })
        }
        return UiStrings.pinRequired(context)
    }
}
