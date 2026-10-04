// Файл: мантиқи тозаи филтри сайтҳо — хондани пакетҳои DNS, санҷиши доменҳои манъшуда
// ва сохтани ҷавобҳо. Аз Android вобаста нест, бинобар ин бо JUnit санҷида мешавад.

package tj.nigoh.nigoh_family_parent

/**
 * Сатҳҳои филтр, серверҳои DNS-и филтрдор ва амалиёт бо пакетҳои IPv4/UDP/DNS.
 *
 * Филтр DNS-ро иваз мекунад: телефон номи сайтро аз сервери CleanBrowsing мепурсад, ки
 * сайтҳои калонсолонро намекушояд ва дар Google, Bing ва YouTube ҷустуҷӯи бехатарро
 * ҳатмӣ мекунад. Сайтҳое, ки волидайн дастӣ бастанд, дар худи телефон ҷавоби «нест» мегиранд.
 */
object WebFilterDns {
    const val LEVEL_OFF = "off"
    const val LEVEL_KIDS = "kids"
    const val LEVEL_TEEN = "teen"

    /** Суроғаҳои дохилии VPN: телефон DNS-ро ба DNS_ADDRESS мефиристад ва он ба мо меояд. */
    const val TUN_ADDRESS = "10.215.173.1"
    const val DNS_ADDRESS = "10.215.173.2"
    const val MTU = 1500

    private const val RCODE_NXDOMAIN = 3
    private const val UDP = 17

    /**
     * Серверҳои CleanBrowsing барои ҳар сатҳ (асосӣ, эҳтиётӣ).
     * kids — Family Filter: калонсолон, прокси/VPN, сайтҳои омехта; SafeSearch ва YouTube-и маҳдуд.
     * teen — Adult Filter: сайтҳои калонсолон; SafeSearch дар Google ва Bing.
     */
    fun upstreams(level: String): List<String> = when (level) {
        LEVEL_KIDS -> listOf("185.228.168.168", "185.228.169.168")
        LEVEL_TEEN -> listOf("185.228.168.10", "185.228.169.11")
        else -> emptyList()
    }

    /**
     * Серверҳои «DNS-и рамзгузоришуда» (DoH), ки бо онҳо браузер метавонад филтрро гузарад.
     * Барои онҳо «нест» ҷавоб медиҳем, то браузер ба DNS-и муқаррарӣ баргардад.
     * use-application-dns.net — сигнали расмӣ ба Firefox, ки DoH-ро хомӯш кунад.
     */
    val BYPASS_DOMAINS = setOf(
        "use-application-dns.net",
        "dns.google", "dns.google.com", "dns64.dns.google",
        "cloudflare-dns.com", "one.one.one.one", "1dot1dot1dot1.cloudflare-dns.com",
        "dns.quad9.net", "dns.nextdns.io", "doh.opendns.com", "dns.adguard-dns.com",
        "dns.adguard.com", "doh.dns.sb", "dns.alidns.com", "doh.pub", "doh.mullvad.net",
    )

    /** Ҳамаи қисмҳои як пакети DNS, ки аз телефон омад. */
    data class Query(
        val sourceIp: ByteArray,
        val destIp: ByteArray,
        val sourcePort: Int,
        val destPort: Int,
        val dns: ByteArray,
    )

    /** Ном мувофиқи рӯйхат баста аст: худи домен ё ягон зердомени он (m.youtube.com → youtube.com). */
    fun isBlocked(name: String, blocked: Set<String>): Boolean {
        var host = name.trimEnd('.').lowercase()
        while (true) {
            if (host in blocked) return true
            val dot = host.indexOf('.')
            if (dot < 0) return false
            host = host.substring(dot + 1)
        }
    }

    /** Рӯйхати пурраи манъшуда: сайтҳои волидайн ва серверҳои DoH (вақте филтр фаъол аст). */
    fun effectiveBlocklist(level: String, parentBlocked: Collection<String>): Set<String> {
        val result = parentBlocked.map { it.trim().trimEnd('.').lowercase() }.filter { it.isNotEmpty() }.toMutableSet()
        if (level == LEVEL_KIDS || level == LEVEL_TEEN) result.addAll(BYPASS_DOMAINS)
        return result
    }

