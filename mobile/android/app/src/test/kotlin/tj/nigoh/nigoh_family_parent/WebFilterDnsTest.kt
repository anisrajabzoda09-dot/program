// Файл: санҷишҳои JUnit барои WebFilterDns — пакетҳои DNS, рӯйхати манъшуда ва ҷавобҳо.

package tj.nigoh.nigoh_family_parent

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream

class WebFilterDnsTest {
    /** Паёми DNS-и «A»-ро барои ном месозад; бо ихтиёр сабти EDNS (OPT) илова мекунад. */
    private fun dnsQuery(name: String, id: Int = 0x1234, edns: Boolean = true): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(id ushr 8); out.write(id and 0xFF)
        out.write(0x01); out.write(0x00)          // RD=1
        out.write(0); out.write(1)                // QDCOUNT
        out.write(0); out.write(0); out.write(0); out.write(0)
        out.write(0); out.write(if (edns) 1 else 0)
        name.split('.').forEach { label -> out.write(label.length); out.write(label.toByteArray()) }
        out.write(0)
        out.write(0); out.write(1); out.write(0); out.write(1) // A, IN
        if (edns) out.write(byteArrayOf(0, 0, 41, 0x10, 0, 0, 0, 0, 0, 0, 0))
        return out.toByteArray()
    }

    /** Пакети IPv4/UDP аз 10.215.173.1:40000 ба суроғаи додашуда месозад. */
    private fun ipPacket(dns: ByteArray, dest: String = WebFilterDns.DNS_ADDRESS, port: Int = 53, proto: Int = 17): ByteArray {
        val total = 28 + dns.size
        val p = ByteArray(total)
        p[0] = 0x45; p[2] = (total ushr 8).toByte(); p[3] = total.toByte(); p[8] = 64; p[9] = proto.toByte()
        WebFilterDns.ipBytes(WebFilterDns.TUN_ADDRESS).copyInto(p, 12)
        WebFilterDns.ipBytes(dest).copyInto(p, 16)
        p[20] = (40000 ushr 8).toByte(); p[21] = (40000 and 0xFF).toByte()
        p[22] = (port ushr 8).toByte(); p[23] = port.toByte()
        p[24] = ((8 + dns.size) ushr 8).toByte(); p[25] = (8 + dns.size).toByte()
        dns.copyInto(p, 28)
        return p
    }

    private fun u16(b: ByteArray, i: Int) = ((b[i].toInt() and 0xFF) shl 8) or (b[i + 1].toInt() and 0xFF)

    @Test fun upstreamsPerLevel() {
        assertEquals(listOf("185.228.168.168", "185.228.169.168"), WebFilterDns.upstreams("kids"))
        assertEquals(listOf("185.228.168.10", "185.228.169.11"), WebFilterDns.upstreams("teen"))
        assertTrue(WebFilterDns.upstreams("off").isEmpty())
        assertTrue(WebFilterDns.upstreams("weird").isEmpty())
    }

    @Test fun blockedMatchesDomainAndSubdomains() {
        val list = setOf("youtube.com", "tiktok.com")
        assertTrue(WebFilterDns.isBlocked("youtube.com", list))
        assertTrue(WebFilterDns.isBlocked("www.youtube.com", list))
        assertTrue(WebFilterDns.isBlocked("M.YouTube.com.", list))
        assertFalse(WebFilterDns.isBlocked("notyoutube.com", list))
        assertFalse(WebFilterDns.isBlocked("youtube.com.evil.tj", list))
        assertFalse(WebFilterDns.isBlocked("google.com", list))
    }

    @Test fun effectiveBlocklistAddsBypassOnlyWhenOn() {
        val kids = WebFilterDns.effectiveBlocklist("kids", listOf(" Roblox.com ", ""))
        assertTrue("roblox.com" in kids)
        assertTrue("dns.google" in kids)
        assertTrue("use-application-dns.net" in kids)
        assertTrue("cloudflare-dns.com" in WebFilterDns.effectiveBlocklist("teen", emptyList()))
        assertEquals(setOf("a.com"), WebFilterDns.effectiveBlocklist("off", listOf("a.com")))
        assertTrue(WebFilterDns.isBlocked("mozilla.cloudflare-dns.com", kids))
    }

    @Test fun parsesDnsQueryToVirtualServer() {
        val dns = dnsQuery("www.youtube.com")
        val q = WebFilterDns.parseQuery(ipPacket(dns))
        assertNotNull(q)
        assertEquals(40000, q!!.sourcePort)
        assertEquals(53, q.destPort)
        assertArrayEquals(dns, q.dns)
        assertEquals("www.youtube.com", WebFilterDns.questionName(q.dns))
    }

    @Test fun ignoresEverythingElse() {
        val dns = dnsQuery("example.com")
        assertNull(WebFilterDns.parseQuery(ipPacket(dns, dest = "8.8.8.8")))          // дигар суроға
        assertNull(WebFilterDns.parseQuery(ipPacket(dns, port = 853)))                // DoT
        assertNull(WebFilterDns.parseQuery(ipPacket(dns, proto = 6)))                 // TCP
        val v6 = ipPacket(dns).also { it[0] = 0x60 }
        assertNull(WebFilterDns.parseQuery(v6))                                       // IPv6
        assertNull(WebFilterDns.parseQuery(ByteArray(10)))                            // кӯтоҳ
        val truncated = ipPacket(dns)
        assertNull(WebFilterDns.parseQuery(truncated, truncated.size - 20))           // нопурра
        val fragment = ipPacket(dns).also { it[6] = 0x20 }
        assertNull(WebFilterDns.parseQuery(fragment))                                 // қисмати пакет
    }

    @Test fun questionNameRejectsBrokenMessages() {
        assertNull(WebFilterDns.questionName(ByteArray(5)))
        val noQuestion = dnsQuery("a.com").also { it[5] = 0 }
        assertNull(WebFilterDns.questionName(noQuestion))
        val pointer = dnsQuery("a.com").also { it[12] = 0xC0.toByte() }
        assertNull(WebFilterDns.questionName(pointer))
        val overflow = dnsQuery("a.com").also { it[12] = 60 }
        assertNull(WebFilterDns.questionName(overflow))
    }

    @Test fun nxDomainAnswersTheSameQuestion() {
        val query = dnsQuery("www.tiktok.com", id = 0xBEEF)
        val nx = WebFilterDns.nxDomain(query)!!
        assertEquals(0xBEEF, u16(nx, 0))                       // ID-и ҳамон дархост
        assertEquals(0x81, nx[2].toInt() and 0xFF)             // QR=1, RD=1
        assertEquals(3, nx[3].toInt() and 0x0F)                // NXDOMAIN
        assertEquals(1, u16(nx, 4))
        assertEquals(0, u16(nx, 6)); assertEquals(0, u16(nx, 8)); assertEquals(0, u16(nx, 10))
        assertEquals("www.tiktok.com", WebFilterDns.questionName(nx))
        assertEquals(12 + 16 + 4, nx.size)                     // сабти EDNS бурида шуд
        assertNull(WebFilterDns.nxDomain(ByteArray(12)))
    }

    @Test fun wrapResponseBuildsValidIpv4Udp() {
        val dns = dnsQuery("example.com")
        val q = WebFilterDns.parseQuery(ipPacket(dns))!!
        val answer = WebFilterDns.nxDomain(dns)!!
        val p = WebFilterDns.wrapResponse(q, answer)
        assertEquals(0x45, p[0].toInt())
        assertEquals(p.size, u16(p, 2))
        assertEquals(17, p[9].toInt())
        assertArrayEquals(WebFilterDns.ipBytes(WebFilterDns.DNS_ADDRESS), p.copyOfRange(12, 16))
        assertArrayEquals(WebFilterDns.ipBytes(WebFilterDns.TUN_ADDRESS), p.copyOfRange(16, 20))
        assertEquals(53, u16(p, 20))
        assertEquals(40000, u16(p, 22))
        assertEquals(8 + answer.size, u16(p, 24))
        assertEquals(u16(p, 10), WebFilterDns.ipChecksum(p, 0, 20))
        // Санҷиши мустақили checksum: ҷамъи ҳамаи калимаҳо бо checksum бояд 0xFFFF шавад.
        var sum = 0
        for (i in 0 until 20 step 2) sum += u16(p, i)
        while (sum shr 16 != 0) sum = (sum and 0xFFFF) + (sum shr 16)
        assertEquals(0xFFFF, sum)
        assertArrayEquals(answer, p.copyOfRange(28, p.size))
    }

    @Test fun oversizedResponseIsTruncatedWithTcFlag() {
        val dns = dnsQuery("big.example.com")
        val q = WebFilterDns.parseQuery(ipPacket(dns))!!
        val big = ByteArray(3000).also { dns.copyInto(it) }
        val p = WebFilterDns.wrapResponse(q, big)
        assertEquals(WebFilterDns.MTU, p.size)
        assertTrue((p[28 + 2].toInt() and 0x02) != 0)
    }
}
