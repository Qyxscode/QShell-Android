package com.a6704.qshell

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * 终端保活前台服务。
 *
 * 有活跃 SSH 会话时启动，除了通知栏常驻把进程提到前台，
 * 还会持有 WakeLock（熄屏不休眠）和 WiFi 高性能锁（熄屏不断 WiFi），
 * 否则 Doze 模式下网络会被切断，SSH 立刻掉线。
 */
class TerminalKeepAliveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            // Android 14+：dataSync 类型有每日配额，长连接会被系统掐掉，
            // 必须用 specialUse 才能长时间挂后台
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireLocks()
        isRunning = true
        return START_STICKY
    }

    private fun acquireLocks() {
        if (wakeLock?.isHeld != true) {
            runCatching {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "QShell:terminal",
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
                holdingWakeLock = true
            }
        }
        if (wifiLock?.isHeld != true) {
            runCatching {
                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE)
                        as WifiManager
                wifiLock = wm.createWifiLock(
                    WifiManager.WIFI_MODE_FULL_HIGH_PERF,
                    "QShell:terminal",
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
            }
        }
    }

    private fun releaseLocks() {
        runCatching {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        }
        wakeLock = null
        holdingWakeLock = false
        runCatching {
            if (wifiLock?.isHeld == true) wifiLock?.release()
        }
        wifiLock = null
    }

    override fun onDestroy() {
        releaseLocks()
        isRunning = false
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 用 DEFAULT 而不是 LOW：ColorOS 会把 LOW 渠道的常驻通知折叠隐藏
            val channel = NotificationChannel(
                CHANNEL_ID,
                "终端保活",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "保持 SSH 连接不被后台清理"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("QShell 终端运行中")
            .setContentText("当前连接终端数量 ${terminalNames.size}")
            .setShowWhen(false)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "qshell.terminal"
        const val NOTIFICATION_ID = 101

        /// 服务是否在跑（供设置页诊断）
        @Volatile
        var isRunning: Boolean = false

        /// WakeLock 是否持有（供设置页诊断）
        @Volatile
        var holdingWakeLock: Boolean = false

        /// 当前已连接的终端名称（Dart 侧每次连接/断开都会更新）
        @Volatile
        var terminalNames: List<String> = emptyList()
    }
}
