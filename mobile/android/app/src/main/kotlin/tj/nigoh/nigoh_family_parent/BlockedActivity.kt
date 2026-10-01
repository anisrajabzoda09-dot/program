package tj.nigoh.nigoh_family_parent

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class BlockedActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val blockedPackage = intent.getStringExtra("blocked_package") ?: ""
        val label = runCatching {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(blockedPackage, 0)
            ).toString()
        }.getOrDefault(blockedPackage)

        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        fun rounded(color: Int, radius: Int = 18, stroke: Int? = null): GradientDrawable =
            GradientDrawable().apply {
                setColor(color)
                cornerRadius = dp(radius).toFloat()
                if (stroke != null) setStroke(dp(1), stroke)
            }
        fun text(value: String, size: Float, color: Int, bold: Boolean = false): TextView =
            TextView(this).apply {
                this.text = value
                textSize = size
                setTextColor(color)
                gravity = Gravity.CENTER
                if (bold) typeface = Typeface.DEFAULT_BOLD
            }
        fun addSpace(parent: LinearLayout, height: Int) {
            parent.addView(View(this), LinearLayout.LayoutParams(1, dp(height)))
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(18), dp(18), dp(22))
            setBackgroundColor(Color.rgb(7, 13, 24))
        }
        val scroll = ScrollView(this).apply {
            addView(root, ViewGroup.LayoutParams(-1, -2))
            setBackgroundColor(Color.rgb(7, 13, 24))
        }

        val header = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = rounded(Color.rgb(17, 28, 48), 16, Color.rgb(34, 51, 84))
        }
        header.addView(text("‹", 34f, Color.rgb(0, 229, 255), true),
            LinearLayout.LayoutParams(dp(34), dp(42)))
        val headerTitle = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        headerTitle.addView(text("🛡  Emergency Lock", 17f, Color.WHITE, true))
        headerTitle.addView(text("NIGOH SHIELD • НАЗОРАТИ ВОЛИДАЙН", 10f, Color.rgb(0, 229, 255), true))
        header.addView(headerTitle, LinearLayout.LayoutParams(0, -2, 1f))
        header.addView(text("👨", 28f, Color.WHITE), LinearLayout.LayoutParams(dp(42), dp(42)))
        root.addView(header)
        addSpace(root, 24)

        val lock = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        lock.addView(text("🔒", 64f, Color.rgb(230, 57, 70), true),
            LinearLayout.LayoutParams(-1, dp(90)))
        lock.addView(text("Ин барнома аз ҷониби волидайн маҳкам шудааст", 23f, Color.WHITE, true))
        addSpace(lock, 8)
        lock.addView(text("This application is restricted by parental controls", 13f, Color.rgb(141, 153, 174)))
        root.addView(lock)
        addSpace(root, 20)

        val summary = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(15), dp(16), dp(15))
            background = rounded(Color.rgb(22, 34, 56), 18, Color.rgb(34, 51, 84))
        }
        val appRow = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        appRow.addView(text("▶", 30f, Color.rgb(0, 229, 255), true),
            LinearLayout.LayoutParams(dp(48), dp(48)))
        val appInfo = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        appInfo.addView(text(label, 18f, Color.WHITE, true))
        appInfo.addView(text("Фароғат ва наворҳо", 12f, Color.rgb(141, 153, 174)))
        appRow.addView(appInfo, LinearLayout.LayoutParams(0, -2, 1f))
        appRow.addView(text("МАҲКАМ", 11f, Color.rgb(230, 57, 70), true),
            LinearLayout.LayoutParams(-2, -2))
        summary.addView(appRow)
        addSpace(summary, 14)
        summary.addView(text("●  Лимити рӯзона пур шуд  |  1 соат 30 дақ / 1 соат 30 дақ", 12f, Color.rgb(24, 144, 255)))
        addSpace(summary, 8)
        summary.addView(text("●  Ҳолати дарсӣ фаъол аст  |  16:00 — 18:00", 12f, Color.rgb(6, 214, 160)))
        root.addView(summary)
        addSpace(root, 20)

        val countdown = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(14), dp(16), dp(14))
            background = rounded(Color.rgb(17, 28, 48), 16, Color.rgb(34, 51, 84))
        }
        countdown.addView(text("Кушодашавии навбатӣ пас аз:", 12f, Color.rgb(141, 153, 174)))
        addSpace(countdown, 5)
        countdown.addView(text("01 : 24 : 58", 31f, Color.rgb(0, 229, 255), true))
        countdown.addView(text("Пагоҳ соати 08:00", 12f, Color.rgb(141, 153, 174)))
        root.addView(countdown)
        addSpace(root, 18)

        val home = Button(this).apply {
            text = "⌂  Бозгашт ба экрани асосӣ"
            textSize = 15f
            setTextColor(Color.rgb(7, 13, 24))
            typeface = Typeface.DEFAULT_BOLD
            background = rounded(Color.rgb(0, 229, 255), 14)
            setOnClickListener { finishAndRemoveTask() }
        }
        root.addView(home, LinearLayout.LayoutParams(-1, dp(54)))
        addSpace(root, 10)
        val request = Button(this).apply {
            text = "Дархости вақти иловагӣ (+15 дақ)"
            textSize = 14f
            setTextColor(Color.WHITE)
            background = rounded(Color.rgb(22, 34, 56), 14, Color.rgb(34, 51, 84))
            setOnClickListener { finishAndRemoveTask() }
        }
        root.addView(request, LinearLayout.LayoutParams(-1, dp(52)))
        addSpace(root, 8)
        root.addView(text("Пайём барои тасдиқ ба волидайн фиристода мешавад", 11f, Color.rgb(141, 153, 174)))
        addSpace(root, 20)
        root.addView(text("☎  Зангҳои таъҷилӣ ҳамеша дастрасанд (SOS)", 12f, Color.rgb(230, 57, 70), true))
        root.addView(text("Хидмати 112 ё занг ба падар ва модар маҳдуд намешавад", 11f, Color.rgb(141, 153, 174)))

        setContentView(scroll)
    }
}
