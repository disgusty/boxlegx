part of '../post_steps.dart';

/// Post-step: §046 — OS-level split-tunneling. Подставляет `include_package`
/// или `exclude_package` в `inbound[type=tun]` на основе `tun_apps` storage.
///
/// Mode → sing-box config:
/// - `off`        → ничего не пишем (sing-box default = все apps через tun)
/// - `allow`      → `tun.include_package = packages` (только эти через tun)
/// - `deny`       → `tun.exclude_package = packages` (все КРОМЕ этих)
///
/// libbox потом читает эти поля из config и передаёт в native слой
/// (`BoxVpnService.openTun` → `addAllowedApplication`/`addDisallowedApplication`,
/// ~`BoxVpnService.kt:208-211`). Применяется на `builder.establish()` — нужен
/// FULL VPN restart, light reload не работает.
///
/// Если `mode != off` но `packages` пустой — silently no-op (нечего apply'ить).
/// Если в config нет tun-inbound — silently no-op (некуда apply'ить).
///
/// lx-legacy: [viaRules] — Android < 5.0, где у VpnService нет per-app API.
/// Список уходит в route-правило ядра `package_name` (владельца соединения
/// ядро находит по /proc/net): deny — эти приложения на direct-out, allow —
/// они на прежний final, а final — direct-out. Трафик исключённых приложений
/// при этом проходит через tun, но не через VPN-сервер.
void applyTunPackages(Map<String, dynamic> config, TunAppsConfig tunApps,
    {bool viaRules = false}) {
  if (tunApps.isOff || tunApps.packages.isEmpty) return;
  if (viaRules) {
    final route = config['route'];
    if (route is! Map<String, dynamic>) return;
    _insertAfterLeadingRules(route, <String, dynamic>{
      'package_name': List<String>.from(tunApps.packages),
      'action': 'route',
      'outbound':
          tunApps.isDeny ? kDirectOutboundTag : _takeProxyFinal(route),
    });
    return;
  }

  final inbounds = config['inbounds'];
  if (inbounds is! List) return;

  Map<String, dynamic>? tun;
  for (final i in inbounds) {
    if (i is Map<String, dynamic> && i['type'] == 'tun') {
      tun = i;
      break;
    }
  }
  if (tun == null) return;

  final field = tunApps.isAllow ? 'include_package' : 'exclude_package';
  tun[field] = List<String>.from(tunApps.packages);
}
