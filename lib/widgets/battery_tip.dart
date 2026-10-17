import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/media_store_channel.dart';
import '../theme/app_theme.dart';

/// Many phones (Xiaomi, Tecno, Infinix, Samsung, ...) put apps to sleep when
/// the screen is off, which silences music. This card sends the user to the
/// one system setting that prevents it. It hides once battery optimization is
/// off for FreakFM or the card is dismissed.
class BatteryTip extends StatefulWidget {
  const BatteryTip({super.key});

  static const String dismissedPref = 'pref_battery_tip_dismissed';

  @override
  State<BatteryTip> createState() => _BatteryTipState();
}

class _BatteryTipState extends State<BatteryTip> with WidgetsBindingObserver {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings page: re-evaluate.
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (kIsWeb || !Platform.isAndroid) return;
    var dismissed = false;
    try {
      dismissed = (await SharedPreferences.getInstance()).getBool(BatteryTip.dismissedPref) ?? false;
    } catch (_) {}
    final exempt = await MediaStoreChannel.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _show = !dismissed && !exempt);
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    try {
      await (await SharedPreferences.getInstance()).setBool(BatteryTip.dismissedPref, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        key: const ValueKey('battery_tip'),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppTheme.spotifyCardElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.battery_saver_rounded, color: AppTheme.spotifyGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keep music playing with the screen off',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text(
                    'Your phone may stop FreakFM to save battery. Set it to "Don\'t optimize".',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.spotifyLightGrey, height: 1.3),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('battery_tip_fix'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                      onPressed: MediaStoreChannel.openBatterySettings,
                      child: const Text('Fix it', style: TextStyle(color: AppTheme.spotifyGreen)),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
