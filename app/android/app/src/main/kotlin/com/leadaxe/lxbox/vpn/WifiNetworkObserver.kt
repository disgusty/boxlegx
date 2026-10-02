package com.leadaxe.lxbox.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel

/**
 * §051 Phase 3 — наблюдает за актуально подключённой Wi-Fi сетью и
 * пишет в `wifi_history` (Dart side через `MethodChannel`) ровно те
 * сети **на которых юзер пробыл ≥ [STICKINESS_THRESHOLD_MS] миллисекунд**.
 *
 * Зачем debounce: без него история засоряется случайными drive-by
 * сетями (магазин на 30 сек, кафе на 5 минут с забытым выходом).
 * 60 сек — отсекает мимохожих, не теряет рабочие/домашние.
 *
 * Фича **opt-in** — гейтится `auto_record_wifi_history` в storage. Без
 * флага observer не регистрируется → нулевая стоимость когда выключено.
 *
 * Lifecycle = process-scope (BoxApplication). При toggle ON/OFF из UI
 * вызываются [start]/[stop] через `WifiHistoryBridge`.
 */
class WifiNetworkObserver(private val ctx: Context) {

    private val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
    private val handler = Handler(Looper.getMainLooper())

    /// `(ssid, bssid)` сеть на которой юзер сейчас «висит». null когда
    /// нет активной wifi-сети или мы только что переключились (старый
    /// pending был cancelled, новый ещё не дождался threshold).
    private var pendingSsid: String? = null
    private var pendingBssid: String = ""
    private var pendingTimer: Runnable? = null
    private var registered = false

    /// lx-legacy: колбэк создаётся только на API 21+ — класс-наследник
    /// NetworkCallback на 4.x не грузится (NoClassDefFoundError в конструкторе).
    private var callback: ConnectivityManager.NetworkCallback? = null

    /// lx-legacy — API < 21: вместо колбэка слушаем CONNECTIVITY_ACTION.
    private var legacyReceiver: LegacyNetwork.ConnectivityReceiver? = null

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun newCallback() = object : ConnectivityManager.NetworkCallback() {
        override fun onCapabilitiesChanged(
            net: Network,
            caps: NetworkCapabilities,
        ) {
            if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return
            // Capabilities update fires при first connect, roaming, SSID
            // change и т.д. — каждый раз дёргаем readWifi и evaluate'им
            // pending timer.
            val state = readWifi() ?: return
            if (state.first.isEmpty()) return
            handlePending(state.first, state.second)
        }

        override fun onLost(net: Network) {
            // Wi-Fi пропал (off, отвалилась сеть). Pending timer
            // отменяем — текущая сеть «не достояла».
            cancelPending()
        }
    }

    /// lx-legacy — аналог колбэка на CONNECTIVITY_ACTION: активная сеть —
    /// подключённый Wi-Fi → evaluate pending; иначе Wi-Fi «не достоял».
    @Suppress("DEPRECATION") // NetworkInfo / TYPE_WIFI — штатный API до 21
    private fun onLegacyConnectivityChange() {
        val info = cm.activeNetworkInfo
        if (info == null || !info.isConnected || info.type != ConnectivityManager.TYPE_WIFI) {
            cancelPending()
            return
        }
        val state = readWifi() ?: return
        if (state.first.isEmpty()) return
        handlePending(state.first, state.second)
    }

