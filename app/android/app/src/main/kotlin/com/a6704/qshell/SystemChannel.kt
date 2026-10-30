package com.a6704.qshell

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.CellSignalStrengthLte
import android.telephony.CellSignalStrengthNr
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.URL

/// 系统信息通道：Material You 取色、链路、Wi-Fi/蜂窝信号、流量、权限、周边扫描。
class SystemChannel(private val activity: MainActivity) {
    private data class PendingPerm(val code: Int, val result: MethodChannel.Result)

    private var pending: PendingPerm? = null

    /// 30 秒节流：requestCellInfoUpdate 不能每秒都发
    private var lastCellUpdateRequest = 0L

    fun onPermissionResult(requestCode: Int, granted: Boolean) {
        val p = pending ?: return
        if (p.code != requestCode) return
        pending = null
        p.result.success(granted)
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "systemAccentColor" -> result.success(systemAccentColor())
            "androidSdkInt" -> result.success(Build.VERSION.SDK_INT)
            "defaultGateways" -> result.success(defaultGateways())
            "wifiInfo" -> result.success(wifiInfo())
            "wifiScan" -> result.success(wifiScan())
            "cellularInfo" -> result.success(cellularInfo())
            "trafficInfo" -> result.success(trafficInfo())
            // 把文件保存到系统「下载」目录（Android 10+ 用 MediaStore，不需要存储权限）
            "saveToDownloads" -> {
                val name = call.argument<String>("name") ?: ""
                val bytes = call.argument<ByteArray>("bytes")
                if (name.isEmpty() || bytes == null) {
                    result.error("bad_args", "缺少文件名或内容", null)
                    return
                }
                Thread {
                    val uri = runCatching { saveToDownloads(name, bytes) }.getOrNull()
                    activity.runOnUiThread { result.success(uri) }
                }.start()
            }
            // 终端保活：前台服务（有活跃 SSH 会话时启动/更新）
            "startKeepAlive" -> {
                val names = call.argument<List<String>>("names") ?: emptyList()
                TerminalKeepAliveService.terminalNames = names
                // 1) 通知权限（Android 13+，否则常驻通知不显示）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    !hasPermission(Manifest.permission.POST_NOTIFICATIONS)
                ) {
                    activity.requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        MainActivity.REQUEST_NOTIFICATIONS,
                    )
                }
                // 2) 请求忽略电池优化（只问一次，避免每次连接都弹）
                runCatching {
                    val powerManager = activity.getSystemService(Context.POWER_SERVICE)
                            as android.os.PowerManager
                    if (!powerManager.isIgnoringBatteryOptimizations(activity.packageName)) {
                        val prefs = activity.getSharedPreferences(
                            "qshell", Context.MODE_PRIVATE,
                        )
                        if (!prefs.getBoolean("asked_battery_optimization", false)) {
                            prefs.edit()
                                .putBoolean("asked_battery_optimization", true)
                                .apply()
                            activity.startActivity(
                                android.content.Intent(
                                    android.provider.Settings
                                        .ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    android.net.Uri.parse(
                                        "package:${activity.packageName}",
                                    ),
                                ),
                            )
                        }
                    }
                }
                // 3) 启动/更新前台服务
                val intent = android.content.Intent(activity, TerminalKeepAliveService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                result.success(null)
            }
            "stopKeepAlive" -> {
                activity.stopService(
                    android.content.Intent(activity, TerminalKeepAliveService::class.java),
                )
                result.success(null)
            }
            // 是否已授予「使用情况访问」（per-app 流量统计需要）
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccess" -> {
                runCatching {
                    val intent = android.content.Intent(
                        android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS,
                        android.net.Uri.parse("package:${activity.packageName}"),
                    ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                }
                result.success(null)
            }
            // 每个应用的流量（近 24 小时，含后台），带图标 PNG
            "appTraffic" -> {
                Thread {
                    val outcome = runCatching { appTraffic() }
                    activity.runOnUiThread {
                        outcome.fold(
                            { result.success(it) },
                            {
                                result.error(
                                    "app_traffic_failed",
                                    it.message ?: "读取应用流量失败",
                                    null,
                                )
                            },
                        )
                    }
                }.start()
            }
            // iperf3 可执行文件路径（打包成 jniLibs/arm64-v8a/libiperf3.so，
            // Android 10+ 只有 nativeLibraryDir 里的文件允许 exec）
            "iperfPath" -> {
                val dir = activity.applicationInfo.nativeLibraryDir
                val file = java.io.File(dir, "libiperf3.so")
                result.success(if (file.exists()) file.absolutePath else null)
            }
            // 真 ICMP ping（非特权 ping socket）；不可用时抛错，Dart 侧降级到 TCP
            "icmpPing" -> {
                val host = call.argument<String>("host") ?: ""
                val count = call.argument<Int>("count") ?: 4
                Thread {
                    val outcome = runCatching {
                        mapOf("rtts" to IcmpPinger.ping(host, count))
                    }
                    activity.runOnUiThread {
                        outcome.fold(
                            { result.success(it) },
                            { result.error("icmp_unavailable", it.message ?: "ICMP 不可用", null) },
                        )
                    }
                }.start()
            }
            // 真 traceroute：优先走 NDK（能拿中间跳），失败再退回纯 Kotlin 实现
            "traceroute" -> {
                val host = call.argument<String>("host") ?: ""
                val maxHops = call.argument<Int>("maxHops") ?: 16
                Thread {
                    val hops = runCatching {
                        if (NativeTraceroute.isAvailable()) {
                            NativeTraceroute.trace(host, maxHops)
                        } else {
                            IcmpPinger.traceroute(host, maxHops)["hops"] as? List<Map<String, Any?>>
                                ?: emptyList()
                        }
                    }.getOrDefault(emptyList())
                    activity.runOnUiThread { result.success(mapOf("hops" to hops, "error" to null)) }
                }.start()
            }
            "resolveHostname" -> {
                val ip = call.argument<String>("ip") ?: ""
                Thread {
                    val name = resolveHostname(ip)
                    activity.runOnUiThread { result.success(name) }
                }.start()
            }
            "hasPhonePermission" -> result.success(hasPermission(Manifest.permission.READ_PHONE_STATE))
            "hasWifiPermission" -> result.success(hasPermission(wifiPermissions().firstOrNull() ?: Manifest.permission.ACCESS_WIFI_STATE))
            "requestPhonePermission" -> request(
                MainActivity.REQUEST_PHONE_STATE,
                arrayOf(Manifest.permission.READ_PHONE_STATE),
                result,
            )
            "requestWifiPermission" -> request(
                MainActivity.REQUEST_WIFI_SCAN,
                wifiPermissions(),
                result,
            )
            // 位置权限（定位 + 部分 ROM 的蜂窝邻区也需要）
            "hasLocationPermission" ->
                result.success(hasPermission(Manifest.permission.ACCESS_FINE_LOCATION))
            "requestLocationPermission" -> request(
                MainActivity.REQUEST_LOCATION,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                result,
            )
            // 最近一次已知位置；没有权限或没有记录时返回 null
            "locationInfo" -> result.success(locationInfo())
            "directPublicIp" -> {
                Thread {
                    val ip = directPublicIpBlocking()
                    activity.runOnUiThread { result.success(ip) }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    // ---------- 权限 ----------

    private fun hasPermission(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    /// 最近一次已知位置（GPS / Network / Passive 里取最新的）。
    private fun locationInfo(): Map<String, Any?>? {
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) &&
            !hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        ) {
            return null
        }
        val lm = activity.getSystemService(Context.LOCATION_SERVICE)
                as? android.location.LocationManager ?: return null
        var best: android.location.Location? = null
        val providers = listOf(
            android.location.LocationManager.GPS_PROVIDER,
            android.location.LocationManager.NETWORK_PROVIDER,
            android.location.LocationManager.PASSIVE_PROVIDER,
        )
        for (provider in providers) {
            runCatching {
                val loc = lm.getLastKnownLocation(provider)
                if (loc != null && (best == null || loc.time > best!!.time)) {
                    best = loc
                }
            }
        }
        val loc = best ?: return null
        return mapOf(
            "lat" to loc.latitude,
            "lng" to loc.longitude,
            "accuracy" to loc.accuracy.toDouble(),
            "altitude" to loc.altitude,
            "speed" to loc.speed.toDouble(),
            "provider" to (loc.provider ?: ""),
            "time" to loc.time,
        )
    }

    private fun wifiPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // 13+ 用 NEARBY_WIFI_DEVICES；部分 ROM 仍需要位置权限才给 SSID
            arrayOf(
                Manifest.permission.NEARBY_WIFI_DEVICES,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun request(code: Int, permissions: Array<String>, result: MethodChannel.Result) {
        if (permissions.all { hasPermission(it) }) {
            result.success(true)
            return
        }
        pending = PendingPerm(code, result)
        activity.requestPermissions(permissions, code)
    }

    // ---------- 配色 ----------

    private fun systemAccentColor(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        val id = activity.resources.getIdentifier("system_accent1_500", "color", "android")
        if (id == 0) return null
        return runCatching { activity.getColor(id) }.getOrNull()
    }

    // ---------- 网络 ----------

    private fun physicalNetworks(): List<Network> {
        val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return cm.allNetworks
            .filter { n ->
                val caps = cm.getNetworkCapabilities(n) ?: return@filter false
                !caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                    (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))
            }
            .sortedByDescending { n ->
                val caps = cm.getNetworkCapabilities(n)
                when {
                    caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> 3
                    caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> 2
                    else -> 1
                }
            }
    }

    private fun defaultGateways(): Map<String, String> {
        val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        var v4: String? = null
        var v6: String? = null

        val networks = buildList {
            addAll(physicalNetworks())
            cm.activeNetwork?.let { if (!contains(it)) add(it) }
        }

        for (network in networks) {
            val lp = cm.getLinkProperties(network) ?: continue
            for (route in lp.routes) {
                if (!route.isDefaultRoute) continue
                val gw = route.gateway ?: continue
                val host = gw.hostAddress ?: continue
                when (gw) {
                    is Inet4Address -> if (v4 == null) v4 = host
                    is Inet6Address -> if (v6 == null) v6 = host
                }
            }
            if (v4 != null && v6 != null) break
        }

        return buildMap {
            v4?.let { put("v4", it) }
            v6?.let { put("v6", it) }
        }
    }

    private fun directPublicIpBlocking(): String? {
        val endpoints = listOf(
            "https://myip.ipip.net/",
            "https://api.ipify.org",
            "https://ipinfo.io/ip",
        )
        val ipv4 = Regex("""(?:\d{1,3}\.){3}\d{1,3}""")
        for (network in physicalNetworks()) {
            for (endpoint in endpoints) {
                val ip = runCatching {
                    val conn = network.openConnection(URL(endpoint)) as HttpURLConnection
                    conn.connectTimeout = 4000
                    conn.readTimeout = 4000
                    conn.requestMethod = "GET"
                    val text = conn.inputStream.bufferedReader().use { it.readText() }
                    conn.disconnect()
                    ipv4.find(text)?.value
                }.getOrNull()
                if (!ip.isNullOrEmpty()) return ip
            }
        }
        return null
    }

    // ---------- Wi-Fi ----------

    private fun rssiToPercent(rssi: Int): Int =
        ((rssi + 100) * 100 / 50).coerceIn(0, 100)

    private fun wifiInfo(): Map<String, Any?>? {
        val wm = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null
        @Suppress("DEPRECATION")
        val info = wm.connectionInfo ?: return null
        val rssi = info.rssi
        if (rssi == -127 || rssi == 0) return null
        val standard = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            runCatching { info.wifiStandard }.getOrDefault(0)
        } else 0
        return mapOf(
            "ssid" to (info.ssid ?: "").trim('"'),
            "bssid" to (info.bssid ?: ""),
            "rssi" to rssi,
            "level" to rssiToPercent(rssi),
            "frequency" to info.frequency,
            "linkSpeed" to runCatching { info.linkSpeed }.getOrDefault(0),
            "standard" to standard,
            "channelWidth" to 0,
        )
    }

