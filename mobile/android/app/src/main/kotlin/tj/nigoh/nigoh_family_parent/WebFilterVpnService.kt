// Файл: филтри сайтҳо дар телефони фарзанд — VpnService-и маҳаллӣ, ки танҳо дархостҳои DNS-ро
// мегирад ва ба сервери филтрдор мефиристад. Трафики дигар ба VPN намеравад ва аз телефон берун намешавад.

package tj.nigoh.nigoh_family_parent

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * VPN-и «танҳо DNS»: ба система суроғаи DNS-и дохилӣ (10.215.173.2) медиҳад ва танҳо роҳи
 * ҳамин суроғаро ба VPN мегузаронад. Ҳар дархост ё дар ҷо «нест» мегирад (сайти манъшуда),
 * ё ба CleanBrowsing фиристода мешавад. Ҷавоб ба барномаи пурсанда бармегардад.
 */
class WebFilterVpnService : VpnService() {
    companion object {
        private const val TAG = "NigohWebFilter"
        const val PREFS = "nigoh_web_filter"
        const val KEY_LEVEL = "level"
        const val KEY_BLOCKED = "blocked"
        const val STATE_ACTIVE = "active"
        const val STATE_OFF = "off"
        const val STATE_NEEDS_PERMISSION = "needs_permission"
        private const val ACTION_STOP = "tj.nigoh.webfilter.STOP"

        /** Дар ҳамин процесс филтр ҳоло кор мекунад ё не. */
        @Volatile var running = false
            private set

        /** Сатҳ ва рӯйхатро нигоҳ медорад ва филтрро оғоз/қатъ мекунад. Ҳолати навро бармегардонад. */
        fun configure(context: Context, level: String, blocked: List<String>): String {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_LEVEL, level)
                .putStringSet(KEY_BLOCKED, blocked.toSet())
                .apply()
            if (level == WebFilterDns.LEVEL_OFF) {
                stop(context)
                return STATE_OFF
            }
            if (VpnService.prepare(context) != null) return STATE_NEEDS_PERMISSION
            start(context)
            return STATE_ACTIVE
        }

        /** Ҳолати ҳозира барои хабар ба волидайн: active, off ё needs_permission. */
        fun state(context: Context): String {
            val level = savedLevel(context)
            if (level == WebFilterDns.LEVEL_OFF) return STATE_OFF
            if (VpnService.prepare(context) != null) return STATE_NEEDS_PERMISSION
            return if (running) STATE_ACTIVE else STATE_OFF
        }

        /** Пас аз boot ё вақте хидмати дигар мебинад, ки филтр бояд кор кунад, вале қатъ шудааст. */
        fun startIfEnabled(context: Context) {
            if (running || savedLevel(context) == WebFilterDns.LEVEL_OFF) return
            if (VpnService.prepare(context) != null) return
            runCatching { start(context) }.onFailure { Log.w(TAG, "start failed", it) }
        }

