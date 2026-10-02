part of '../post_steps.dart';

/// Post-step: маршрутизация сайтов (Routing → Sites), аналог site-based
/// split-tunneling Amnezia VPN. Работает внутри ядра (route-правило), а не
/// через VpnService — поэтому действует и в Proxy-режиме.
///
/// Mode → sing-box config:
/// - `off`   → ничего не пишем.
/// - `deny`  → правило «сайты списка → `direct-out`» (мимо VPN).
/// - `allow` → правило «сайты списка → прежний `route.final`» и
///             `route.final = direct-out`: всё, что не в списке, идёт напрямую.
///
/// Домены матчатся через `domain_suffix` (домен и все его поддомены),
/// IP/CIDR — через `ip_cidr`. Правило встаёт сразу за головными
/// служебными правилами (`sniff`/`hijack-dns`/`resolve`/`route-options`):
/// домен известен только после sniff, а пользовательские правила ниже
/// не должны перехватывать сайты из списка.
///
/// Вызывается ПОСЛЕ резолва `route.final` в [buildConfig].
void applyRouteSites(Map<String, dynamic> config, RouteSitesConfig sites) {
  if (sites.isOff || sites.sites.isEmpty) return;
  final route = config['route'];
  if (route is! Map<String, dynamic>) return;

  final domains = <String>[];
  final cidrs = <String>[];
  for (final s in sites.sites) {
    if (RouteSitesConfig.isIp(s)) {
      cidrs.add(RouteSitesConfig.toCidr(s));
    } else {
      domains.add(s);
    }
  }
  if (domains.isEmpty && cidrs.isEmpty) return;

  final String target;
  if (sites.isDeny) {
    target = kDirectOutboundTag;
  } else {
    target = _takeProxyFinal(route);
  }

  final rule = <String, dynamic>{
    if (domains.isNotEmpty) 'domain_suffix': domains,
    if (cidrs.isNotEmpty) 'ip_cidr': cidrs,
    'action': 'route',
    'outbound': target,
  };

  _insertAfterLeadingRules(route, rule);
}

/// Вставляет [rule] сразу за головными служебными правилами
/// (`sniff`/`hijack-dns`/`resolve`/`route-options`) — до пользовательских.
void _insertAfterLeadingRules(
    Map<String, dynamic> route, Map<String, dynamic> rule) {
  final rules = route['rules'] is List
      ? List<dynamic>.from(route['rules'] as List)
      : <dynamic>[];
  const leading = {'sniff', 'hijack-dns', 'resolve', 'route-options'};
  var at = 0;
  while (at < rules.length) {
    final r = rules[at];
    if (r is Map && leading.contains(r['action'])) {
      at++;
    } else {
      break;
    }
  }
  rules.insert(at, rule);
  route['rules'] = rules;
}

/// Цель «через VPN» для режима allow-list: прежний `route.final`, если он
/// не direct/block, иначе `vpn-1`. Переводит `route.final` на direct-out.
String _takeProxyFinal(Map<String, dynamic> route) {
  final prevFinal = route['final'];
  route['final'] = kDirectOutboundTag;
  return prevFinal is String &&
          prevFinal.isNotEmpty &&
          prevFinal != kDirectOutboundTag &&
          prevFinal != kBlockOutboundTag
      ? prevFinal
      : 'vpn-1';
}
