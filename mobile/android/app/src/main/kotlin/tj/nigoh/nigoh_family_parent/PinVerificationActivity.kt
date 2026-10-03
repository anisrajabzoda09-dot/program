// Файл: экрани санҷиши PIN-и волидайн барои ҳифзи NIGOH аз несткунӣ;
// баъди PIN-и дуруст ҳуқуқи device admin-ро мегирад ва uninstall-ро мекушояд.

package tj.nigoh.nigoh_family_parent

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.text.InputType

/**
 * Ҳангоми кӯшиши хомӯш ё нест кардани NIGOH PIN мепурсад; тугмаи Back онро намепӯшад.
 */
class PinVerificationActivity : Activity() {
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Формаи PIN, сатри хато ва тугмаи тасдиқро месозад. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFinishOnTouchOutside(false)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val density = resources.displayMetrics.density
        /** dp-ро барои зичии экран ба pixel табдил медиҳад. */
        fun dp(value: Int) = (value * density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(28), dp(28), dp(28))
            setBackgroundColor(Color.rgb(7, 13, 24))
        }
        root.addView(TextView(this).apply {
            text = "🛡"
            textSize = 58f
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, dp(82)))
        root.addView(TextView(this).apply {
            text = UiStrings.pinTitle(this@PinVerificationActivity)
            textSize = 25f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, dp(52)))
        root.addView(TextView(this).apply {
            text = UiStrings.pinRequired(this@PinVerificationActivity)
            textSize = 16f
            setTextColor(Color.rgb(220, 230, 242))
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(-1, dp(92)))
        val pin = EditText(this).apply {
            hint = UiStrings.pinHint4(this@PinVerificationActivity)
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            setTextColor(Color.WHITE)
            setHintTextColor(Color.rgb(150, 165, 185))
            gravity = Gravity.CENTER
            textSize = 22f
        }
        root.addView(pin, LinearLayout.LayoutParams(-1, dp(58)))
        val error = TextView(this).apply {
            setTextColor(Color.rgb(255, 120, 120))
            gravity = Gravity.CENTER
            textSize = 14f
        }
        root.addView(error, LinearLayout.LayoutParams(-1, dp(45)))
        root.addView(Button(this).apply {
            text = UiStrings.confirm(this@PinVerificationActivity)
            setOnClickListener { verify(pin.text.toString(), error) }
        }, LinearLayout.LayoutParams(-1, dp(54)))
        setContentView(root)
    }

    /**
     * PIN-ро месанҷад; ҳангоми муваффақият device admin-ро гирифта, uninstall-ро оғоз мекунад.
     */
    private fun verify(pin: String, error: TextView) {
        val result = PinSecurity.verify(this, pin)
        if (result.allowed) {
            val policy = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, TamperDeviceAdminReceiver::class.java)
            if (policy.isAdminActive(admin)) policy.removeActiveAdmin(admin)
            mainHandler.postDelayed({ launchUninstall() }, 350L)
        } else {
            error.text = if (result.error == "locked") {
                UiStrings.pinLocked(this, result.remainingSeconds)
            } else if (!PinSecurity.hasPin(this)) {
                UiStrings.pinNotSet(this)
            } else {
                UiStrings.pinWrong(this)
            }
        }
    }

    /** Равзанаи uninstall-и Android-ро мекушояд ва ин экранро мебандад. */
    private fun launchUninstall() {
        startActivity(Intent(Intent.ACTION_UNINSTALL_PACKAGE).apply {
            data = Uri.parse("package:$packageName")
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        })
        finish()
    }

    /** Барои пешгирии гузаштан аз муҳофизат амали Back-ро нодида мегирад. */
    override fun onBackPressed() {
        // Раванди муҳофизатшуда бо Back баста намешавад.
    }
}
