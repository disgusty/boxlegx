import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/app_log.dart';

/// lx-legacy: сведения о старых версиях Android (4.2–4.4, API 17–19) и
/// обходы их ограничений.
///
/// - Per-app VPN (`VpnService.Builder.addAllowedApplication`) появился в
///   API 21 — на старых версиях «Приложения в туннеле» делаются правилами
///   ядра (`package_name`), см. [applyTunPackages].
/// - Камера-плагин QR-сканера требует API 21 — сканер скрыт.
/// - В системном хранилище корневых сертификатов до Android 7.1.1 (API 25)
///   нет ISRG Root X1 (Let's Encrypt): HTTPS-клиент Dart получает встроенный
///   набор Mozilla (`assets/certs/cacert.pem`), ядро — `certificate.store:
///   mozilla`.
abstract final class LegacyPlatform {
  /// `Build.VERSION.SDK_INT`; 0 — не Android или ещё не прочитан.
  static int sdkInt = 0;

  /// Android до 5.0 — нет per-app VPN, камеры для сканера и т.п.
  static bool get isPreLollipop =>
      Platform.isAndroid && sdkInt > 0 && sdkInt < 21;

  /// Системные корни без ISRG Root X1 (до Android 7.1.1).
  static bool get needsBundledRoots =>
      Platform.isAndroid && sdkInt > 0 && sdkInt < 25;

  /// Вызывается в main() до runApp: читает SDK_INT и при необходимости
  /// подключает встроенные корневые сертификаты ко всем HttpClient.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (e) {
      AppLog.I.warning('LegacyPlatform: SDK_INT unavailable: $e');
      return;
    }
    if (!needsBundledRoots) return;
    try {
      final pem = await rootBundle.load('assets/certs/cacert.pem');
      final bytes = pem.buffer.asUint8List(pem.offsetInBytes, pem.lengthInBytes);
      HttpOverrides.global = _BundledRootsOverrides(bytes);
      AppLog.I.info('LegacyPlatform: API $sdkInt — bundled Mozilla roots on');
    } catch (e) {
      AppLog.I.warning('LegacyPlatform: bundled roots failed: $e');
    }
  }
}

/// Все `HttpClient()` (и `http.Client()` поверх них) доверяют системным
/// корням ПЛЮС набору Mozilla.
final class _BundledRootsOverrides extends HttpOverrides {
  _BundledRootsOverrides(this._pem);

  final List<int> _pem;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final ctx = context ?? SecurityContext(withTrustedRoots: true);
    try {
      ctx.setTrustedCertificatesBytes(_pem);
    } on TlsException {
      // Уже добавлены в этот контекст — не ошибка.
    }
    return super.createHttpClient(ctx);
  }
}
