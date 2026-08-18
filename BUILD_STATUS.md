# Build status

**Status: GREEN.** CI passes on `main` and the `v0.2.0-alpha1` tag publishes an
installable APK. One CI fix was needed this round (a lint-only import removal);
nothing in `lib/engine/*` or `test/*` was touched.

| | |
|---|---|
| Feature commit | `cb51b20` — *v0.2.0-alpha: live notification loop — channel + DONE/NOT DONE actions, background logging, rolling scheduler, Setup & Today on real data* |
| First run (`cb51b20`) | ❌ [32109543977](https://github.com/ATOIH/keepatit/actions/runs/32109543977) — failed at **Analyze** |
| Fix commit | `424a710` — *CI fix (attempt 1/4): drop redundant flutter/foundation import in notifier.dart* |
| Run on `main` (`424a710`) | ✅ [32109730859](https://github.com/ATOIH/keepatit/actions/runs/32109730859) — 8m07s, all steps green |
| Tag run (`v0.2.0-alpha1`) | ✅ [32110379094](https://github.com/ATOIH/keepatit/actions/runs/32110379094) |
| **Release** | **https://github.com/ATOIH/keepatit/releases/tag/v0.2.0-alpha1** |
| Installable APK | [`keepatit-v0.2.0-alpha1-424a710.apk`](https://github.com/ATOIH/keepatit/releases/download/v0.2.0-alpha1/keepatit-v0.2.0-alpha1-424a710d63c675c13fedc17a050efeb776ccffa8.apk) — 59,522,388 bytes |
| Analyze | `No issues found! (ran in 8.6s)` |
| Tests | **52/52 passed** (`00:05 +52: All tests passed!`) — up from 29 in v0.1.0 |
| Attempts used | 1 of 4 |
| Toolchain | Flutter stable 3.47.0, ubuntu-latest |

---

## What shipped in this commit

`cb51b20` is the Cowork session's v0.2.0-alpha payload: 11 new/changed library
files plus 3 new test files, and `pubspec.yaml` version `0.1.0+1` → `0.2.0+2`.

- `lib/notifications/` — `notifier.dart` (channel `habit_triggers`, DONE / NOT DONE
  action buttons, background response handling), `sync.dart` (rolling scheduler),
  `content.dart` (notification copy).
- `lib/ui/` — `setup_screen.dart`, `today_screen.dart`, `priming_sheet.dart`,
  `common.dart`; `lib/main.dart` rewired onto real data.
- `lib/data/repository.dart`, `lib/engine/schedule_select.dart`.
- New suites: `content_test.dart`, `repository_rules_test.dart`,
  `schedule_select_test.dart`.

No workflow or `android_overlay/` change was required — the manifest overlay
already carried `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`,
`SCHEDULE_EXACT_ALARM` and the three `flutter_local_notifications` receivers
(`ScheduledNotificationReceiver`, `ActionBroadcastReceiver`,
`ScheduledNotificationBootReceiver`), so the new notification surface built against
the existing overlay unchanged.

## The one failure, and the fix

Run [32109543977](https://github.com/ATOIH/keepatit/actions/runs/32109543977) got
through scaffold, overlay, desugaring, `pub get` and drift codegen, then stopped at
**Analyze** after 1m47s:

```
Analyzing keepatit...

   info • The import of 'package:flutter/foundation.dart' is unnecessary because
   all of the used elements are also provided by the import of
   'package:flutter/widgets.dart'. Try removing the import directive
   • lib/notifications/notifier.dart:11:8 • unnecessary_import

1 issue found. (ran in 9.2s)
##[error]Process completed with exit code 1.
```

Note the severity: `info`. The repo's `analysis_options.yaml` makes `flutter
analyze` exit non-zero on any diagnostic, so an informational lint is a hard build
failure here — worth remembering when reading future logs.

Fix (`424a710`), the whole diff:

```diff
--- a/lib/notifications/notifier.dart
+++ b/lib/notifications/notifier.dart
@@
-import 'package:flutter/foundation.dart';
 import 'package:flutter/widgets.dart';
```

`widgets.dart` re-exports `foundation.dart`, so every symbol `notifier.dart` used
still resolves. Purely mechanical, no behaviour change, and no other file in the
repo imports `package:flutter/foundation.dart`.

## Unresolved

None. All 13 steps are green on both `main` and the tag, and the release asset is
published and downloadable.

Non-blocking annotation on every run (informational, not a failure):

```
Node.js 20 is deprecated. The following actions target Node.js 20 but are being
forced to run on Node.js 24: actions/checkout@v4, actions/upload-artifact@v4,
softprops/action-gh-release@v2.
```

Nothing to do yet — the runner transparently runs them on Node 24. When those
actions publish v5 majors, bump them in one commit.

## Carried-over notes from the v0.1.0 session

Still true, still worth reading before touching CI:

- **`android/` is not committed.** It is generated in CI by `flutter create` and
  patched in place by `android_overlay/patch_gradle.py` (core library desugaring —
  `flutter_local_notifications` 19.x needs `java.time` desugared or gradle fails).
  The patcher is idempotent and deliberately non-fatal: if the Flutter template
  stops matching it prints why and exits 0, so the real gradle error surfaces
  instead of a patcher crash. It fired again this run.
- **Step names containing `": "` must be quoted.** An unquoted colon-space in a
  YAML plain scalar broke the whole workflow file in the v0.1.0 session. A
  malformed workflow is a *startup* failure: no jobs, no logs, `total_count: 0`,
  `created_at == updated_at`, and `gh run view --log-failed` can never explain it —
  read the annotation on the run's web page instead.
- **Flaky GitHub REST 404s.** The v0.1.0 session saw intermittent HTTP 404 on this
  repo across `/branches`, `/commits` and `/actions/runs`, on a correctly scoped
  token. Not observed at all this session (likely fresh-repo replication lag that
  has since settled), but if it returns: retry until a 200, and never read a 404 as
  "the run does not exist."
