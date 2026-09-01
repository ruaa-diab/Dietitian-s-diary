import 'package:flutter/widgets.dart';

import 'app_store.dart';

/// Makes the [AppStore] available to the widget tree and rebuilds
/// dependants when it changes.
///
/// A plain [InheritedNotifier] keeps the app dependency-free; swapping in
/// a package like provider later would only touch this file.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// Reads the store and subscribes to its changes.
  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context');
    return scope!.notifier!;
  }

  /// Reads the store without subscribing — for event handlers.
  static AppStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context');
    return scope!.notifier!;
  }
}