    /** Агар пакет дархости DNS-и IPv4/UDP ба DNS_ADDRESS:53 бошад, онро ҷудо мекунад; вагарна null. */
    fun parseQuery(packet: ByteArray, length: Int = packet.size, dnsAddress: ByteArray = ipBytes(DNS_ADDRESS)): Query? {
        if (length < 28) return null
        val version = (packet[0].toInt() ushr 4) and 0xF
        if (version != 4) return null
        val ihl = (packet[0].toInt() and 0xF) * 4
        if (ihl < 20 || length < ihl + 8) return null
        val total = u16(packet, 2)
        if (total > length || total < ihl + 8) return null
        if ((packet[9].toInt() and 0xFF) != UDP) return null
        val fragment = u16(packet, 6) and 0x3FFF
        if (fragment != 0) return null
        val dest = packet.copyOfRange(16, 20)
        if (!dest.contentEquals(dnsAddress)) return null
        val destPort = u16(packet, ihl + 2)
        if (destPort != 53) return null
        val udpLength = u16(packet, ihl + 4)
        if (udpLength < 8 || ihl + udpLength > total) return null
        val dns = packet.copyOfRange(ihl + 8, ihl + udpLength)
        if (dns.size < 12) return null
        return Query(packet.copyOfRange(12, 16), dest, u16(packet, ihl), destPort, dns)
    }

    /** Номи аввалин саволро аз паёми DNS мехонад (масалан «www.youtube.com»); хато бошад, null. */
    fun questionName(dns: ByteArray): String? {
        if (dns.size < 12 || u16(dns, 4) < 1) return null
        val labels = ArrayList<String>()
        var i = 12
        while (i < dns.size) {
            val len = dns[i].toInt() and 0xFF
            if (len == 0) return labels.joinToString(".")
            if (len and 0xC0 != 0 || len > 63 || i + 1 + len > dns.size) return null
            labels.add(String(dns, i + 1, len, Charsets.US_ASCII))
            i += 1 + len
            if (labels.sumOf { it.length + 1 } > 255) return null
        }
        return null
    }

    /** Дарозии қисми «савол» (ном + навъ + синф), то ҷавоби NXDOMAIN-ро аз он созем. */
    private fun questionEnd(dns: ByteArray): Int? {
        var i = 12
        while (i < dns.size) {
            val len = dns[i].toInt() and 0xFF
            if (len == 0) return if (i + 5 <= dns.size) i + 5 else null
            if (len and 0xC0 != 0) return null
            i += 1 + len
        }
        return null
    }

    /** Ҷавоби «чунин сайт нест» (NXDOMAIN) барои дархост месозад; хато бошад, null. */
    fun nxDomain(query: ByteArray): ByteArray? {
        val end = questionEnd(query) ?: return null
        val out = query.copyOfRange(0, end)
        val rd = out[2].toInt() and 0x01
        val opcode = out[2].toInt() and 0x78
        out[2] = (0x80 or opcode or rd).toByte()        // QR=1, opcode ва RD нигоҳ дошта мешаванд
        out[3] = (0x80 or RCODE_NXDOMAIN).toByte()      // RA=1, RCODE=3
        out[4] = 0; out[5] = 1                          // QDCOUNT=1
        for (k in 6 until 12) out[k] = 0                // AN/NS/AR = 0
        return out
    }

    /**
     * Ҷавоби DNS-ро ба пакети IPv4/UDP мепечонад: аз DNS_ADDRESS:53 ба телефон.
     * Агар ҷавоб аз MTU калон бошад, бурида ва бо байрақи TC қайд мешавад.
     */
    fun wrapResponse(query: Query, dnsResponse: ByteArray): ByteArray {
        var payload = dnsResponse
        val maxPayload = MTU - 28
        if (payload.size > maxPayload) {
            payload = payload.copyOfRange(0, maxPayload)
            payload[2] = (payload[2].toInt() or 0x02).toByte() // TC=1
        }
        val total = 28 + payload.size
        val p = ByteArray(total)
        p[0] = 0x45
        put16(p, 2, total)
        put16(p, 6, 0x4000) // DF
        p[8] = 64
        p[9] = UDP.toByte()
        query.destIp.copyInto(p, 12)
        query.sourceIp.copyInto(p, 16)
        put16(p, 10, ipChecksum(p, 0, 20))
        put16(p, 20, query.destPort)
        put16(p, 22, query.sourcePort)
        put16(p, 24, 8 + payload.size)
        // Checksum-и UDP барои IPv4 ихтиёрӣ аст (0 = ҳисоб нашуд).
        payload.copyInto(p, 28)
        return p
    }

    /** Checksum-и сарлавҳаи IPv4 (RFC 791). */
    fun ipChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0L
        var i = offset
        while (i < offset + length - 1) {
            if (i != offset + 10) sum += u16(data, i).toLong()
            i += 2
        }
        while (sum shr 16 != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        return (sum.inv() and 0xFFFF).toInt()
    }

    /** «10.215.173.2» → 4 байт. */
    fun ipBytes(address: String): ByteArray =
        address.split('.').map { it.toInt().toByte() }.toByteArray()

    private fun u16(b: ByteArray, i: Int): Int = ((b[i].toInt() and 0xFF) shl 8) or (b[i + 1].toInt() and 0xFF)

    private fun put16(b: ByteArray, i: Int, v: Int) {
        b[i] = (v ushr 8).toByte()
        b[i + 1] = v.toByte()
    }
}
