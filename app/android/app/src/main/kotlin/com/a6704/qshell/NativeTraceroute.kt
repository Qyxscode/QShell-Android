package com.a6704.qshell

/// NDK 版 traceroute：用 recvmsg(MSG_ERRQUEUE) + IP_RECVERR 读 ICMP 错误队列，
/// 这样才能拿到中间路由的地址（纯 Java 层拿不到）。
object NativeTraceroute {
    @Volatile
    private var loaded = false

    init {
        loaded = runCatching {
            System.loadLibrary("qshell_native")
            true
        }.getOrDefault(false)
    }

    fun isAvailable(): Boolean = loaded

    /// 逐跳回调接口（C 层通过 JNI 调用）
    interface HopCallback {
        fun onHop(ttl: Int, address: String?, rtt: Double, reached: Boolean)
    }

    /// 返回每跳 "ttl|ip|rttMs|reached"，拿不到 IP 时 ip 为空。
    private external fun traceNative(
        host: String,
        maxHops: Int,
        timeoutMs: Int,
    ): Array<String>?

    /// 流式版本：每测完一跳回调一次。
    private external fun traceStream(
        host: String,
        maxHops: Int,
        timeoutMs: Int,
        callback: HopCallback,
    )

    /// 同步执行流式 traceroute（调用方负责放进后台线程）。
    fun stream(
        host: String,
        maxHops: Int = 16,
        timeoutMs: Int = 1200,
        onHop: (ttl: Int, address: String?, rttMs: Double, reached: Boolean) -> Unit,
    ): Boolean {
        if (!loaded) return false
        traceStream(
            host,
            maxHops,
            timeoutMs,
            object : HopCallback {
                override fun onHop(
                    ttl: Int,
                    address: String?,
                    rtt: Double,
                    reached: Boolean,
                ) {
                    onHop(ttl, address, rtt, reached)
                }
            },
        )
        return true
    }

    fun trace(host: String, maxHops: Int = 16, timeoutMs: Int = 1200): List<Map<String, Any?>> {
        if (!loaded) throw IllegalStateException("native 库未加载")
        val raw = traceNative(host, maxHops, timeoutMs) ?: return emptyList()
        return raw.mapNotNull { line ->
            val parts = line.split('|')
            if (parts.size < 4) return@mapNotNull null
            val ttl = parts[0].toIntOrNull() ?: return@mapNotNull null
            val ip = parts[1].ifBlank { null }
            val rtt = parts[2].toDoubleOrNull()?.takeIf { it >= 0 }
            val reached = parts[3] == "1"
            mapOf(
                "ttl" to ttl,
                "address" to ip,
                "rtt" to rtt,
                "reached" to reached,
                "error" to if (ip == null) "no reply" else null,
            )
        }
    }
}
