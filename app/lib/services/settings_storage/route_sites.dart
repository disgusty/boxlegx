part of '../settings_storage.dart';

// Маршрутизация сайтов (Routing → Sites) — доменный split-tunneling по
// образцу Amnezia VPN. Форма хранения — зеркало `tun_apps`:
//   `route_sites: {mode: off|allow|deny, sites: [..]}`
// Записи — домены (матчат и поддомены) и IP/CIDR. Сборка переводит их в
// route-правило (post-step applyRouteSites).

Future<RouteSitesConfig> _getRouteSites() async {
  final data = await _load();
  final raw = data['route_sites'];
  if (raw is Map<String, dynamic>) {
    final mode = raw['mode'];
    final sites = (raw['sites'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    if (mode is String && RouteSitesConfig.isValidMode(mode)) {
      return RouteSitesConfig(mode: mode, sites: sites);
    }
  }
  return const RouteSitesConfig(mode: 'off', sites: <String>[]);
}

Future<void> _setRouteSites(RouteSitesConfig cfg, {bool flush = true}) async {
  if (!RouteSitesConfig.isValidMode(cfg.mode)) {
    throw ArgumentError('route_sites.mode must be off|allow|deny: ${cfg.mode}');
  }
  final dedup = <String>{};
  for (final s in cfg.sites) {
    final n = RouteSitesConfig.normalize(s);
    if (n != null) dedup.add(n);
  }
  final data = await _load();
  data['route_sites'] = {
    'mode': cfg.mode,
    'sites': dedup.toList()..sort(),
  };
  SettingsStorage._cache = data;
  SettingsStorage.markConfigDirty();
  if (flush) await _save();
}

/// Typed wrapper над `route_sites`.
class RouteSitesConfig {
  const RouteSitesConfig({required this.mode, required this.sites});

  /// `"off"` | `"allow"` (только эти сайты через VPN) | `"deny"` (эти сайты
  /// мимо VPN).
  final String mode;
  final List<String> sites;

  static bool isValidMode(String mode) =>
      mode == 'off' || mode == 'allow' || mode == 'deny';

  bool get isOff => mode == 'off';
  bool get isAllow => mode == 'allow';
  bool get isDeny => mode == 'deny';

  RouteSitesConfig copyWith({String? mode, List<String>? sites}) =>
      RouteSitesConfig(mode: mode ?? this.mode, sites: sites ?? this.sites);

  Map<String, Object?> toJson() => {'mode': mode, 'sites': sites};

  static final _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(/\d{1,2})?$');
  static final _ipv6 = RegExp(r'^[0-9a-f:]+:[0-9a-f:.]*(/\d{1,3})?$');
  static final _domain = RegExp(
      r'^(?=.{1,253}$)([a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9])?\.)*[a-z0-9-]{1,63}$');

  /// Приводит ввод пользователя к записи списка: `https://www.Example.com:443/x`
  /// → `www.example.com`, `*.example.com` → `example.com`, `10.0.0.0/8` как есть.
  /// `null` — мусор.
  static String? normalize(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return null;
    final scheme = s.indexOf('://');
    if (scheme >= 0) s = s.substring(scheme + 3);
    final at = s.lastIndexOf('@');
    if (at >= 0) s = s.substring(at + 1);
    final cut = s.indexOf(RegExp(r'[/?#]'));
    // `/` в IP-записи — префикс CIDR, а не путь.
    if (cut >= 0 && !(_ipv4.hasMatch(s) || _ipv6.hasMatch(s))) {
      s = s.substring(0, cut);
    }
    if (s.startsWith('[')) {
      // [v6]:port
      final end = s.indexOf(']');
      if (end < 0) return null;
      s = s.substring(1, end);
    } else if (':'.allMatches(s).length == 1) {
      s = s.substring(0, s.indexOf(':'));
    }
    while (s.startsWith('*.') || s.startsWith('.')) {
      s = s.substring(s.startsWith('*.') ? 2 : 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.isEmpty) return null;
    if (isIp(s)) return s;
    // `300.1.1.1` — не домен, а битый IP.
    if (RegExp(r'^[\d./]+$').hasMatch(s)) return null;
    return _domain.hasMatch(s) ? s : null;
  }

  /// IP-адрес или CIDR (IPv4/IPv6).
  static bool isIp(String s) {
    final m = _ipv4.firstMatch(s);
    if (m != null) {
      for (var i = 1; i <= 4; i++) {
        if (int.parse(m.group(i)!) > 255) return false;
      }
      final p = m.group(5);
      return p == null || int.parse(p.substring(1)) <= 32;
    }
    return _ipv6.hasMatch(s);
  }

  /// Ввод пользователя → записи: разделители — пробелы, запятые, `;`.
  static List<String> splitInput(String text) =>
      text.split(RegExp(r'[\s,;]+')).where((s) => s.isNotEmpty).toList();

  /// Разбор файла списка сайтов: JSON Amnezia VPN (`[{"hostname", "ip"}]`),
  /// JSON-массив строк (или `{"sites": [...]}`) либо простой текст — по
  /// записи в строке, `#` — комментарий. Записи не нормализуются.
  static List<String> parseList(String raw) {
    final text = raw.trim();
    if (text.startsWith('[') || text.startsWith('{')) {
      try {
        var decoded = jsonDecode(text);
        if (decoded is Map && decoded['sites'] is List) {
          decoded = decoded['sites'];
        }
        if (decoded is List) {
          final out = <String>[];
          for (final e in decoded) {
            if (e is String) {
              out.add(e);
            } else if (e is Map) {
              final host = e['hostname'];
              final ip = e['ip'];
              if (host is String && host.trim().isNotEmpty) {
                out.add(host);
              } else if (ip is String && ip.trim().isNotEmpty) {
                out.add(ip);
              }
            }
          }
          return out;
        }
      } on FormatException {
        // Не JSON — читаем как текст ниже.
      }
    }
    return [
      for (final line in const LineSplitter().convert(text))
        ...splitInput(line.split('#').first),
    ];
  }

  /// Экспорт в формате Amnezia VPN: массив `{hostname, ip}`.
  static String toAmneziaJson(List<String> sites) =>
      const JsonEncoder.withIndent('    ').convert([
        for (final s in sites) {'hostname': s, 'ip': ''},
      ]);

  /// sing-box требует CIDR в `ip_cidr`: голый адрес → /32 или /128.
  static String toCidr(String ip) =>
      ip.contains('/') ? ip : (ip.contains(':') ? '$ip/128' : '$ip/32');
}
