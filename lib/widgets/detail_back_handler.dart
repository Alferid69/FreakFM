import 'package:flutter/foundation.dart';

/// Lets a tab's drill-down view (an album, artist, genre or folder) claim the
/// system Back button, so Back goes up one level instead of leaving the app.
///
/// Each tab registers a close callback under its own name while a detail is
/// open; the home screen asks for the callback of the tab that is visible.
class DetailBackHandler {
  DetailBackHandler._();

  static final ValueNotifier<Map<String, VoidCallback>> open = ValueNotifier(const {});

  static void register(String tab, VoidCallback close) {
    open.value = {...open.value, tab: close};
  }

  static void unregister(String tab) {
    if (!open.value.containsKey(tab)) return;
    open.value = {...open.value}..remove(tab);
  }

  /// Closes the open detail in [tab]; returns false when there was none.
  static bool closeIn(String tab) {
    final close = open.value[tab];
    if (close == null) return false;
    close();
    return true;
  }
}
