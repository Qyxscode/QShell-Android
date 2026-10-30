package com.a6704.qshell

import android.system.Os
import android.system.OsConstants
import android.system.StructTimeval
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import kotlin.random.Random

/// 非特权 ICMP（Linux ping socket：SOCK_DGRAM + IPPROTO_ICMP）。
///
/// 不需要 root，也不需要 VpnService —— 只要内核的 ping_group_range 允许
/// 且 SELinux 没拦 icmp_socket。用不了时抛异常，由上层降级到 TCP ping。
object IcmpPinger {
    /// 双栈域名时 getAllByName 可能先给 IPv6，这里显式挑 IPv4。
    private fun resolveIpv4(host: String): Inet4Address? {
        val all = InetAddress.getAllByName(host)
        return all.filterIsInstance<Inet4Address>().firstOrNull()
    }
    private fun checksum(data: ByteArray): Int {
        var sum = 0
        var i = 0
        while (i + 1 < data.size) {
            sum += ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
            i += 2
        }
        if (i < data.size) sum += (data[i].toInt() and 0xFF) shl 8
        while ((sum shr 16) != 0) sum = (sum and 0xFFFF) + (sum shr 16)
        return sum.inv() and 0xFFFF
    }

    private fun buildEcho(id: Int, seq: Int, payloadSize: Int = 32): ByteArray {
        val packet = ByteArray(8 + payloadSize)
        packet[0] = 8 // Echo Request
        packet[1] = 0
        packet[4] = ((id shr 8) and 0xFF).toByte()
        packet[5] = (id and 0xFF).toByte()
        packet[6] = ((seq shr 8) and 0xFF).toByte()
        packet[7] = (seq and 0xFF).toByte()
        for (i in 0 until payloadSize) {
            packet[8 + i] = ('a' + (i % 26)).code.toByte()
        }
        val cs = checksum(packet)
        packet[2] = ((cs shr 8) and 0xFF).toByte()
        packet[3] = (cs and 0xFF).toByte()
        return packet
    }

    private fun applyTimeout(fd: java.io.FileDescriptor, timeoutMs: Int) {
        Os.setsockoptTimeval(
            fd,
            OsConstants.SOL_SOCKET,
            OsConstants.SO_RCVTIMEO,
            StructTimeval.fromMillis(timeoutMs.toLong()),
        )
    }

    /// 返回每包的 RTT（毫秒），超时/失败为 -1。
    fun ping(
        host: String,
        count: Int = 4,
        timeoutMs: Int = 1500,
        payloadSize: Int = 32,
    ): List<Double> {
        val address = resolveIpv4(host)
            ?: throw UnsupportedOperationException("解析不到 IPv4 地址（ICMP 目前只支持 IPv4）")
        val fd = Os.socket(OsConstants.AF_INET, OsConstants.SOCK_DGRAM, OsConstants.IPPROTO_ICMP)
        try {
            applyTimeout(fd, timeoutMs)

            val id = Random.nextInt(0x10000)
            val results = mutableListOf<Double>()
            val buffer = ByteArray(1500)
            val source = InetSocketAddress(0)

            for (seq in 1..count) {
                val packet = buildEcho(id, seq, payloadSize)
                val start = System.nanoTime()
                try {
                    Os.sendto(fd, packet, 0, packet.size, 0, address, 0)
                } catch (e: Exception) {
                    // 第一包就发不出去（比如 SELinux 拦 sendmsg），直接把错误抛给上层去降级
                    if (seq == 1) throw e
                    results.add(-1.0)
                    continue
                }

                var rtt = -1.0
                val deadline = System.currentTimeMillis() + timeoutMs
                while (System.currentTimeMillis() <= deadline) {
                    val length = try {
                        Os.recvfrom(fd, buffer, 0, buffer.size, 0, source)
                    } catch (e: Exception) {
                        -1
                    }
                    if (length <= 0) break
                    if ((buffer[0].toInt() and 0xFF) != 0) continue // 不是 Echo Reply
                    // 注意：ping socket 的 identifier 由内核改写，不能用自己生成的值匹配，
                    // 只按序号核对即可
                    val recvSeq = ((buffer[6].toInt() and 0xFF) shl 8) or (buffer[7].toInt() and 0xFF)
                    if (recvSeq == seq) {
                        rtt = (System.nanoTime() - start) / 1_000_000.0
                        break
                    }
                }
                results.add(rtt)
                // 标准 ping 的节奏：每个包间隔 1 秒
                if (seq < count) Thread.sleep(1000)
            }
            return results
        } finally {
            runCatching { Os.close(fd) }
        }
    }

