import 'package:flutter/material.dart';

import 'accent.dart';
import 'app_style.dart';
import 'holo.dart';

/// Темы трёх стилей интерфейса.
///
/// - Material 3 — исходный вид L×Box: схема из акцентного цвета (seed), фон и
///   поверхности — всегда от исходного Indigo.
/// - Material 1 — Material Design 2014 (Android 5.0): один акцентный цвет на
///   панель приложения и элементы, типографика material2014, тени, углы 2dp,
///   волна InkRipple. Фон — палитра Grey MD 2014, от акцента не зависит.
/// - Holo — Android 4.x (Theme.Holo / Theme.Holo.Light), по ресурсам AOSP
///   4.2 (см. holo.dart): градиентный фон окна, прозрачная панель действий с
///   голубой полосой, вкладки с голубым индикатором, плоские элементы,
///   подсветка нажатия без волны. Акцент не используется.
///
/// lx-legacy: вариант для Flutter 3.13 (MaterialState*, ColorScheme с
/// background/surfaceVariant, *Theme вместо *ThemeData).
ThemeData buildAppTheme(
  UiStyle style,
  Brightness brightness, {
  required bool reduceMotion,
  MaterialColor accent = AccentPalette.defaultColor,
}) {
  final holo = style == UiStyle.holo;
  final theme = switch (style) {
    UiStyle.material3 => _material3(brightness, reduceMotion, accent),
    UiStyle.material1 => _material1(brightness, accent),
    UiStyle.holo => _holo(brightness),
  };
  if (!reduceMotion) return theme;
  // Упрощённые анимации: экраны открываются мгновенно — без перерисовки
  // двух страниц с прозрачностью/сдвигом в каждом кадре перехода.
  final instant = _InstantPageTransitionsBuilder(holo: holo);
  return theme.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: instant,
    }),
  );
}

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder({required this.holo});

  /// Holo: страница рисует фон окна сама (Scaffold прозрачный).
  final bool holo;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      holo ? HoloWindowBackground(child: child) : child;
}

// ─────────────────────────────── Material 3 ───────────────────────────────

ThemeData _material3(
    Brightness brightness, bool reduceMotion, MaterialColor accent) {
  // Фон и поверхности — от исходного Indigo: акцент меняет только цвета
  // элементов, фон остаётся прежним.
  final base =
      ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: brightness);
  final scheme = accent == Colors.indigo
      ? base
      : ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
          .copyWith(
          background: base.background,
          onBackground: base.onBackground,
          surface: base.surface,
          onSurface: base.onSurface,
          surfaceVariant: base.surfaceVariant,
          onSurfaceVariant: base.onSurfaceVariant,
          surfaceTint: base.surfaceTint,
          inverseSurface: base.inverseSurface,
          onInverseSurface: base.onInverseSurface,
        );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // InkSparkle (дефолт M3 на Android) — фрагментный шейдер на каждое
    // нажатие; на слабых GPU заметно дороже обычной волны.
    splashFactory: reduceMotion ? InkRipple.splashFactory : null,
  );
}

// ─────────────────────────────── Material 1 ───────────────────────────────

