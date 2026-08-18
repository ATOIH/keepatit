// Keep At It — v0.3.0-alpha: Streaks screen + notification hygiene fix-pack.
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
import 'ui/settings_screen.dart';
import 'ui/setup_screen.dart';
import 'ui/streaks_screen.dart';
import 'ui/today_screen.dart';

const String kAppVersion = '0.3.0 (build 3)';

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
        actions: [
          if (_tab == 0)
            IconButton(
              tooltip: 'New habit',
              icon: const Icon(Icons.add, color: KColors.lowContrast),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SetupScreen(db: widget.db),
                    fullscreenDialog: true));
                await _resync();
              },
            )
          else
            const SizedBox(width: 48),
        ],
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
          StreaksScreen(db: widget.db),
          SettingsScreen(
            db: widget.db,
            paused: _paused,
            onTogglePause: _togglePause,
            appVersion: kAppVersion,
          ),
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
