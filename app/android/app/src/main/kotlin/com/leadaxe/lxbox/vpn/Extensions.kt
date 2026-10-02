package com.leadaxe.lxbox.vpn

import android.app.PendingIntent
import android.net.IpPrefix
import android.os.Build
import androidx.annotation.RequiresApi
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.StringIterator
import java.net.InetAddress
import kotlin.coroutines.Continuation

fun StringIterator.toList(): List<String> {
    return mutableListOf<String>().apply {
        while (hasNext()) {
            add(next())
        }
    }
}

/// lx-legacy: `PendingIntent.FLAG_IMMUTABLE` появился в API 23 — ниже флаг
/// системе неизвестен, не передаём его (требование неизменяемости — с API 31).
val PI_FLAG_IMMUTABLE: Int
    get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
fun RoutePrefix.toIpPrefix(): IpPrefix = IpPrefix(InetAddress.getByName(address()), prefix())

/// §049 F26 fix: helper для DnsResolver.Callback'ов в LocalResolver. Защита от
/// двойного resume (если sing-box ctx.cancel + onError одновременно отстреляли).
/// Identical к reference's `ktx/Continuations.kt`.
fun <T> Continuation<T>.tryResumeWithException(exception: Throwable) {
    try {
        resumeWith(Result.failure(exception))
    } catch (_: IllegalStateException) {
    }
}