ThemeData _material1(Brightness brightness, MaterialColor accent) {
  final dark = brightness == Brightness.dark;
  final onAccent = AccentPalette.needsDarkForeground(accent)
      ? const Color(0xDE000000)
      : Colors.white;
  // Один общий цвет: панель приложения и элементы. На тёмном фоне элементы —
  // светлее (оттенок 300), панель — темнее (700), как в тёмной теме MD 2014.
  final bar = dark ? accent.shade700 : accent.shade500;
  final onBar = dark ? Colors.white : onAccent;
  final element = dark ? accent.shade300 : accent.shade500;
  final onElement = dark ? const Color(0xDE000000) : onAccent;

  final cs = dark
      ? ColorScheme(
          brightness: Brightness.dark,
          primary: element,
          onPrimary: onElement,
          primaryContainer: accent.shade700,
          onPrimaryContainer: accent.shade50,
          secondary: element,
          onSecondary: onElement,
          secondaryContainer: accent.shade800,
          onSecondaryContainer: accent.shade100,
          tertiary: const Color(0xFFFFC107),
          onTertiary: Colors.black,
          error: const Color(0xFFE57373),
          onError: Colors.black,
          errorContainer: const Color(0xFF8C1D18),
          onErrorContainer: const Color(0xFFFFCDD2),
          background: const Color(0xFF303030),
          onBackground: Colors.white,
          surface: const Color(0xFF303030),
          onSurface: Colors.white,
          surfaceVariant: const Color(0xFF424242),
          onSurfaceVariant: const Color(0xB3FFFFFF),
          outline: const Color(0xFF8A8A8A),
          outlineVariant: const Color(0xFF5C5C5C),
          inverseSurface: const Color(0xFFFAFAFA),
          onInverseSurface: const Color(0xDE000000),
          inversePrimary: accent.shade500,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        )
      : ColorScheme(
          brightness: Brightness.light,
          primary: element,
          onPrimary: onElement,
          primaryContainer: accent.shade100,
          onPrimaryContainer: accent.shade900,
          secondary: element,
          onSecondary: onElement,
          secondaryContainer: accent.shade100,
          onSecondaryContainer: accent.shade900,
          tertiary: const Color(0xFFFF8F00),
          onTertiary: Colors.white,
          error: const Color(0xFFF44336),
          onError: Colors.white,
          errorContainer: const Color(0xFFFFCDD2),
          onErrorContainer: const Color(0xFFB71C1C),
          background: const Color(0xFFFAFAFA),
          onBackground: const Color(0xDE000000),
          surface: const Color(0xFFFAFAFA),
          onSurface: const Color(0xDE000000),
          surfaceVariant: const Color(0xFFE0E0E0),
          onSurfaceVariant: const Color(0x8A000000),
          outline: const Color(0xFF9E9E9E),
          outlineVariant: const Color(0xFFE0E0E0),
          inverseSurface: const Color(0xFF323232),
          onInverseSurface: Colors.white,
          inversePrimary: accent.shade200,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        );

  const r2 = BorderRadius.all(Radius.circular(2));
  const shape2 = RoundedRectangleBorder(borderRadius: r2);
  final cardBg = dark ? const Color(0xFF424242) : Colors.white;
  final typography = Typography.material2014(platform: TargetPlatform.android);
  final textTheme = dark ? typography.white : typography.black;
  const buttonText =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    colorScheme: cs,
    typography: typography,
    textTheme: textTheme,
    primaryColor: bar,
    primaryColorDark: accent.shade700,
    scaffoldBackgroundColor: cs.background,
    canvasColor: cs.background,
    cardColor: cardBg,
    dividerColor: dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: bar,
      foregroundColor: onBar,
      elevation: 4,
      scrolledUnderElevation: 4,
      centerTitle: false,
      titleTextStyle:
          TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: onBar),
      iconTheme: IconThemeData(color: onBar),
      actionsIconTheme: IconThemeData(color: onBar),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: onBar,
      unselectedLabelColor: onBar.withOpacity(0.7),
      // Индикатор на цветной панели — цветом текста панели.
      indicatorColor: onBar,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: buttonText,
      unselectedLabelStyle: buttonText,
    ),
    cardTheme: CardTheme(
      color: cardBg,
      elevation: 2,
      shape: shape2,
      margin: const EdgeInsets.all(4),
    ),
    dialogTheme:
        DialogTheme(backgroundColor: cardBg, elevation: 24, shape: shape2),
    popupMenuTheme:
        PopupMenuThemeData(color: cardBg, elevation: 8, shape: shape2),
    bottomSheetTheme:
        BottomSheetThemeData(backgroundColor: cardBg, elevation: 16),
    drawerTheme: DrawerThemeData(
      backgroundColor: cardBg,
      elevation: 16,
      shape: const RoundedRectangleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF323232),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      actionTextColor: dark ? accent.shade300 : accent.shade200,
      behavior: SnackBarBehavior.fixed,
      shape: const RoundedRectangleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: element,
        foregroundColor: onElement,
        elevation: 2,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: element,
        foregroundColor: onElement,
        elevation: 2,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: element,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: element,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const MaterialStatePropertyAll(shape2),
        backgroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? cs.primaryContainer : null),
        foregroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? cs.onPrimaryContainer : null),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: element,
      foregroundColor: onElement,
      elevation: 6,
      shape: const CircleBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? element
              : (dark ? const Color(0xFFBDBDBD) : const Color(0xFFF1F1F1))),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? element.withOpacity(0.5)
              : (dark ? const Color(0x4DFFFFFF) : const Color(0x42000000))),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? element : null),
      checkColor: MaterialStatePropertyAll(onElement),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2))),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? element : cs.onSurfaceVariant),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: element),
    inputDecorationTheme: InputDecorationTheme(
      border: const UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: element, width: 2)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: element,
      selectionColor: element.withOpacity(0.4),
      selectionHandleColor: element,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}

