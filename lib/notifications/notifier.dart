// Notification surface N1 (PRD §7.5) — flutter_local_notifications 19.x.
// Channel `habit_triggers`, DONE / NOT DONE actions, group-per-habit,
// Android timeoutAfter auto-dismiss at the response deadline.
//
// Display-replacement note (delta vs PRD D-5): instances carry unique ids so
// they can coexist in the pending queue; "one visible per habit" is achieved by
// grouping (Android groupKey / iOS threadIdentifier) + Android timeoutAfter,
// and data-level replacement (auto-miss) happens in reconcile().
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/db.dart';
import '../data/repository.dart';
import '../engine/models.dart';
import '../engine/schedule_select.dart';
import 'content.dart';

const String kChannelId = 'habit_triggers';
const String kChannelName = 'Habit Triggers';
const String kChannelDescription =
    'Recurring habit prompts inside your operational windows';
const String kCategoryId = 'HABIT_TRIGGER';
const String kActionDone = 'DONE';
const String kActionNotDone = 'NOT_DONE';

final FlutterLocalNotificationsPlugin notifier =
    FlutterLocalNotificationsPlugin();

/// Foreground taps/actions land here; main.dart wires the callback so it can
/// refresh UI state after the write.
typedef ResponseHandler = Future<void> Function(NotificationResponse response);

Future<void> initNotifier(ResponseHandler onForegroundResponse) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  final darwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: [
      DarwinNotificationCategory(
        kCategoryId,
        actions: [
          DarwinNotificationAction.plain(kActionNotDone, 'NOT DONE'),
          DarwinNotificationAction.plain(kActionDone, 'DONE'),
        ],
      ),
    ],
  );
  await notifier.initialize(
    InitializationSettings(android: android, iOS: darwin),
    onDidReceiveNotificationResponse: (r) => onForegroundResponse(r),
    onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
  );
}

/// Lock-screen action handler — runs in its own background isolate while the
/// app may be dead. Kept minimal: parse, write the log, close. The 48h horizon
/// means rescheduling can safely wait for the next app open/resume.
@pragma('vm:entry-point')
Future<void> notificationActionBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await handleResponse(response, openAppDb(), closeDb: true);
  } catch (e) {
    debugPrint('keepatit bg response error: $e');
  }
}

/// Shared response logic for foreground and background paths.
Future<void> handleResponse(NotificationResponse response, AppDb db,
    {bool closeDb = false}) async {
  try {
    final payload = response.payload;
    final action = response.actionId;
    if (payload == null) return;
    if (action != kActionDone && action != kActionNotDone) {
      return; // body tap just opens the app (S1)
    }
    await recordResponseByKey(
      db,
      payload, // 'R|'-prefixed for repeating triggers; handled downstream
      action == kActionDone ? 'done' : 'not_done',
      'notification',
    );
  } finally {
    if (closeDb) await db.close();
  }
}

/// Android 13+ / iOS permission request. Returns true when granted.
Future<bool> requestNotificationPermission() async {
  final android = notifier.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }
  final ios = notifier.resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>();
  if (ios != null) {
    final granted =
        await ios.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? false;
  }
  return false;
}

Future<bool> notificationsEnabled() async {
  final android = notifier.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    return await android.areNotificationsEnabled() ?? false;
  }
  return true; // iOS: treated as enabled until a denial is observed via request
}

/// Cancels everything pending and schedules [targets]. Idempotent by design —
/// called from every sync point (launch, resume, response, CRUD, pause toggle).
Future<void> applySchedule(
    List<ScheduleTarget> targets, Map<String, HabitSpec> specsById) async {
  await notifier.cancelAll();

  for (final t in targets) {
    final spec = specsById[t.plan.habitId];
    if (spec == null) continue;

    final key =
        instanceKey(spec.id, t.plan.localDate, t.plan.minuteOfDay);
    final id = notificationIdFor(
        t.repeatingDaily ? '${spec.id}|daily-repeat' : key);

    // Auto-dismiss at the response deadline (Android only); min 1 minute.
    final visibleMinutes =
        (t.plan.deadlineMinuteOfDay - t.plan.minuteOfDay).clamp(1, 1440);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        kChannelId,
        kChannelName,
        channelDescription: kChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        groupKey: 'habit_${spec.id}',
        timeoutAfter: visibleMinutes * 60000,
        actions: [
          AndroidNotificationAction(kActionNotDone, 'NOT DONE',
              showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction(kActionDone, 'DONE',
              showsUserInterface: false, cancelNotification: true),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: kCategoryId,
        threadIdentifier: spec.id,
        interruptionLevel: InterruptionLevel.active,
      ),
    );

    await notifier.zonedSchedule(
      id,
      notificationTitle(spec),
      notificationBody(spec, t.plan.minuteOfDay),
      t.at,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeating triggers get the 'R|' marker: their embedded date is only
      // an anchor and responses must remap to the firing day (repository).
      payload: t.repeatingDaily ? 'R|$key' : key,
      matchDateTimeComponents:
          t.repeatingDaily ? DateTimeComponents.time : null,
    );
  }
}

Future<void> cancelAllScheduled() => notifier.cancelAll();
