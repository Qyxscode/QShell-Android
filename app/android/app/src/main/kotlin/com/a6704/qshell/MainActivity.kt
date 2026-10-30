package com.a6704.qshell

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var systemChannel: SystemChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        systemChannel = SystemChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qshell/system")
            .setMethodCallHandler(systemChannel::handle)

        // Traceroute 流式输出：每跳一条事件
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "qshell/traceroute")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val args = arguments as? Map<*, *>
                    val host = (args?.get("host") as? String).orEmpty()
                    val maxHops = (args?.get("maxHops") as? Int) ?: 16
                    if (host.isEmpty() || events == null) return
                    if (!NativeTraceroute.isAvailable()) {
                        events.error("no_native", "native 库未加载", null)
                        return
                    }
                    Thread {
                        NativeTraceroute.stream(
                            host = host,
                            maxHops = maxHops,
                            timeoutMs = 1200,
                        ) { ttl, address, rtt, reached ->
                            runOnUiThread {
                                events.success(
                                    mapOf(
                                        "ttl" to ttl,
                                        "address" to address,
                                        "rtt" to if (rtt >= 0) rtt else null,
                                        "reached" to reached,
                                        "error" to if (address == null) "no reply" else null,
                                    ),
                                )
                                if (reached) {
                                    runCatching { events.endOfStream() }
                                }
                            }
                        }
                    }.start()
                }

                override fun onCancel(arguments: Any?) {}
            })
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == android.content.pm.PackageManager.PERMISSION_GRANTED }
        if (::systemChannel.isInitialized) {
            systemChannel.onPermissionResult(requestCode, granted)
        }
    }

    companion object {
        const val REQUEST_PHONE_STATE = 1001
        const val REQUEST_WIFI_SCAN = 1002
        const val REQUEST_LOCATION = 1003
        const val REQUEST_NOTIFICATIONS = 1004
    }
}