        fun savedLevel(context: Context): String =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_LEVEL, WebFilterDns.LEVEL_OFF) ?: WebFilterDns.LEVEL_OFF

        private fun start(context: Context) {
            context.startService(Intent(context, WebFilterVpnService::class.java))
        }

        private fun stop(context: Context) {
            if (!running) return
            context.startService(Intent(context, WebFilterVpnService::class.java).setAction(ACTION_STOP))
        }
    }

    private var tun: ParcelFileDescriptor? = null
    private var reader: Thread? = null
    private var pool: ExecutorService? = null
    @Volatile private var blocklist: Set<String> = emptySet()
    @Volatile private var upstreams: List<InetAddress> = emptyList()

    /** Фармони оғоз ё қатъро иҷро мекунад; танзими навро бе бозоғозии VPN мегирад. */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            stopSelf()
            return START_NOT_STICKY
        }
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val level = prefs.getString(KEY_LEVEL, WebFilterDns.LEVEL_OFF) ?: WebFilterDns.LEVEL_OFF
        if (level == WebFilterDns.LEVEL_OFF) {
            shutdown()
            stopSelf()
            return START_NOT_STICKY
        }
        blocklist = WebFilterDns.effectiveBlocklist(level, prefs.getStringSet(KEY_BLOCKED, emptySet()).orEmpty())
        upstreams = WebFilterDns.upstreams(level).map { InetAddress.getByName(it) }
        if (tun == null && !establish()) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    /** Интерфейси VPN-ро месозад: як суроға, як DNS ва танҳо як роҳ — ба ҳамон DNS. */
    private fun establish(): Boolean {
        val iface = runCatching {
            Builder()
                .setSession("NIGOH Family")
                .setMtu(WebFilterDns.MTU)
                .addAddress(WebFilterDns.TUN_ADDRESS, 32)
                .addDnsServer(WebFilterDns.DNS_ADDRESS)
                .addRoute(WebFilterDns.DNS_ADDRESS, 32)
                .setBlocking(true)
                .establish()
        }.onFailure { Log.w(TAG, "establish failed", it) }.getOrNull() ?: return false
        tun = iface
        running = true
        pool = Executors.newFixedThreadPool(4)
        reader = Thread({ readLoop(iface) }, "nigoh-dns").also { it.start() }
        return true
    }

    /** Пакетҳоро аз VPN мехонад ва ҳар дархости DNS-ро дар pool коркард мекунад. */
    private fun readLoop(iface: ParcelFileDescriptor) {
        val input = FileInputStream(iface.fileDescriptor)
        val output = FileOutputStream(iface.fileDescriptor)
        val buffer = ByteArray(32767)
        try {
            while (!Thread.currentThread().isInterrupted) {
                val n = input.read(buffer)
                if (n <= 0) continue
                val query = WebFilterDns.parseQuery(buffer, n) ?: continue
                pool?.execute { answer(query, output) }
            }
        } catch (e: Exception) {
            if (running) Log.w(TAG, "read loop stopped", e)
        }
    }

    /** Ба як дархост ҷавоб медиҳад: «нест» барои сайти манъшуда ё ҷавоби сервери филтр. */
    private fun answer(query: WebFilterDns.Query, output: FileOutputStream) {
        val name = WebFilterDns.questionName(query.dns)
        val response = if (name != null && WebFilterDns.isBlocked(name, blocklist)) {
            WebFilterDns.nxDomain(query.dns)
        } else {
            forward(query.dns)
        } ?: return
        val packet = WebFilterDns.wrapResponse(query, response)
        synchronized(output) {
            runCatching { output.write(packet) }
        }
    }

    /** Дархостро ба сервери филтр мефиристад; агар сервери асосӣ ҷавоб надиҳад, ба эҳтиётӣ. */
    private fun forward(dns: ByteArray): ByteArray? {
        for (server in upstreams) {
            try {
                DatagramSocket().use { socket ->
                    // protect: ин сокет аз худи VPN намегузарад (вагарна давра мешуд).
                    protect(socket)
                    socket.soTimeout = 4000
                    socket.send(DatagramPacket(dns, dns.size, server, 53))
                    val buf = ByteArray(4096)
                    val reply = DatagramPacket(buf, buf.size)
                    socket.receive(reply)
                    return buf.copyOf(reply.length)
                }
            } catch (_: SocketTimeoutException) {
                continue
            } catch (e: Exception) {
                Log.w(TAG, "forward failed", e)
            }
        }
        return null
    }

    /** VPN-ро мебандад ва thread-ҳоро қатъ мекунад. */
    private fun shutdown() {
        running = false
        reader?.interrupt()
        reader = null
        pool?.shutdownNow()
        pool?.awaitTermination(1, TimeUnit.SECONDS)
        pool = null
        runCatching { tun?.close() }
        tun = null
    }

    /** Вақте корбар дар танзимот VPN-ро қатъ мекунад ё VPN-и дигар фаъол мешавад. */
    override fun onRevoke() {
        shutdown()
        stopSelf()
    }

    override fun onDestroy() {
        shutdown()
        super.onDestroy()
    }
}
