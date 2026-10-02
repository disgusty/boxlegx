package com.leadaxe.lxbox.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log
import java.io.File
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * lx-legacy — сетевые примитивы для API < 21, где нет `Network`,
 * `NetworkCallback`, `LinkProperties` и `NetworkCapabilities`.
 *
 * - Дефолтный интерфейс — из IPv4-таблицы маршрутов `/proc/net/route`
 *   (на 4.x читается без root): строка с Destination и Mask `00000000`,
 *   флагом RTF_UP и минимальной метрикой. tun-интерфейсы (в т.ч. наш
 *   собственный) и loopback пропускаются: на 4.x маршруты VPN лежат в той же
 *   main-таблице. Таблица недоступна — первый поднятый не-loopback,
 *   не-tun интерфейс с IPv4-адресом.
 * - Индекс интерфейса: `NetworkInterface.getIndex` — с API 19, ниже —
 *   `/sys/class/net/<имя>/ifindex`.
 * - Смена сети — sticky-broadcast `CONNECTIVITY_ACTION` ([ConnectivityReceiver]).
 */
internal object LegacyNetwork {
    private const val TAG = "LxBoxNet"

    /// RTF_UP из <linux/route.h>.
    private const val RTF_UP = 0x1

    // IFF_* из <linux/if.h>: android.system.OsConstants — только с API 21.
    const val IFF_UP = 0x1
    const val IFF_LOOPBACK = 0x8
    const val IFF_POINTOPOINT = 0x10
    const val IFF_RUNNING = 0x40
    const val IFF_MULTICAST = 0x1000

    data class Iface(val name: String, val index: Int)

    /// Текущий дефолтный (underlying) интерфейс или null, если сети нет.
    fun defaultInterface(): Iface? {
        val name = defaultRouteInterface() ?: fallbackInterface() ?: return null
        val ni = runCatching { NetworkInterface.getByName(name) }.getOrNull() ?: return null
        val index = indexOf(ni)
        if (index <= 0) return null
        return Iface(name, index)
    }

    /// tun* — наш (или чужой) VPN; в underlying-кандидаты не берём.
    fun isTun(name: String): Boolean = name.startsWith("tun")

    /// Есть ли сейчас подключённая сеть (CONNECTIVITY_ACTION приходит раньше,
    /// чем маршрут попадает в таблицу, — по этому признаку решаем, ждать ли).
    fun isConnected(): Boolean = runCatching {
        @Suppress("DEPRECATION")
        BoxApplication.connectivity.activeNetworkInfo?.isConnected == true
    }.getOrDefault(false)

    fun indexOf(ni: NetworkInterface): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) return ni.index
        return runCatching {
            File("/sys/class/net/${ni.name}/ifindex").readText().trim().toInt()
        }.getOrDefault(-1)
    }

    private fun defaultRouteInterface(): String? = runCatching {
        var best: String? = null
        var bestMetric = Int.MAX_VALUE
        // Формат: Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT;
        // адреса — hex в порядке байт ядра, первая строка — заголовок.
        File("/proc/net/route").readLines().drop(1).forEach { line ->
            val cols = line.trim().split(Regex("\\s+"))
            if (cols.size < 8) return@forEach
            val name = cols[0]
            if (cols[1] != "00000000" || cols[7] != "00000000") return@forEach
            val flags = cols[3].toIntOrNull(16) ?: return@forEach
            if (flags and RTF_UP == 0) return@forEach
            if (name == "lo" || isTun(name)) return@forEach
            val metric = cols[6].toIntOrNull() ?: 0
            if (metric < bestMetric) {
                best = name
                bestMetric = metric
            }
        }
        best
    }.onFailure { Log.w(TAG, "legacy: /proc/net/route unreadable: ${it.message}") }.getOrNull()

    private fun fallbackInterface(): String? = runCatching {
        NetworkInterface.getNetworkInterfaces()?.toList().orEmpty().firstOrNull { ni ->
            ni.isUp && !ni.isLoopback && !isTun(ni.name) &&
                ni.inetAddresses.toList().any { it is Inet4Address }
        }?.name
    }.getOrNull()

    /// Подписка на `CONNECTIVITY_ACTION` (API < 21: NetworkCallback'а нет).
    /// Broadcast sticky — первый onReceive приходит сразу при регистрации,
    /// это и есть начальный снимок. onReceive — на main looper.
    class ConnectivityReceiver(private val onChange: () -> Unit) : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            runCatching(onChange)
                .onFailure { Log.w(TAG, "legacy: connectivity change handler failed: ${it.message}") }
        }

        fun register(ctx: Context): Boolean = runCatching {
            @Suppress("DEPRECATION")
            ctx.registerReceiver(this, IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION))
            Unit
        }.onFailure { Log.w(TAG, "legacy: register CONNECTIVITY_ACTION failed: ${it.message}") }
            .isSuccess

        fun unregister(ctx: Context) {
            runCatching { ctx.unregisterReceiver(this) }
        }
    }
}
