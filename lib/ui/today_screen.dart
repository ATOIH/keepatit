// S1 — Today ("Today's Focus"), PRD §7.1, design: daily_focus_dark_mode.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../data/repository.dart';
import '../notifications/content.dart';
import '../notifications/notifier.dart';
import '../notifications/sync.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'setup_screen.dart';

class TodayScreen extends StatefulWidget {
  final AppDb db;
  const TodayScreen({super.key, required this.db});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _minuteTick;
  bool? _notifEnabled;

  @override
  void initState() {
    super.initState();
    // Progress and "open instance" states shift with wall-clock time.
    _minuteTick = Timer.periodic(
        const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final enabled = await notificationsEnabled();
    if (mounted) setState(() => _notifEnabled = enabled);
  }

  @override
  void dispose() {
    _minuteTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = localDateOf(DateTime.now());
    return StreamBuilder<List<Habit>>(
      stream: watchActiveHabitRows(widget.db),
      builder: (context, habitsSnap) {
        final habits = habitsSnap.data ?? const <Habit>[];
        return StreamBuilder<List<TriggerLog>>(
          stream: watchLogsOn(widget.db, today),
          builder: (context, logsSnap) {
            final logs = logsSnap.data ?? const <TriggerLog>[];
            return _body(context, habits, logs);
          },
        );
      },
    );
  }

  Widget _body(
      BuildContext context, List<Habit> habits, List<TriggerLog> logs) {
    final views = habits
        .map((h) => buildTodayView(h, logs, tz.local))
        .toList()
      ..sort((a, b) {
        final an = a.nextToday?.minuteOfDay ?? a.openInstance?.minuteOfDay ?? 1440;
        final bn = b.nextToday?.minuteOfDay ?? b.openInstance?.minuteOfDay ?? 1440;
        return an.compareTo(bn);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          KSpace.marginMobile, KSpace.lg, KSpace.marginMobile, 120),
      children: [
        if (_notifEnabled == false && habits.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(KSpace.md),
            decoration: ghostCard(border: KColors.crimson),
            child: Text(
              'Notifications are off — Keep At It is silent. Enable them in '
              'system Settings → Apps → Keep At It → Notifications.',
              style: KType.bodySm.copyWith(color: KColors.onSurface),
            ),
          ),
          const SizedBox(height: KSpace.md),
        ],
        Text("Today's Focus", style: KType.headlineLgMobile),
        const SizedBox(height: KSpace.md),
        if (habits.isEmpty) _emptyState(context),
        for (final v in views) ...[
          _habitCard(context, v),
          const SizedBox(height: KSpace.md),
        ],
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: KSpace.xl),
      child: Column(
        children: [
          const SectionLabel('No active protocols'),
          const SizedBox(height: KSpace.sm),
          Text('Define your first focus ritual.',
              style: KType.bodySm.copyWith(color: KColors.lowContrast)),
          const SizedBox(height: KSpace.lg),
          CrimsonButton(
            label: 'ACTIVATE FIRST HABIT',
            icon: Icons.power_settings_new,
            onPressed: () => _openSetup(context, null),
          ),
        ],
      ),
    );
  }

  Widget _habitCard(BuildContext context, TodayHabitView v) {
    final fraction = v.expectedSoFar == 0
        ? 0.0
        : v.doneToday / v.expectedSoFar;
    final allDoneSoFar = v.expectedSoFar > 0 && v.doneToday >= v.expectedSoFar;
    final actionable = v.openInstance != null;

    return InkWell(
      onTap: () => _openSetup(context, v.row),
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.all(KSpace.md),
        decoration: ghostCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.spec.directive, style: KType.headlineMd),
                      const SizedBox(height: KSpace.sm),
                      Wrap(
                        spacing: KSpace.sm,
                        runSpacing: KSpace.xs,
                        children: [
                          MonoChip(
                              icon: Icons.schedule,
                              label: frequencyChip(v.spec)),
                          MonoChip(
                              icon: Icons.access_time,
                              label: windowChip(v.spec)),
                          if (v.spec.restDay != null)
                            MonoChip(
                                icon: Icons.bedtime_outlined,
                                label: 'REST ${_dayName(v.spec.restDay!)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KSpace.sm),
                _checkControl(context, v, actionable, allDoneSoFar),
              ],
            ),
            const SizedBox(height: KSpace.lg),
            ThinProgress(fraction),
            const SizedBox(height: KSpace.xs),
            Text(
              v.expectedSoFar == 0
                  ? (v.nextToday == null
                      ? 'No triggers today'
                      : 'First trigger at ${formatMinute(v.nextToday!.minuteOfDay)}')
                  : '${v.doneToday} / ${v.expectedSoFar} so far today',
              style: KType.labelMono.copyWith(color: KColors.lowContrast),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkControl(
      BuildContext context, TodayHabitView v, bool actionable, bool allDone) {
    final Color border = actionable || allDone
        ? KColors.crimson
        : KColors.borderSubtle;
    final Color fill = allDone
        ? KColors.crimson.withValues(alpha: 0.1)
        : Colors.transparent;
    final Color iconColor = actionable || allDone
        ? KColors.crimson
        : KColors.borderSubtle;

    return InkWell(
      onTap: () async {
        if (v.openInstance != null) {
          final p = v.openInstance!;
          await recordResponseByKey(
            widget.db,
            instanceKey(v.spec.id, p.localDate, p.minuteOfDay),
            'done',
            'app',
          );
          await fullSync(widget.db, tz.local);
          if (mounted) setState(() {});
        } else if (v.nextToday != null) {
          showObsidianSnack(
              context, 'Next at ${formatMinute(v.nextToday!.minuteOfDay)}');
        } else {
          showObsidianSnack(context, 'Done for today.');
        }
      },
      customBorder: const CircleBorder(),
      child: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border),
        ),
        child: Icon(Icons.check, size: 18, color: iconColor),
      ),
    );
  }

  String _dayName(int weekday) => const [
        'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
      ][weekday - 1];

  Future<void> _openSetup(BuildContext context, Habit? edit) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SetupScreen(db: widget.db, edit: edit),
        fullscreenDialog: true));
    await _refreshPermission();
    if (mounted) setState(() {});
  }
}
