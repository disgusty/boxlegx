import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legacy/legacy_platform.dart';

/// Стиль интерфейса (App Settings → Appearance).
enum UiStyle {
  /// Material Design 3 — исходный вид приложения (по умолчанию).
  material3,

  /// Material Design 1 (2014, Android 5.0 Lollipop).
  material1,

  /// Holo (Android 4.0 ICS — 4.4 KitKat).
  holo,
}

/// Глобальное состояние внешнего вида: стиль интерфейса и упрощённые
/// анимации. Хранится в SharedPreferences рядом с `app_theme_mode`
/// ([ThemeNotifier]) — это настройки устройства, не профиля, и в бэкап не идут.
class AppStyle extends ChangeNotifier {
  AppStyle() {
    ready = _load();
  }

  /// Завершается после чтения prefs; main() ждёт его до runApp, чтобы
  /// первый кадр не мигал стилем по умолчанию.
  late final Future<void> ready;

  static const _styleKey = 'app_ui_style';
  static const _motionKey = 'app_reduce_motion';

  UiStyle _style = UiStyle.material3;
  UiStyle get style => _style;

  /// Упрощённые анимации: мгновенные переходы между экранами, без
  /// шейдерной «искры» нажатия (InkSparkle), без постоянно крутящихся
  /// индикаторов. По умолчанию ВКЛ — форк ориентирован на слабые устройства.
  bool _reduceMotion = true;
  bool get reduceMotion => _reduceMotion;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_styleKey);
      _style = UiStyle.values.firstWhere(
        (s) => s.name == stored,
        // lx-legacy: на Android 4.x по умолчанию — родной для них Holo.
        orElse: () => LegacyPlatform.isPreLollipop
            ? UiStyle.holo
            : UiStyle.material3,
      );
      _reduceMotion = prefs.getBool(_motionKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Prefs недоступны — остаются дефолты.
    }
  }

  Future<void> setStyle(UiStyle style) async {
    if (style == _style) return;
    _style = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, style.name);
  }

  Future<void> setReduceMotion(bool value) async {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_motionKey, value);
  }

  /// Длительность анимации с учётом [reduceMotion]: при упрощённых
  /// анимациях — мгновенно.
  Duration motion(Duration normal) => _reduceMotion ? Duration.zero : normal;
}

final appStyle = AppStyle();
