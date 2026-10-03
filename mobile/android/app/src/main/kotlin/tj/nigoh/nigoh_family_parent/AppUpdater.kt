// Файл: навсозии дохилии барнома — APK-ро боргирӣ ва санҷида,
// тавассути PackageInstaller насб мекунад.

package tj.nigoh.nigoh_family_parent

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Навсозиро бе нест кардани барнома иҷро мекунад: APK-ро бор гирифта, package,
 * имзо ва версияро месанҷад. Маълумот, воридшавӣ ва иҷозатҳо нигоҳ дошта мешаванд.
 */
object AppUpdater {
    @Volatile var listener: ((Map<String, Any?>) -> Unit)? = null
    @Volatile private var running = false

    private val main = Handler(Looper.getMainLooper())

    /** Вазъ ва пешрафти навсозиро дар main thread ба Flutter мефиристад. */
    private fun emit(state: String, progress: Double? = null, message: String? = null) {
        val event = mapOf("state" to state, "progress" to progress, "message" to message)
        main.post { listener?.invoke(event) }
        if (state == "done" || state == "error") running = false
    }

    /** Боргирӣ, санҷиш ва насбро дар background thread оғоз мекунад. */
    fun start(context: Context, url: String) {
        if (running) return
        running = true
        val app = context.applicationContext
        Thread {
            try {
                val apk = download(app, url)
                emit("verifying", 1.0)
                verify(app, apk)
                emit("installing", 1.0)
                install(app, apk)
            } catch (error: Exception) {
                emit("error", message = error.message ?: UiStrings.updateNotInstalled(app))
            }
        }.start()
    }

    /** APK-ро бо пайгирии redirect ба cache бор гирифта, пешрафтро хабар медиҳад. */
    private fun download(context: Context, url: String): File {
        val dir = File(context.cacheDir, "updates").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val target = File(dir, "nigoh-update.apk")
        var connection = URL(url).openConnection() as HttpURLConnection
        var redirects = 0
        while (true) {
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            connection.instanceFollowRedirects = true
            val code = connection.responseCode
            if (code in 300..399 && redirects < 5) {
                val next = connection.getHeaderField("Location") ?: break
                connection.disconnect()
                connection = URL(URL(url), next).openConnection() as HttpURLConnection
                redirects++
                continue
            }
            if (code !in 200..299) throw IllegalStateException(UiStrings.updateServerError(context, code))
            break
        }
        val total = connection.contentLengthLong.takeIf { it > 0 }
        connection.inputStream.use { input ->
            target.outputStream().use { output ->
                val buffer = ByteArray(64 * 1024)
                var done = 0L
                var lastReported = -1
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    done += read
                    if (total != null) {
                        val percent = (done * 100 / total).toInt()
                        if (percent != lastReported) {
                            lastReported = percent
                            emit("downloading", done.toDouble() / total)
                        }
                    }
                }
            }
        }
        connection.disconnect()
        if (target.length() < 1_000_000) throw IllegalStateException(UiStrings.updateIncomplete(context))
        return target
    }

    /** SHA-256-и сертификатҳои имзои [info]-ро бармегардонад. */
    @Suppress("DEPRECATION")
    private fun signatureDigests(info: PackageInfo?): Set<String> {
        if (info == null) return emptySet()
        val raw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signing = info.signingInfo ?: return emptySet()
            if (signing.hasMultipleSigners()) signing.apkContentsSigners else signing.signingCertificateHistory
        } else {
            info.signatures
        } ?: return emptySet()
        val sha = MessageDigest.getInstance("SHA-256")
        return raw.map { sig -> sha.digest(sig.toByteArray()).joinToString("") { "%02x".format(it) } }.toSet()
    }

    /**
     * APK-и барномаи дигар, имзои бегона ё версияи кӯҳнаро рад мекунад.
     */
    @Suppress("DEPRECATION")
    private fun verify(context: Context, apk: File) {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val archive = pm.getPackageArchiveInfo(apk.absolutePath, flags)
            ?: throw IllegalStateException(UiStrings.updateBroken(context))
        if (archive.packageName != context.packageName) {
            throw SecurityException(UiStrings.updateWrongPackage(context))
        }
        val installed = pm.getPackageInfo(context.packageName, flags)
        val newCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) archive.longVersionCode else archive.versionCode.toLong()
        val oldCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) installed.longVersionCode else installed.versionCode.toLong()
        if (newCode <= oldCode) throw IllegalStateException(UiStrings.updateAlreadyLatest(context))
        val mine = signatureDigests(installed)
        val theirs = signatureDigests(archive)
        if (mine.isEmpty() || theirs.isEmpty() || mine.intersect(theirs).isEmpty()) {
            throw SecurityException(UiStrings.updateBadSignature(context))
        }
    }

    /** APK-ро дар session ба PackageInstaller дода, насбро тасдиқ мекунад. */
    private fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Дар Android 12+ баъди насби пешина дархости иловагӣ лозим нест.
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("nigoh.apk", 0, apk.length()).use { output ->
                    input.copyTo(output, 64 * 1024)
                    session.fsync(output)
                }
            }
            val intent = Intent(context, UpdateStatusReceiver::class.java)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
    }

    /** Натиҷаи PackageInstaller-ро коркард карда, ба Flutter мерасонад. */
    internal fun onStatus(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                }
                emit("installing", 1.0, UiStrings.updateConfirmPrompt(context))
            }
            PackageInstaller.STATUS_SUCCESS -> emit("done", 1.0)
            PackageInstaller.STATUS_FAILURE_ABORTED -> emit("error", message = UiStrings.updateCancelled(context))
            else -> emit(
                "error",
                message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: UiStrings.updateNotInstalled(context),
            )
        }
    }
}

/** Натиҷаи session-и PackageInstaller-ро ба [AppUpdater] месупорад. */
class UpdateStatusReceiver : BroadcastReceiver() {
    /** Broadcast-и натиҷаи насбро қабул мекунад. */
    override fun onReceive(context: Context, intent: Intent) = AppUpdater.onStatus(context, intent)
}
