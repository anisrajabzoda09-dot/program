package tj.nigoh.nigoh_family_parent

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class TamperDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        runCatching {
            context.startActivity(Intent(context, PinVerificationActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            })
        }
        return "Барои ғайрифаъол ва нест кардани NIGOH Family ворид намудани рамзи PIN-и волидайн ҳатмист."
    }
}
