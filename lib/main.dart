// Keep At It — v0.2.0-alpha: the live notification loop.
// Init order matters: timezone db -> local location -> app db -> notifier ->
// UI; a full sync runs after first frame and on every resume (PRD §8.2).
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data/db.dart';
import 'data/repository.dart';
import 'notifications/notifier.dart';
import 'notifications/sync.dart';
import 'theme/tokens.dart';
import 'ui/common.dart';
import 'ui/today_screen.dart';

const String kAppVersion = '0.2.0 (build 2)';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tzdata.initializeTimeZones();
  try {
    // flutter_timezone 4.x returns TimezoneInfo, older versions a String —
    // resolve either shape without pinning to one API.
    final dynamic localTz = await FlutterTimezone.getLocalTimezone();
    final String name =
        localTz is String ? localTz : (localTz.identifier as String);
    tz.setLocalLocation(tz.getLocation(name));
  } catch (_) {
    // tz.local falls back to the package default; schedules regenerate on the
    // next successful launch. Never crash the app over timezone lookup.
  }

  final db = openAppDb();

  await initNotifier((response) async {
    await handleResponse(response, db);
    await fullSync(db, tz.local);
    db.markTablesUpdated([db.triggerLogs]);
  });

  runApp(KeepAtItApp(db: db));
}

class KeepAtItApp extends StatelessWidget {
  final AppDb db;
  const KeepAtItApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keep At It',
      debugShowCheckedModeBanner: false,
      theme: buildKeepAtItTheme(),
      home: HomeShell(db: db),
    );
  }
}

class HomeShell extends StatefulWidget {
  final AppDb db;
  const HomeShell({super.key, required this.db});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resync();
  }

  Future<void> _resync() async {
    await fullSync(widget.db, tz.local);
    // Background-isolate writes (lock-screen DONE) don't invalidate this
    // isolate's drift streams — poke them after every sync.
    widget.db.markTablesUpdated([widget.db.triggerLogs, widget.db.habits]);
    final paused = await isPaused(widget.db);
    if (mounted) setState(() => _paused = paused);
  }

  Future<void> _togglePause() async {
    await setAppState(widget.db, 'pause_all', _paused ? '0' : '1');
    await _resync();
    if (mounted) {
      showObsidianSnack(
          context, _paused ? 'Triggers active.' : 'All triggers paused.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: KColors.pureBlack,
        centerTitle: true,
        leading: IconButton(
          tooltip: _paused ? 'Resume all triggers' : 'Pause all triggers',
          icon: Icon(Icons.airplanemode_active,
              color: _paused ? KColors.crimson : KColors.lowContrast),
          onPressed: _togglePause,
        ),
        title: Text('KEEP AT IT',
            style: KType.headlineMd.copyWith(letterSpacing: -0.4)),
        actions: const [SizedBox(width: 48)],
        shape: const Border(
            bottom: BorderSide(color: KColors.borderSubtle, width: 1)),
        bottom: _paused
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  width: double.infinity,
                  color: KColors.surfaceHover,
                  padding: const EdgeInsets.symmetric(vertical: KSpace.xs),
                  child: Center(
                    child: Text('PAUSED — NO TRIGGERS WILL FIRE',
                        style: KType.labelMono
                            .copyWith(color: KColors.crimson)),
                  ),
                ),
              )
            : null,
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(db: widget.db),
          const _StreaksPlaceholder(),
          _SettingsLite(
              db: widget.db, paused: _paused, onTogglePause: _togglePause),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: KColors.surface,
        indicatorColor: KColors.surfaceContainerHighest.withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Streaks'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _StreaksPlaceholder extends StatelessWidget {
  const _StreaksPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KSpace.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KSpace.lg),
          Text('NEUROPLASTICITY IN PROGRESS',
              style: KType.headlineLgMobile.copyWith(letterSpacing: -0.3)),
          const SizedBox(height: KSpace.sm),
          Text('Tracking consistency to rebuild neural pathways.',
              style: KType.bodySm.copyWith(color: KColors.lowContrast)),
          const SizedBox(height: KSpace.xl),
          Center(
            child: Text('STREAK ANALYTICS ARRIVE IN THE NEXT BUILD',
                style: KType.labelCaps),
          ),
        ],
      ),
    );
  }
}

class _SettingsLite extends StatelessWidget {
  final AppDb db;
  final bool paused;
  final VoidCallback onTogglePause;
  const _SettingsLite(
      {required this.db, required this.paused, required this.onTogglePause});

  @override
  Widget build(BuildContext context) {
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
          value: paused,
          onChanged: (_) => onTogglePause(),
        ),
        const SizedBox(height: KSpace.lg),
        const SectionLabel('Notifications'),
        FutureBuilder<bool>(
          future: notificationsEnabled(),
          builder: (context, snap) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Permission status', style: KType.bodyLg),
            trailing: Text(
              snap.data == null
                  ? '…'
                  : (snap.data! ? 'GRANTED' : 'OFF'),
              style: KType.labelMono.copyWith(
                  color:
                      snap.data == false ? KColors.crimson : KColors.onSurface),
            ),
            subtitle: snap.data == false
                ? Text(
                    'Enable in system Settings → Apps → Keep At It → Notifications.',
                    style: KType.bodySm.copyWith(color: KColors.lowContrast))
                : null,
          ),
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
          child: Text('Version $kAppVersion · full settings arrive in a later build',
              style: KType.labelMono.copyWith(color: KColors.lowContrast)),
        ),
      ],
    );
  }
}
