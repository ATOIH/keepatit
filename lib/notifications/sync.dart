// Sync orchestrator — the single entry point that makes reality match the DB.
// Called on: app launch, app resume, foreground notification response, habit
// CRUD, and Pause All toggles. (PRD §8.2 refresh points.)
import 'dart:io' show Platform;

import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../data/repository.dart';
import '../engine/schedule_select.dart';
import 'notifier.dart';

Future<void> fullSync(AppDb db, tz.Location loc) async {
  // 1. Settle past instances (missed / excused).
  await reconcile(db, loc);

  // 2. Paused => nothing pending, nothing scheduled.
  if (await isPaused(db)) {
    await cancelAllScheduled();
    return;
  }

  // 3. Recompute and apply the schedule. Precision timing (exact alarms) is
  //    user-opt-in and only honored while the OS grant is actually held.
  final rows = await activeHabitRows(db);
  final specs = rows.map(specFromRow).toList();
  final targets = selectSchedule(
    specs: specs,
    loc: loc,
    now: tz.TZDateTime.now(loc),
    iosBudgetMode: Platform.isIOS,
  );
  final exactMode = Platform.isAndroid &&
      await getAppState(db, 'precision_mode') == '1' &&
      await canUseExactAlarms();
  await applySchedule(targets, {for (final s in specs) s.id: s},
      exactMode: exactMode);
}
