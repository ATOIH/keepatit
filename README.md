# Keep At It

A habit notifier that is **100% on-device**: no backend, no account, no analytics, no runtime
network. The Android release manifest ships **without the INTERNET permission** — the OS
notification is the product; the app is a thin shell for setup and progress.

Specs live beside the designs in the project folder: `Keep At It - PRD v1.1.md` and
`Keep At It - Delivery Plan v1.1.md`.

## Architecture (PRD §8–§9)

```
lib/
  engine/            pure Dart, zero Flutter imports — the core IP
    models.dart        HabitSpec, PlannedInstance, enums
    instance_generator.dart  wall-clock instance planning (inclusive-end, deadlines, rest day)
    budget.dart        60-triggers/day validator (protects iOS's 64-notification cap)
    materialize.dart   wall-clock -> timezone-aware DateTime (DST gap => excused)
  data/db.dart       drift schema: habits, trigger_logs, app_state
  theme/tokens.dart  Obsidian Precision design system constants
  main.dart          app shell (screens land Day 4 of the sprint)
```

## Build & test — GitHub Actions is the factory

Every push runs `.github/workflows/build.yml`: scaffold (`flutter create .`) → codegen →
analyze → **engine test suite** → `flutter build apk --release`, and uploads
`keepatit-apk` as a downloadable artifact. Tags `v*` additionally publish a GitHub Release
with the APK attached. The `android/` folder is deliberately not committed — CI regenerates
it and applies `android_overlay/` (manifest with permissions, receivers, app label).

Local development (any machine with Flutter stable):

```
flutter create --org com.aayushgupta --project-name keepatit --platforms android .
cp -f android_overlay/app/src/main/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

## Non-negotiable principles

1. No cloud infrastructure, ever. Local notifications only; OS device backup only.
2. Engine changes require the full engine test suite green (`test/`).
3. Trigger budget: ≤ 60 instances/day across active habits (iOS pending-notification cap is 64).
4. Fonts bundled (OFL: Hanken Grotesk, JetBrains Mono); no runtime fetches.