// ────────────────────────────────── Holo ──────────────────────────────────

const _holoRed = Color(0xFFFF4444); // holo_red_light
const _holoRedDark = Color(0xFFCC0000); // holo_red_dark
const _holoOrange = Color(0xFFFFBB33); // holo_orange_light
const _holoOrangeDark = Color(0xFFFF8800); // holo_orange_dark

ThemeData _holo(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? HoloPalette.dark : HoloPalette.light;
  const blue = HoloPalette.blue;
  // Голубой для элементов: на светлом фоне — holo_blue_dark (контраст).
  final accent = dark ? HoloPalette.blue : HoloPalette.blueDark;

  final cs = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: dark ? Colors.black : Colors.white,
    primaryContainer: dark ? const Color(0xFF0E3B4C) : const Color(0xFFCDEEFA),
    onPrimaryContainer:
        dark ? const Color(0xFFA6E1F5) : const Color(0xFF003A4F),
    secondary: accent,
    onSecondary: dark ? Colors.black : Colors.white,
    secondaryContainer:
        dark ? const Color(0xFF1F2F35) : const Color(0xFFDDEFF6),
    onSecondaryContainer:
        dark ? const Color(0xFFC8E8F4) : const Color(0xFF0B3443),
    tertiary: dark ? _holoOrange : _holoOrangeDark,
    onTertiary: dark ? Colors.black : Colors.white,
    error: dark ? _holoRed : _holoRedDark,
    onError: dark ? Colors.black : Colors.white,
    errorContainer: dark ? const Color(0xFF5C1414) : const Color(0xFFFFD6D6),
    onErrorContainer: dark ? const Color(0xFFFFC2C2) : const Color(0xFF5C0000),
    background: p.windowTop,
    onBackground: p.textPrimary,
    // Поверхности (меню, листы, поля) — панель диалога Holo.
    surface: p.panel,
    onSurface: p.textPrimary,
    surfaceVariant: dark ? const Color(0xFF333333) : const Color(0xFFE2E2E2),
    onSurfaceVariant: p.textSecondary,
    outline: dark ? const Color(0xFF6E6E6E) : const Color(0xFF9A9A9A),
    outlineVariant: p.listDivider,
    inverseSurface: dark ? const Color(0xFFF3F3F3) : const Color(0xFF282828),
    onInverseSurface: dark ? Colors.black : const Color(0xFFF3F3F3),
    inversePrimary: dark ? HoloPalette.blueDark : HoloPalette.blue,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  // Нажатие в Holo — заливка голубым (list_selector_holo: pressed), без волны.
  final pressed = blue.withOpacity(dark ? 0.6 : 0.4);
  final focused = blue.withOpacity(0.25);
  MaterialStateProperty<Color?> overlay() =>
      MaterialStateProperty.resolveWith((s) {
        if (s.contains(MaterialState.pressed)) return pressed;
        if (s.contains(MaterialState.focused) ||
            s.contains(MaterialState.hovered)) {
          return focused;
        }
        return null;
      });

  const r2 = BorderRadius.all(Radius.circular(2));
  const shape2 = RoundedRectangleBorder(borderRadius: r2);
  final typography = Typography.material2014(platform: TargetPlatform.android);
  final base = (dark ? typography.white : typography.black).apply(
    bodyColor: p.textPrimary,
    displayColor: p.textPrimary,
  );
  // Roboto 4.x: заголовки обычного веса (TextAppearance.Holo.*).
  final textTheme = base.copyWith(
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w400),
  );

  // Кнопка Holo (Widget.Holo.Button): полупрозрачный серый прямоугольник,
  // 48dp, текст обычного регистра; нажатие — голубым.
  final holoButton = ButtonStyle(
    backgroundColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.disabled)
            ? p.button.withOpacity(0.2)
            : p.button),
    foregroundColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.disabled)
            ? p.textPrimary.withOpacity(0.38)
            : p.textPrimary),
    overlayColor: overlay(),
    elevation: const MaterialStatePropertyAll(0),
    shape: const MaterialStatePropertyAll(shape2),
    minimumSize: const MaterialStatePropertyAll(Size(64, 44)),
    splashFactory: NoSplash.splashFactory,
    textStyle: const MaterialStatePropertyAll(
        TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
  );
  // Плоская кнопка (Widget.Holo.Button.Borderless).
  final borderless = ButtonStyle(
    foregroundColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.disabled)
            ? p.textPrimary.withOpacity(0.38)
            : p.textPrimary),
    overlayColor: overlay(),
    shape: const MaterialStatePropertyAll(RoundedRectangleBorder()),
    splashFactory: NoSplash.splashFactory,
    textStyle: const MaterialStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
  );

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    colorScheme: cs,
    extensions: [HoloThemeExt(p)],
    typography: typography,
    textTheme: textTheme,
    primaryColor: accent,
    // Фон окна — градиент, его рисует каждая страница (HoloWindowBackground
    // в переходе маршрута); Scaffold прозрачный.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: p.panel,
    cardColor: p.panel,
    dividerColor: p.listDivider,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: pressed,
    focusColor: focused,
    hoverColor: focused,
    // Панель действий Theme.Holo: прозрачная поверх фона окна, по низу —
    // голубая полоса 1,5dp (ab_transparent_*_holo). Заголовок 18sp.
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: blue, width: 1.5)),
      titleTextStyle: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w400, color: p.textPrimary),
      iconTheme: IconThemeData(color: p.textPrimary),
      actionsIconTheme: IconThemeData(color: p.textPrimary),
    ),
    // «Вверх» Holo: каретка ‹ и значок приложения; меню — значок с полосками.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const _HoloUpIcon(),
      drawerButtonIconBuilder: (_) => const _HoloUpIcon(drawer: true),
    ),
    // Вкладки панели действий (Widget.Holo.ActionBar.TabText): 12sp bold,
    // ЗАГЛАВНЫЕ (StyledTab), индикатор — голубая полоса 6dp.
    tabBarTheme: TabBarTheme(
      labelColor: p.textPrimary,
      unselectedLabelColor: p.textPrimary,
      indicator: const HoloTabIndicator(),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      overlayColor: overlay(),
      splashFactory: NoSplash.splashFactory,
    ),
    // Строки списка (preference_holo): заголовок 18sp, описание 14sp
    // вторичным цветом.
    listTileTheme: ListTileThemeData(
      selectedColor: accent,
      iconColor: p.textSecondary,
      // От textTheme (inherit: false), как у стилей других тем: ListTile
      // анимирует стиль текста при смене темы, а TextStyle.lerp не умеет
      // переходить между inherit true/false.
      titleTextStyle: textTheme.titleMedium!
          .copyWith(fontSize: 18, fontWeight: FontWeight.w400, color: p.textPrimary),
      subtitleTextStyle: textTheme.bodyMedium!
          .copyWith(fontSize: 14, color: p.textSecondary),
    ),
    dividerTheme: DividerThemeData(color: p.listDivider, thickness: 1),
    // Holo без карточек: плоская подложка с тонкой рамкой.
    cardTheme: CardTheme(
      color: dark ? const Color(0x0DFFFFFF) : const Color(0x08000000),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: r2, side: BorderSide(color: p.listDivider)),
      margin: const EdgeInsets.all(4),
    ),
    // Диалоги, не прошедшие через StyledAlertDialog: панель Holo, заголовок
    // голубой 22sp (TextAppearance.Holo.DialogWindowTitle).
    dialogTheme: DialogTheme(
      backgroundColor: p.panel,
      elevation: 0,
      shape: shape2,
      titleTextStyle: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w400, color: blue),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.panel,
      elevation: 4,
      shape: const RoundedRectangleBorder(),
      textStyle: TextStyle(fontSize: 18, color: p.textPrimary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.panel,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: dark ? const Color(0xFF111111) : const Color(0xFFF3F3F3),
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    // Toast Android 4.x (toast_frame): тёмно-серая плашка, светлый текст.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF383838),
      contentTextStyle:
          const TextStyle(color: Color(0xFFF3F3F3), fontSize: 14),
      actionTextColor: blue,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6))),
    ),
    filledButtonTheme: FilledButtonThemeData(style: holoButton),
    elevatedButtonTheme: ElevatedButtonThemeData(style: holoButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: holoButton),
    textButtonTheme: TextButtonThemeData(style: borderless),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(),
        splashFactory: NoSplash.splashFactory,
        shape: const MaterialStatePropertyAll(RoundedRectangleBorder()),
      ),
    ),
    // Сегментов в Holo нет — ряд кнопок Holo, выбранная подсвечена голубым.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const MaterialStatePropertyAll(shape2),
        side: MaterialStatePropertyAll(BorderSide(color: p.listDivider)),
        overlayColor: overlay(),
        splashFactory: NoSplash.splashFactory,
        backgroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected)
                ? blue.withOpacity(0.35)
                : p.button.withOpacity(0.25)),
        foregroundColor: MaterialStatePropertyAll(p.textPrimary),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.panel,
      foregroundColor: blue,
      elevation: 2,
      highlightElevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: r2),
    ),
    // Переключатели — HoloSwitch (StyledSwitch); здесь — для оставшихся
    // стандартных Switch.
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? HoloPalette.blueDark
              : const Color(0xFF9E9E9E)),
      trackColor: MaterialStatePropertyAll(p.switchTrack),
    ),
    // CheckBox Holo (btn_check_holo): серая рамка, голубая галочка.
    checkboxTheme: CheckboxThemeData(
      fillColor: const MaterialStatePropertyAll(Colors.transparent),
      checkColor: const MaterialStatePropertyAll(blue),
      side: MaterialStateBorderSide.resolveWith(
          (_) => BorderSide(color: p.textSecondary, width: 2)),
      shape: const RoundedRectangleBorder(),
    ),
    // RadioButton Holo: серое кольцо, у выбранного — голубое.
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? blue : p.textSecondary),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: blue,
      linearTrackColor: blue.withOpacity(0.2),
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: blue,
      thumbColor: blue,
    ),
    // EditText Holo: линия с засечками; в фокусе — holo_blue_dark.
    inputDecorationTheme: InputDecorationTheme(
      border: HoloUnderlineInputBorder(
          borderSide: BorderSide(color: p.fieldLine)),
      enabledBorder: HoloUnderlineInputBorder(
          borderSide: BorderSide(color: p.fieldLine)),
      focusedBorder: const HoloUnderlineInputBorder(
          borderSide: BorderSide(color: HoloPalette.blueDark, width: 2)),
      floatingLabelStyle: const TextStyle(color: blue),
      hintStyle: TextStyle(color: p.textSecondary.withOpacity(0.6)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: blue,
      selectionColor: blue.withOpacity(0.4),
      selectionHandleColor: blue,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: Color(0xFF383838),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      textStyle: TextStyle(color: Color(0xFFF3F3F3)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _HoloPageTransitionsBuilder(),
    }),
  );
}

/// Кнопка «Вверх» панели действий Holo: каретка ‹ (ic_ab_back_holo) и значок
/// приложения; у меню — короткие полоски (ic_drawer) вместо каретки.
class _HoloUpIcon extends StatelessWidget {
  const _HoloUpIcon({this.drawer = false});

  final bool drawer;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    // Ширина кнопки панели может быть меньше 48dp — ужимаем по месту.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(drawer ? Icons.menu : Icons.chevron_left,
              size: drawer ? 14 : 16, color: color),
          Image.asset('assets/icons/app_icon.png', width: 24, height: 24),
        ],
      ),
    );
  }
}

/// Переход между Activity в Android 4.x — короткое затухание с лёгким
/// масштабированием (activity_open_enter_holo); страница рисует фон окна.
class _HoloPageTransitionsBuilder extends PageTransitionsBuilder {
  const _HoloPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.decelerate);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
        child: HoloWindowBackground(child: child),
      ),
    );
  }
}
