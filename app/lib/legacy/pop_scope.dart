import 'package:flutter/widgets.dart';

/// lx-legacy: `PopScope` появился во Flutter 3.16, а ветка для Android 4.x
/// собирается на Flutter 3.13 (движок 3.16 не грузится на API < 19). Тот же
/// API (`canPop`, `onPopInvoked`) поверх `WillPopScope`.
///
/// Отличие от оригинала: `onPopInvoked(true)` вызывается непосредственно
/// перед уходом со страницы, а не после.
class PopScope extends StatelessWidget {
  const PopScope({
    super.key,
    required this.child,
    this.canPop = true,
    this.onPopInvoked,
  });

  final Widget child;
  final bool canPop;
  final void Function(bool didPop)? onPopInvoked;

  @override
  Widget build(BuildContext context) {
    final callback = onPopInvoked;
    if (canPop && callback == null) return child;
    return WillPopScope(
      onWillPop: () async {
        callback?.call(canPop);
        return canPop;
      },
      child: child,
    );
  }
}