    /// 周边 Wi-Fi 扫描。系统对 startScan 有频率限制（约 2 分钟 4 次），
    /// 被限频时返回缓存结果。
    private fun wifiScan(): List<Map<String, Any?>> {
        val wm = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return emptyList()
        if (!hasPermission(wifiPermissions().first())) return emptyList()
        runCatching { wm.startScan() }
        val results = runCatching { wm.scanResults }.getOrNull().orEmpty()
        return results
            .filter { !it.SSID.isNullOrEmpty() }
            .sortedByDescending { it.level }
            .map {
                val width = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    runCatching { it.channelWidth }.getOrDefault(0)
                } else 0
                val standard = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    runCatching { it.wifiStandard }.getOrDefault(0)
                } else 0
                val center = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    runCatching { it.centerFreq0 }.getOrDefault(0)
                } else 0
                mapOf(
                    "ssid" to it.SSID,
                    "bssid" to it.BSSID,
                    "rssi" to it.level,
                    "level" to rssiToPercent(it.level),
                    "frequency" to it.frequency,
                    "capabilities" to it.capabilities,
                    "channelWidth" to 0,
                    "standard" to standard,
                    "centerFreq" to center,
                )
            }
    }

    // ---------- 蜂窝 ----------

    private fun cellularInfo(): List<Map<String, Any?>> {
        if (!hasPermission(Manifest.permission.READ_PHONE_STATE)) return emptyList()
        val tm = activity.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            ?: return emptyList()
        val sm = activity.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
            as? SubscriptionManager ?: return emptyList()

        val subs = runCatching { sm.activeSubscriptionInfoList }.getOrNull().orEmpty()
        val out = mutableListOf<Map<String, Any?>>()
        for (sub in subs) {
            val subTm = runCatching { tm.createForSubscriptionId(sub.subscriptionId) }
                .getOrNull() ?: continue
            val strength = runCatching { subTm.signalStrength }.getOrNull()
            val level = strength?.level ?: 0
            val all = strength?.cellSignalStrengths.orEmpty()
            val lte = all.filterIsInstance<CellSignalStrengthLte>().firstOrNull()
            val nr = all.filterIsInstance<CellSignalStrengthNr>().firstOrNull()

            // MCC / MNC
            val simOperator = subTm.simOperator.orEmpty()
            val mcc = if (simOperator.length >= 5) simOperator.substring(0, 3) else null
            val mnc = if (simOperator.length >= 5) simOperator.substring(3) else null

            // 服务小区 + 邻小区（需要位置权限；部分 ROM 只返回服务小区）
            // 先主动请求一次更新：部分 ROM 只有收到 requestCellInfoUpdate 才会补全邻区
            val nowMs = System.currentTimeMillis()
            if (nowMs - lastCellUpdateRequest > 30_000L) {
                lastCellUpdateRequest = nowMs
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                runCatching {
                    subTm.requestCellInfoUpdate(
                        activity.mainExecutor,
                        object : TelephonyManager.CellInfoCallback() {
                            override fun onCellInfo(
                                cellInfo: MutableList<android.telephony.CellInfo>,
                            ) {}
                            override fun onError(errorCode: Int, detail: Throwable?) {}
                        },
                    )
                }
            }
            }
            val cells = runCatching { subTm.allCellInfo }.getOrNull().orEmpty()
            val serving = cells.firstOrNull { it.isRegistered }
            var tac: Int? = null
            var pci: Int? = null
            var cellId: Long? = null
            var arfcn: Int? = null
            var band: Int? = null
            var cellType: String? = null

            when (serving) {
                is android.telephony.CellInfoNr -> {
                    cellType = "NR"
                    val id = serving.cellIdentity as? android.telephony.CellIdentityNr
                    if (id != null) {
                        runCatching { tac = id.tac }
                        runCatching { pci = id.pci }
                        runCatching { cellId = id.nci }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            runCatching { arfcn = id.nrarfcn }
                            runCatching { band = id.bands?.firstOrNull() }
                        }
                    }
                }
                is android.telephony.CellInfoLte -> {
                    cellType = "LTE"
                    val id = serving.cellIdentity
                    if (id != null) {
                        runCatching { tac = id.tac }
                        runCatching { pci = id.pci }
                        runCatching { cellId = id.ci.toLong() }
                        runCatching { arfcn = id.earfcn }
                        runCatching { band = id.bands?.firstOrNull() }
                    }
                }
            }

            val neighbors = cells.filter { !it.isRegistered }.mapNotNull { cell ->
                when (cell) {
                    is android.telephony.CellInfoNr -> {
                        val id = cell.cellIdentity as? android.telephony.CellIdentityNr
                        val ss = cell.cellSignalStrength as? CellSignalStrengthNr
                        mapOf(
                            "type" to "NR",
                            "pci" to runCatching { id?.pci }.getOrNull(),
                            "rsrp" to runCatching { ss?.ssRsrp }.getOrNull(),
                            "rsrq" to runCatching { ss?.ssRsrq }.getOrNull(),
                            "sinr" to runCatching { ss?.ssSinr }.getOrNull(),
                            "band" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                runCatching { id?.bands?.firstOrNull() }.getOrNull()
                            } else {
                                null
                            },
                        )
                    }
                    is android.telephony.CellInfoLte -> {
                        val id = cell.cellIdentity
                        val ss = cell.cellSignalStrength as? CellSignalStrengthLte
                        mapOf(
                            "type" to "LTE",
                            "pci" to runCatching { id?.pci }.getOrNull(),
                            "rsrp" to runCatching { ss?.rsrp }.getOrNull(),
                            "rsrq" to runCatching { ss?.rsrq }.getOrNull(),
                            "sinr" to runCatching { ss?.rssnr }.getOrNull(),
                            "band" to runCatching { id?.bands?.firstOrNull() }.getOrNull(),
                        )
                    }
                    else -> null
                }
            }.take(12)

            out.add(
                mapOf(
                    "slot" to (sub.simSlotIndex + 1),
                    "carrier" to (sub.carrierName?.toString() ?: ""),
                    "level" to level,
                    "percent" to cellularPercent(level, lte?.rsrp, nr?.ssRsrp),
                    "dbm" to all.firstOrNull()?.dbm,
                    "rsrp" to lte?.rsrp,
                    "rsrq" to lte?.rsrq,
                    "sinr" to lte?.rssnr,
                    "nrRsrp" to nr?.ssRsrp,
                    "nrRsrq" to runCatching { nr?.ssRsrq }.getOrNull(),
                    "nrSinr" to runCatching { nr?.ssSinr }.getOrNull(),
                    "networkType" to subTm.dataNetworkType,
                    "operatorName" to (subTm.networkOperatorName ?: ""),
                    "mcc" to mcc,
                    "mnc" to mnc,
                    "cellType" to cellType,
                    "tac" to tac,
                    "pci" to pci,
                    "cellId" to cellId,
                    "arfcn" to arfcn,
                    "band" to band,
                    "neighbors" to neighbors,
                ),
            )
        }
        return out
    }

    /// 用 RSRP 精确映射百分比，而不是粗暴的 0~4 档 × 25。
    /// LTE RSRP 有效范围约 -140 ~ -44 dBm；5G NR 约 -156 ~ -44 dBm。
    /// 拿不到 RSRP 时才退回系统档位。
    private fun cellularPercent(level: Int, lteRsrp: Int?, nrRsrp: Int?): Int {
        if (lteRsrp != null && lteRsrp > -140 && lteRsrp < 0) {
            return ((lteRsrp + 140) * 100 / 96).coerceIn(0, 100)
        }
        if (nrRsrp != null && nrRsrp > -156 && nrRsrp < 0) {
            return ((nrRsrp + 156) * 100 / 112).coerceIn(0, 100)
        }
        return (level * 25).coerceIn(0, 100)
    }

    // ---------- 局域网设备 ----------

    /// 找到承载局域网的物理网络（Wi-Fi / 有线优先），而不是当前活动网络。
    /// 挂代理时 activeNetwork 是 VPN，直接用它会把代理网段当成局域网。
    private fun localNetworkLink(): Pair<Network, android.net.LinkProperties>? {
        val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        fun linkOf(network: Network): android.net.LinkProperties? =
            cm.getLinkProperties(network)

        val candidates = physicalNetworks().sortedByDescending { n ->
            val caps = cm.getNetworkCapabilities(n)
            when {
                caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> 3
                caps?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> 2
                else -> 1
            }
        }
        for (network in candidates) {
            val lp = linkOf(network) ?: continue
            if (lp.linkAddresses.any { it.address is Inet4Address }) {
                return network to lp
            }
        }
        // 兜底：当前活动网络
        val active = cm.activeNetwork ?: return null
        val lp = linkOf(active) ?: return null
        return active to lp
    }

    /// 扫描当前局域网（限定 /24）内的在线设备。
    /// 优先读 /proc/net/arp 拿 MAC，再用 ping 补全在线状态。
    private fun lanScanBlocking(): Map<String, Any?> {
        val (_, lp) = localNetworkLink() ?: return mapOf("selfIp" to null, "devices" to emptyList<Any>())
        val self = lp.linkAddresses.firstOrNull { it.address is Inet4Address }
            ?: return mapOf("selfIp" to null, "devices" to emptyList<Any>())
        val selfIp = self.address.hostAddress ?: return mapOf("selfIp" to null, "devices" to emptyList<Any>())
        val parts = selfIp.split(".")
        if (parts.size != 4) return mapOf("selfIp" to selfIp, "devices" to emptyList<Any>())
        val base = "${parts[0]}.${parts[1]}.${parts[2]}"

        val arp = readArpTable()
        val found = java.util.concurrent.ConcurrentHashMap<String, String?>()
        val pool = java.util.concurrent.Executors.newFixedThreadPool(32)
        for (i in 1..254) {
            val target = "$base.$i"
            if (target == selfIp) continue
            pool.submit {
                if (pingOnce(target)) {
                    found[target] = arp[target]
                }
            }
        }
        pool.shutdown()
        pool.awaitTermination(25, java.util.concurrent.TimeUnit.SECONDS)

        val devices = found.entries
            .sortedBy { it.key.split(".").last().toIntOrNull() ?: 0 }
            .map {
                mapOf(
                    "ip" to it.key,
                    "mac" to (it.value ?: ""),
                )
            }
        return mapOf("selfIp" to selfIp, "devices" to devices)
    }

    private fun pingOnce(ip: String): Boolean = runCatching {
        val p = ProcessBuilder("/system/bin/ping", "-c", "1", "-W", "1", ip)
            .redirectErrorStream(true)
            .start()
        val finished = p.waitFor(1500, java.util.concurrent.TimeUnit.MILLISECONDS)
        if (finished) p.exitValue() == 0 else {
            p.destroy()
            false
        }
    }.getOrDefault(false)

    private fun readArpTable(): Map<String, String> = runCatching {
        java.io.File("/proc/net/arp").readLines()
            .drop(1)
            .mapNotNull { line ->
                val cols = line.trim().split(Regex("\\s+"))
                if (cols.size >= 4 && cols[3] != "00:00:00:00:00:00") {
                    cols[0] to cols[3]
                } else {
                    null
                }
            }
            .toMap()
    }.getOrDefault(emptyMap())

    // ---------- 流量 ----------

    private fun trafficInfo(): Map<String, Long> = mapOf(
        "rx" to TrafficStats.getTotalRxBytes(),
        "tx" to TrafficStats.getTotalTxBytes(),
    )

    /// 写入系统下载目录，返回 content:// URI（API 29+）。
    /// 低版本没有 MediaStore.Downloads，返回 null，调用方回退到应用目录。
    private fun saveToDownloads(name: String, bytes: ByteArray): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = activity.contentResolver
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.Downloads.DISPLAY_NAME, name)
            put(
                android.provider.MediaStore.Downloads.MIME_TYPE,
                "application/octet-stream",
            )
            put(
                android.provider.MediaStore.Downloads.RELATIVE_PATH,
                android.os.Environment.DIRECTORY_DOWNLOADS + "/QShell",
            )
        }
        val uri = resolver.insert(
            android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values,
        ) ?: return null
        resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return null
        return uri.toString()
    }

    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = activity.getSystemService(android.content.Context.APP_OPS_SERVICE)
                    as android.app.AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    activity.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    activity.packageName,
                )
            }
            mode == android.app.AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            false
        }
    }

    /// 近 [hours] 小时内每个应用的流量（含后台），按总量降序。
    /// 需要「使用情况访问」权限；没有权限时返回空列表。
    private fun appTraffic(hours: Int = 24): List<Map<String, Any?>> {
        if (!hasUsageAccess()) return emptyList()
        val nsm = activity.getSystemService(android.content.Context.NETWORK_STATS_SERVICE)
                as android.app.usage.NetworkStatsManager
        val end = System.currentTimeMillis()
        val start = end - hours * 3600_000L

        val perUid = HashMap<Int, LongArray>() // uid -> [rx, tx]
        val types = intArrayOf(
            android.net.ConnectivityManager.TYPE_WIFI,
            android.net.ConnectivityManager.TYPE_MOBILE,
        )
        for (type in types) {
            runCatching {
                val stats = nsm.querySummary(type, null, start, end)
                try {
                    val bucket = android.app.usage.NetworkStats.Bucket()
                    while (stats.hasNextBucket()) {
                        stats.getNextBucket(bucket)
                        if (bucket.uid < 0) continue
                        val cur = perUid.getOrPut(bucket.uid) { LongArray(2) }
                        cur[0] += bucket.rxBytes
                        cur[1] += bucket.txBytes
                    }
                } finally {
                    stats.close()
                }
            }
        }

        val pm = activity.packageManager
        val result = ArrayList<Map<String, Any?>>()
        for ((uid, bytes) in perUid) {
            if (bytes[0] + bytes[1] <= 0L) continue
            val packages = pm.getPackagesForUid(uid) ?: continue
            val pkg = packages.firstOrNull() ?: continue
            val label = runCatching {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            }.getOrDefault(pkg)
            val iconBytes = runCatching { appIconPng(pkg) }.getOrNull()
            result.add(
                mapOf(
                    "package" to pkg,
                    "label" to label,
                    "uid" to uid,
                    "rx" to bytes[0],
                    "tx" to bytes[1],
                    "icon" to iconBytes,
                ),
            )
        }
        result.sortByDescending { (it["rx"] as Long) + (it["tx"] as Long) }
        return result.take(60)
    }

    /// 应用图标转 96x96 PNG 字节，方便 Dart 侧直接 Image.memory 显示。
    private fun appIconPng(packageName: String): ByteArray? {
        val pm = activity.packageManager
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getApplicationInfo(
                packageName,
                android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationInfo(packageName, 0)
        }
        val drawable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getApplicationIcon(
                pm.getApplicationInfo(
                    packageName,
                    android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            pm.getApplicationIcon(info)
        }
        val size = 96
        val bitmap = android.graphics.Bitmap.createBitmap(
            size, size, android.graphics.Bitmap.Config.ARGB_8888,
        )
        val canvas = android.graphics.Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val out = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    // ---------- 主机名 ----------

    /// 反向 DNS（PTR）解析设备名；拿不到（等于 IP 本身）返回 null。
    /// 带 1.5 秒超时，避免某些 IP 卡住整个扫描。
    private fun resolveHostname(ip: String): String? {
        if (ip.isBlank()) return null
        val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
        val future = executor.submit<String?> {
            runCatching { java.net.InetAddress.getByName(ip).canonicalHostName }.getOrNull()
        }
        return try {
            val name = future.get(1500, java.util.concurrent.TimeUnit.MILLISECONDS)
            if (name.isNullOrBlank() || name == ip) null else name
        } catch (_: Exception) {
            future.cancel(true)
            null
        } finally {
            executor.shutdownNow()
        }
    }
}
