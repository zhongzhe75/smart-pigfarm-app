import 'package:flutter/widgets.dart';

import '../services/app_state.dart';

class SmartPigfarmScope extends InheritedNotifier<AppState> {
  const SmartPigfarmScope({
    super.key,
    required AppState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppState watch(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SmartPigfarmScope>();
    assert(scope != null, 'SmartPigfarmScope not found in widget tree');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<SmartPigfarmScope>();
    final scope = element?.widget as SmartPigfarmScope?;
    assert(scope != null, 'SmartPigfarmScope not found in widget tree');
    return scope!.notifier!;
  }
}
