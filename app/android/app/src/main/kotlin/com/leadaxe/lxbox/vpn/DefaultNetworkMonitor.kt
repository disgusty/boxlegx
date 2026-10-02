package com.leadaxe.lxbox.vpn

import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.nekohasekai.libbox.InterfaceUpdateListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.net.NetworkInterface

object DefaultNetworkMonitor {
    /// §087 — окно debounce для force-reset на смену интерфейса (мс). Android
    /// при переходе шлёт пачку callback'ов; копим тишину и ресетим один раз.
    private const val RESET_DEBOUNCE_MS = 1500L

    var defaultNetwork: Network? = null
    private var listener: InterfaceUpdateListener? = null
    private var scope: CoroutineScope? = null

    /// §087 — callback на genuine смену интерфейса (BoxService → resetNetwork()).
    private var onNetworkSwitch: (() -> Unit)? = null

    /// §087 — имя последнего реального интерфейса (baseline для детекта смены).
    /// `@Volatile`: пишется из notifySync (attach-thread) и checkUpdate (actor).
    @Volatile
    private var lastIfName: String? = null
    private var resetJob: Job? = null

    /// lx-legacy — подписка на CONNECTIVITY_ACTION вместо NetworkCallback (API < 21).
    private var legacyReceiver: LegacyNetwork.ConnectivityReceiver? = null