    @Synchronized
    fun start() {
        if (registered) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            val r = LegacyNetwork.ConnectivityReceiver { onLegacyConnectivityChange() }
            if (r.register(ctx)) {
                legacyReceiver = r
                registered = true
                Log.d(TAG, "started (legacy CONNECTIVITY_ACTION)")
            }
            return
        }
        // На API 33+ проверяем NEARBY_WIFI_DEVICES, на 29-32 BACKGROUND_LOCATION.
        // Без них readWifi всё равно вернёт null, observer бесполезен — но
        // регистрируем callback чтобы как только permission'ы появятся,
        // дальше работало без re-toggle.
        try {
            val req = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build()
            val cb = newCallback()
            cm.registerNetworkCallback(req, cb)
            callback = cb
            registered = true
            Log.d(TAG, "started")
        } catch (e: SecurityException) {
            Log.w(TAG, "registerNetworkCallback denied: ${e.message}")
        } catch (e: RuntimeException) {
            Log.w(TAG, "registerNetworkCallback failed: ${e.message}")
        }
    }

    @Synchronized
    fun stop() {
        cancelPending()
        if (!registered) return
        legacyReceiver?.unregister(ctx)
        legacyReceiver = null
        val cb = callback
        if (cb != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            runCatching { cm.unregisterNetworkCallback(cb) }
                .onFailure { Log.w(TAG, "unregister failed: ${it.message}") }
        }
        callback = null
        registered = false
        Log.d(TAG, "stopped")
    }

    /// Delegate to `WifiInfoReader` — same defensive read как у sing-box
    /// callback. Returns `(ssid, bssid)` или null при ошибке. Empty ssid
    /// в результате трактуется как "unknown" — calling code (handlePending)
    /// сам skip'нёт.
    private fun readWifi(): Pair<String, String>? {
        return when (val r = WifiInfoReader.read(ctx)) {
            is WifiInfoReader.Result.Success -> r.ssid to r.bssid
            is WifiInfoReader.Result.UnknownSsid -> "" to ""
            else -> null
        }
    }

    /// Если та же сеть что pending — оставляем таймер. Иначе cancel + new.
    private fun handlePending(ssid: String, bssid: String) {
        if (pendingSsid == ssid && pendingBssid == bssid) return
        cancelPending()
        pendingSsid = ssid
        pendingBssid = bssid
        val task = Runnable {
            // Threshold met. Promote через MethodChannel в Dart →
            // SettingsStorage.addToWifiHistory.
            val s = pendingSsid
            val b = pendingBssid
            pendingSsid = null
            pendingTimer = null
            if (s != null && s.isNotEmpty()) {
                WifiHistoryBridge.notifySeen(s, b)
            }
        }
        pendingTimer = task
        handler.postDelayed(task, STICKINESS_THRESHOLD_MS)
    }

    private fun cancelPending() {
        pendingTimer?.let(handler::removeCallbacks)
        pendingTimer = null
        pendingSsid = null
        pendingBssid = ""
    }

    companion object {
        private const val TAG = "WifiNetObserver"

        /// 5 минут — отсекает drive-by сети (магазин, проходящий wifi
        /// на 1-2 мин). Дом / офис / постоянное кафе с сидением за
        /// работой — легко больше 5 минут. Не вытаскиваем константу
        /// в settings — overengineering, default works for everyone.
        const val STICKINESS_THRESHOLD_MS = 300_000L
    }
}

/**
 * Native ↔ Flutter bridge для §051 Phase 3 auto-history. Singleton
 * channel attached в `MainActivity.configureFlutterEngine`. Native
 * side вызывает `notifySeen(ssid, bssid)` → `MethodChannel.invokeMethod`
 * в main looper → Dart handler → `SettingsStorage.addToWifiHistory`.
 */
object WifiHistoryBridge {
    private const val TAG = "WifiHistoryBridge"
    private const val METHOD_ON_WIFI_SEEN = "onWifiSeen"

    @Volatile
    private var channel: MethodChannel? = null
    private val handler = Handler(Looper.getMainLooper())

    fun attach(ch: MethodChannel) {
        channel = ch
    }

    fun detach() {
        channel = null
    }

    fun notifySeen(ssid: String, bssid: String) {
        val ch = channel ?: run {
            Log.w(TAG, "notifySeen but channel not attached, dropped")
            return
        }
        handler.post {
            ch.invokeMethod(
                METHOD_ON_WIFI_SEEN,
                mapOf("ssid" to ssid, "bssid" to bssid),
            )
        }
    }
}