    /// TTL 递增做 traceroute。
    ///
    /// 返回 `{hops: [...], error: "..."}`：
    /// - hops 里每项含 ttl / address / rtt / reached / error
    /// - error 非空表示整体失败（比如 setsockopt(IP_TTL) 被拒）
    fun traceroute(
        host: String,
        maxHops: Int = 16,
        timeoutMs: Int = 1200,
    ): Map<String, Any?> {
        val hops = mutableListOf<Map<String, Any?>>()
        var fatal: String? = null

        val address = try {
            resolveIpv4(host)
        } catch (e: Exception) {
            return mapOf("hops" to hops, "error" to "解析主机失败：${e.message}")
        } ?: return mapOf(
            "hops" to hops,
            "error" to "解析不到 IPv4 地址（ICMP 目前只支持 IPv4）",
        )

        val fd = try {
            Os.socket(OsConstants.AF_INET, OsConstants.SOCK_DGRAM, OsConstants.IPPROTO_ICMP)
        } catch (e: Exception) {
            return mapOf("hops" to hops, "error" to "创建 ICMP socket 失败：${e.message}")
        }

        try {
            applyTimeout(fd, timeoutMs)
            val id = Random.nextInt(0x10000)
            val buffer = ByteArray(1500)
            val source = InetSocketAddress(0)

            for (ttl in 1..maxHops) {
                try {
                    Os.setsockoptInt(fd, OsConstants.IPPROTO_IP, OsConstants.IP_TTL, ttl)
                } catch (e: Exception) {
                    // ping socket 上设置 IP_TTL 被拒，直接告诉上层
                    fatal = "设置 TTL 失败（IP_TTL 不被 ping socket 支持）：${e.message}"
                    break
                }
                val packet = buildEcho(id, ttl, 16)
                val start = System.nanoTime()
                try {
                    Os.sendto(fd, packet, 0, packet.size, 0, address, 0)
                } catch (e: Exception) {
                    fatal = "发送失败：${e.message}"
                    break
                }

                var hopAddress: String? = null
                var reached = false
                var rtt = -1.0
                var lastError: String? = null
                val deadline = System.currentTimeMillis() + timeoutMs
                while (System.currentTimeMillis() <= deadline) {
                    val length = try {
                        Os.recvfrom(fd, buffer, 0, buffer.size, 0, source)
                    } catch (e: Exception) {
                        lastError = e.message ?: e.javaClass.simpleName
                        -1
                    }
                    if (length <= 0) break
                    val type = buffer[0].toInt() and 0xFF
                    val recvSeq = ((buffer[6].toInt() and 0xFF) shl 8) or (buffer[7].toInt() and 0xFF)
                    val from = source.address?.hostAddress
                    if (type == 0 && recvSeq == ttl) {
                        reached = true
                        hopAddress = from ?: address.hostAddress
                        rtt = (System.nanoTime() - start) / 1_000_000.0
                        break
                    }
                    if (type == 11) {
                        hopAddress = from
                        rtt = (System.nanoTime() - start) / 1_000_000.0
                        break
                    }
                    lastError = "type=$type"
                }
                hops.add(
                    mapOf(
                        "ttl" to ttl,
                        "address" to hopAddress,
                        "rtt" to if (rtt < 0) null else rtt,
                        "reached" to reached,
                        "error" to lastError,
                    ),
                )
                if (reached) break
            }
        } finally {
            runCatching { Os.close(fd) }
        }
        return mapOf("hops" to hops, "error" to fatal)
    }
}