    suspend fun start(scope: CoroutineScope, onNetworkSwitch: () -> Unit) {
        this.scope = scope
        this.onNetworkSwitch = onNetworkSwitch
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            // lx-legacy: `Network` нет — `defaultNetwork` остаётся null, ядру
            // отдаём имя/индекс интерфейса с дефолтным маршрутом (LegacyNetwork).
            val r = LegacyNetwork.ConnectivityReceiver { checkLegacyUpdate() }
            if (r.register(BoxApplication.application)) legacyReceiver = r
            Log.i("LxBoxNet", "[init] legacy defaultInterface=${LegacyNetwork.defaultInterface()}")
            return
        }
        // §119 — seed `defaultNetwork` из getActiveNetwork(), но НИКОГДА не нашим
        // же VPN. getActiveNetwork() возвращает per-app default, который штатно
        // ВКЛЮЧАЕТ наш tun, если VPN уже поднят к моменту start() (док:
        // ConnectivityManager.getActiveNetwork / registerDefaultNetworkCallback —
        // «may be ... a VPN that applies to the application»). Если пустить такой
        // seed в LocalResolver, DnsResolver.query(VPN) уйдёт обратно в tun → loop.
        // NOT_VPN из NetworkRequest сюда НЕ применяется (это прямой геттер, не
        // запрос), поэтому фильтруем явно. Callback-источник (ниже) уже отфильтрован
        // NOT_VPN'ом самого NetworkRequest и здесь перезапишет seed.
        defaultNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            BoxApplication.connectivity.activeNetwork?.takeUnless(::isVpn)
        } else null
        logDefaultNetwork("init", defaultNetwork)

        DefaultNetworkListener.start(this) {
            defaultNetwork = it
            checkUpdate(it)
        }

        if (defaultNetwork == null && Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            defaultNetwork = DefaultNetworkListener.get()
        }
    }

    suspend fun stop() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            legacyReceiver?.unregister(BoxApplication.application)
            legacyReceiver = null
        } else {
            DefaultNetworkListener.stop(this)
        }
        resetJob?.cancel()
        resetJob = null
        onNetworkSwitch = null
        lastIfName = null
        scope = null
        listener = null
    }

    fun setListener(listener: InterfaceUpdateListener?) {
        this.listener = listener
        if (listener != null) notifySync(defaultNetwork, listener)
    }

    /// §141 P1.1b — JNI no-throw (§050/§128): `notifySync` вызывается из
    /// `setListener`, который сам — JNI-колбэк от Go-ядра (`startDefault-
    /// InterfaceMonitor`). Любой throw отсюда (`getLinkProperties` /
    /// `getByName` / `updateDefaultInterface`) пролетел бы через JNI =
    /// `Runtime::Abort` процесса. Всё тело обёрнуто во внешний runCatching;
    /// на сбой — fail-safe «нет интерфейса» (тоже в runCatching, т.к. сам
    /// updateDefaultInterface — JNI-вызов и тоже может бросить).
    ///
    /// `Thread.sleep` сохранён, но осознанно: метод синхронный (ядру нужен
    /// первичный ifIndex немедленно при подписке), а интерфейс после смены сети
    /// появляется в `NetworkInterface.getByName` с задержкой. Полный async-
    /// рефакторинг (через scope, как в `checkUpdate`) меняет контракт первичной
    /// нотификации → отдельная device-verified задача.
    private fun notifySync(network: Network?, listener: InterfaceUpdateListener) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            notifyLegacySync(listener)
            return
        }
        runCatching {
            if (network == null) {
                listener.updateDefaultInterface("", -1, false, false)
                return@runCatching
            }
            val linkProps = BoxApplication.connectivity.getLinkProperties(network)
            val ifName = linkProps?.interfaceName ?: ""
            if (ifName.isEmpty()) {
                listener.updateDefaultInterface("", -1, false, false)
                return@runCatching
            }
            for (attempt in 0 until 10) {
                try {
                    val ni = NetworkInterface.getByName(ifName) ?: continue
                    lastIfName = ifName  // §087 — baseline для детекта последующих смен
                    listener.updateDefaultInterface(ifName, ni.index, false, false)
                    return@runCatching
                } catch (_: Exception) {
                    Thread.sleep(50)
                }
            }
            listener.updateDefaultInterface("", -1, false, false)
        }.onFailure { e ->
            Log.e("LxBoxNet", "notifySync failed (fail-safe empty interface)", e)
            runCatching { listener.updateDefaultInterface("", -1, false, false) }
        }
    }

    /// lx-legacy — первичная нотификация на API < 21 (тот же JNI no-throw
    /// контракт, что у [notifySync]).
    private fun notifyLegacySync(listener: InterfaceUpdateListener) {
        runCatching {
            val iface = LegacyNetwork.defaultInterface()
            if (iface == null) {
                listener.updateDefaultInterface("", -1, false, false)
            } else {
                lastIfName = iface.name  // §087 — baseline
                listener.updateDefaultInterface(iface.name, iface.index, false, false)
            }
        }.onFailure { e ->
            Log.e("LxBoxNet", "notifyLegacySync failed (fail-safe empty interface)", e)
            runCatching { listener.updateDefaultInterface("", -1, false, false) }
        }
    }

    /// lx-legacy — аналог [checkUpdate] на CONNECTIVITY_ACTION (API < 21).
    /// Broadcast приходит раньше, чем маршрут попадает в /proc/net/route, —
    /// пока сеть подключена, а маршрута нет, коротко ждём (как retry в checkUpdate).
    private fun checkLegacyUpdate() {
        val l = listener ?: return
        val s = scope ?: return  // service already dead — don't touch Go objects
        s.launch(Dispatchers.IO) {
            var iface = LegacyNetwork.defaultInterface()
            var attempt = 0
            while (iface == null && attempt++ < 10 && LegacyNetwork.isConnected()) {
                delay(100)
                iface = LegacyNetwork.defaultInterface()
            }
            Log.i("LxBoxNet", "[update] legacy defaultInterface=$iface")
            if (iface == null) {
                // §087 — disconnect: baseline lastIfName не трогаем, не ресетим.
                runCatching { l.updateDefaultInterface("", -1, false, false) }
                return@launch
            }
            maybeResetOnSwitch(iface.name, s)  // §087
            lastIfName = iface.name
            runCatching { l.updateDefaultInterface(iface.name, iface.index, false, false) }
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun checkUpdate(network: Network?) {
        val l = listener ?: return
        val s = scope ?: return  // service already dead — don't touch Go objects
        if (network == null) {
            // §087 — disconnect: НЕ трогаем lastIfName (сохраняем baseline, чтобы
            // switch через "" к ДРУГОМУ интерфейсу всё равно детектился) и НЕ
            // ресетим (нет сети для re-dial).
            s.launch(Dispatchers.IO) {
                runCatching { l.updateDefaultInterface("", -1, false, false) }
            }
            return
        }
        logDefaultNetwork("update", network)
        val linkProps = BoxApplication.connectivity.getLinkProperties(network)
        val ifName = linkProps?.interfaceName ?: return
        for (attempt in 0 until 10) {
            try {
                val ni = NetworkInterface.getByName(ifName) ?: continue
                maybeResetOnSwitch(ifName, s)  // §087
                lastIfName = ifName
                s.launch(Dispatchers.IO) {
                    runCatching { l.updateDefaultInterface(ifName, ni.index, false, false) }
                }
                return
            } catch (_: Exception) {
                Thread.sleep(100)
            }
        }
    }

    /// §087 — force-reset стейл-соединений на genuine смену интерфейса.
    ///
    /// `checkUpdate` дёргается из `DefaultNetworkListener` на ЛЮБОЙ
    /// `onCapabilitiesChanged`, поэтому reset только на реальный switch:
    /// `prev → new`, оба непустые и разные. НЕ на первый connect (prev пуст),
    /// capability-update (prev == new) или disconnect (см. ветку network==null).
    /// Иначе — регрессия класса sing-box #3400 (убить весь TCP на каждый чих).
    /// Debounced: пачка переходов схлопывается в один resetNetwork().
    private fun maybeResetOnSwitch(newIfName: String, s: CoroutineScope) {
        val prev = lastIfName
        if (prev.isNullOrEmpty() || newIfName.isEmpty() || prev == newIfName) return
        resetJob?.cancel()
        resetJob = s.launch(Dispatchers.IO) {
            delay(RESET_DEBOUNCE_MS)
            runCatching { onNetworkSwitch?.invoke() }
        }
    }

    /// §119 — true, если у network есть VPN-транспорт (наш собственный tun).
    /// Источник истины: ConnectivityManager.getActiveNetwork() и
    /// registerDefaultNetworkCallback() отдают per-app default, который штатно
    /// включает VPN, применённый к процессу — это AOSP-поведение, не баг прошивки.
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun isVpn(network: Network): Boolean =
        BoxApplication.connectivity.getNetworkCapabilities(network)
            ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true

    /// §119 — постоянная диагностика: какой `defaultNetwork` поймали — VPN или
    /// underlying-физика. Репро в проде у нас нет, поэтому лог безусловный
    /// (`Log.i`, без debug-gating): следующий field-report диагностируется сразу.
    /// Читать: `adb logcat -s LxBoxNet`.
    ///
    /// TECH DEBT (TD-119-1): безусловность временна. После подтверждения фикса на
    /// реальном устройстве — свернуть (revert) или перенести в debug-форму
    /// (`Log.isLoggable("LxBoxNet", Log.INFO)`). См. docs/spec/tasks/119, раздел
    /// «Технический долг».
    ///
    /// Ожидаемые значения `vpn`:
    ///   [init]   — ПОСЛЕ §119-фильтра (`takeUnless(::isVpn)`) всегда `false`;
    ///              `true` здесь означало бы, что фильтр обойдён — копать.
    ///   [update] — приходит из NetworkRequest с NOT_VPN (default-capability,
    ///              API ≥ 28), поэтому штатно `false`. `true` — аномалия:
    ///              underlying-сеть не сматчилась, выбран VPN вопреки NOT_VPN.
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun logDefaultNetwork(where: String, network: Network?) {
        runCatching {
            if (network == null) {
                Log.i("LxBoxNet", "[$where] defaultNetwork=null")
                return
            }
            val ifName = BoxApplication.connectivity
                .getLinkProperties(network)?.interfaceName ?: "?"
            Log.i("LxBoxNet", "[$where] defaultNetwork iface=$ifName vpn=${isVpn(network)}")
        }
    }
}
