// S4 — Settings (minimal by principle P-2), PRD §7.4.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../data/repository.dart';
import '../notifications/notifier.dart';
import '../notifications/sync.dart';
import '../theme/tokens.dart';
import 'common.dart';

class SettingsScreen extends StatefulWidget {
  final AppDb db;
  final bool paused;
  final VoidCallback onTogglePause;
  final String appVersion;
  const SettingsScreen(
      {super.key,
      required this.db,
      required this.paused,
      required this.onTogglePause,
      required this.appVersion});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _precisionPref = false;
  bool _exactGranted = false;
  bool _notifEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system exact-alarm screen: re-check the grant.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final pref = await getAppState(widget.db, 'precision_mode') == '1';
    final granted = Platform.isAndroid && await canUseExactAlarms();
    final notif = await notificationsEnabled();
    if (!mounted) return;
    setState(() {
      _precisionPref = pref;
      _exactGranted = granted;
      _notifEnabled = notif;
    });
  }

  Future<void> _togglePrecision(bool on) async {
    if (on && !_exactGranted) {
      // Opens the system "Alarms & reminders" screen; grant is re-checked on
      // resume via the lifecycle observer.
      await requestExactAlarms();
    }
    await setAppState(widget.db, 'precision_mode', on ? '1' : '0');
    await fullSync(widget.db, tz.local);
    await _refresh();
    if (mounted) {
      showObsidianSnack(
          context,
          on
              ? (_exactGranted
                  ? 'Precision timing on — triggers fire on the minute.'
                  : 'Waiting for the system permission — flip the switch on the screen that opened, then return.')
              : 'Precision timing off — battery-friendly windows.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final precisionActive = _precisionPref && _exactGranted;
    return ListView(
      padding: const EdgeInsets.all(KSpace.marginMobile),
      children: [
        const SizedBox(height: KSpace.lg),
        const SectionLabel('Behavior'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: KColors.crimson,
          title: Text('Pause all triggers', style: KType.bodyLg),
          subtitle: Text('Nothing fires until you resume.',
              style: KType.bodySm.copyWith(color: KColors.lowContrast)),
          value: widget.paused,
          onChanged: (_) => widget.onTogglePause(),
        ),
        const SizedBox(height: KSpace.lg),
        const SectionLabel('Notifications'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Permission status', style: KType.bodyLg),
          trailing: Text(_notifEnabled ? 'GRANTED' : 'OFF',
              style: KType.labelMono.copyWith(
                  color:
                      _notifEnabled ? KColors.onSurface : KColors.crimson)),
          subtitle: _notifEnabled
              ? null
              : Text(
                  'Enable in system Settings → Apps → Keep At It → Notifications.',
                  style: KType.bodySm.copyWith(color: KColors.lowContrast)),
        ),
        if (Platform.isAndroid)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: KColors.crimson,
            title: Text('Precision timing', style: KType.bodyLg),
            subtitle: Text(
              precisionActive
                  ? 'Triggers fire on the minute (exact alarms granted).'
                  : 'Default mode delivers within a battery-friendly window '
                      '(can run ~10 min late). Turn on to fire on the minute — '
                      'Android will ask for the "Alarms & reminders" permission.',
              style: KType.bodySm.copyWith(color: KColors.lowContrast),
            ),
            value: precisionActive,
            onChanged: _togglePrecision,
          ),
        const SizedBox(height: KSpace.lg),
        const SectionLabel('Data'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
          child: Text(
            'Your data lives on this device and is included in your '
            "phone's own backup. Keep At It has no servers.",
            style: KType.bodySm.copyWith(color: KColors.lowContrast),
          ),
        ),
        const SizedBox(height: KSpace.lg),
        const SectionLabel('About'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
          child: Text(
              'Version ${widget.appVersion} · full settings arrive in a later build',
              style: KType.labelMono.copyWith(color: KColors.lowContrast)),
        ),
      ],
    );
  }
}
