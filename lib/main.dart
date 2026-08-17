// Keep At It — app shell (Day 1 of the build sprint).
// Screens are assembled Days 4–7; this shell proves theme, fonts and structure.
import 'package:flutter/material.dart';

import 'theme/tokens.dart';

void main() {
  runApp(const KeepAtItApp());
}

class KeepAtItApp extends StatelessWidget {
  const KeepAtItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keep At It',
      debugShowCheckedModeBanner: false,
      theme: buildKeepAtItTheme(),
      home: const TodayScreen(),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: KColors.pureBlack,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.airplanemode_active,
              color: KColors.lowContrast),
          tooltip: 'Pause all (arrives with the engine)',
          onPressed: () {},
        ),
        title: Text('KEEP AT IT',
            style: KType.headlineMd.copyWith(letterSpacing: -0.4)),
        shape: const Border(
            bottom: BorderSide(color: KColors.borderSubtle, width: 1)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(KSpace.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: KSpace.lg),
            Text("Today's Focus", style: KType.headlineLgMobile),
            const SizedBox(height: KSpace.xl),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('NO ACTIVE PROTOCOLS', style: KType.labelCaps),
                    const SizedBox(height: KSpace.sm),
                    Text(
                      'Define your first focus ritual.',
                      style: KType.bodySm.copyWith(color: KColors.lowContrast),
                    ),
                    const SizedBox(height: KSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: KColors.crimson,
                          padding:
                              const EdgeInsets.symmetric(vertical: KSpace.md),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kRadius)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: KColors.surfaceHover,
                              content: Text(
                                  'Habit setup lands in the next build (Day 4).'),
                            ),
                          );
                        },
                        child: Text('ACTIVATE FIRST HABIT',
                            style: KType.bodyLg.copyWith(
                                fontVariations: const [
                                  FontVariation('wght', 700)
                                ],
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
                child: Text('v0.1.0 · engine build',
                    style: KType.labelMono
                        .copyWith(color: KColors.lowContrast))),
            const SizedBox(height: KSpace.sm),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
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
