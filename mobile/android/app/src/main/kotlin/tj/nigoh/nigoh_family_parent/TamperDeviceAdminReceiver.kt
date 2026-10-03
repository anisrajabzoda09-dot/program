// Device-admin receiver that protects NIGOH from being disabled or removed
// without the parent PIN.

package tj.nigoh.nigoh_family_parent

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Device-admin hook: when someone tries to disable NIGOH's admin rights it
 * opens the parent-PIN screen and shows a warning.
 */
class TamperDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        runCatching {
            context.startActivity(Intent(context, PinVerificationActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            })
        }
        return UiStrings.pinRequired(context)
    }
}
