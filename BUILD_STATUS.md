# Build status

**Status: GREEN.** CI passes on `main` and the `v0.3.0-alpha1` tag publishes an
installable APK. One CI fix was needed this round — and it was a *repeat* of the
v0.2.0 fix (see "The one failure" below); nothing in `lib/engine/*` or `test/*`
was touched.

| | |
|---|---|
| Feature commit | `882c855` — *v0.3.0-alpha: Streaks screen (S3) + notification hygiene fixes + D-11 rule + Today add button* |
| First run (`882c855`) | ❌ [32128100236](https://github.com/ATOIH/keepatit/actions/runs/32128100236) — failed at **Analyze** after 1m45s |
| Fix commit | `8e33187` — *CI fix (attempt 1/4): drop redundant flutter/foundation import in notifier.dart* |
| Run on `main` (`8e33187`) | ✅ [32128299461](https://github.com/ATOIH/keepatit/actions/runs/32128299461) — 8m21s, all 13 steps green |
| Tag run (`v0.3.0-alpha1`) | ✅ [32129045236](https://github.com/ATOIH/keepatit/actions/runs/32129045236) — 8m10s |
| **Release** | **https://github.com/ATOIH/keepatit/releases/tag/v0.3.0-alpha1** |
| Installable APK | [`keepatit-v0.3.0-alpha1-8e33187.apk`](https://github.com/ATOIH/keepatit/releases/download/v0.3.0-alpha1/keepatit-v0.3.0-alpha1-8e33187f45ca1302baae4535f22933e6b2cac5ae.apk) — 59,522,440 bytes |
| Analyze | `No issues found! (ran in 9.9s)` |
| Tests | **66/66 passed** (`00:04 +66: All tests passed!`) — up from 52 in v0.2.0 |
| Attempts used | 1 of 4 |
| Toolchain | Flutter stable 3.47.0, ubuntu-latest |

---

## What shipped in this commit

`882c855` is the Cowork session's v0.3.0-alpha payload: 3 new library files, 4
changed ones, 2 new test suites, and `pubspec.yaml` version `0.2.0+2` → `0.3.0+3`.

- `lib/ui/streaks_screen.dart` (new, 345 lines) — screen S3: consistency figure,
  90-day rewire bar, heatmap + 90-day grid, today timeline.
- `lib/ui/settings_screen.dart` (new, 156 lines) — includes the Precision timing
  exact-alarm toggle.
- `lib/data/stats.dart` (new, 213 lines) — the stats derivations behind S3.
- `lib/notifications/notifier.dart`, `sync.dart` — notification hygiene against
  stale overlap: response-timeout margin and a predecessor sweep.
- `lib/data/repository.dart` — D-11: notification responses outrank auto-missed.
- `lib/main.dart` — rewired for the new screens; Today gets an add button
  (127 lines changed, mostly deletions as screens moved out of `main.dart`).
- New suites: `test/stats_rules_test.dart`, `test/response_rules_db_test.dart`.

No workflow or `android_overlay/` change was required. The exact-alarm toggle
builds against the existing overlay unchanged — `SCHEDULE_EXACT_ALARM` was
already in the committed manifest from the v0.2.0 round.

## The one failure, and the fix — a repeat of v0.2.0's

Run [32128100236](https://github.com/ATOIH/keepatit/actions/runs/32128100236) got
through scaffold, overlay, desugaring, `pub get` and drift codegen, then stopped
at **Analyze** after 1m45s with the *same* diagnostic that broke the v0.2.0 round:

```
Analyzing keepatit...

   info • The import of 'package:flutter/foundation.dart' is unnecessary because
   all of the used elements are also provided by the import of
   'package:flutter/widgets.dart'. Try removing the import directive
   • lib/notifications/notifier.dart:11:8 • unnecessary_import

1 issue found. (ran in 8.2s)
##[error]Process completed with exit code 1.
```

Severity is `info`, and the repo's `analysis_options.yaml` makes `flutter analyze`
exit non-zero on any diagnostic — so an informational lint is a hard build failure
here.

Fix (`8e33187`), the whole diff:

```diff
--- a/lib/notifications/notifier.dart
+++ b/lib/notifications/notifier.dart
@@
-import 'package:flutter/foundation.dart';
 import 'package:flutter/widgets.dart';
```

`widgets.dart` re-exports `foundation.dart`, so every symbol `notifier.dart` uses
still resolves. Purely mechanical, no behaviour change, and no other file in the
repo imports `package:flutter/foundation.dart`.

**Regression, not a new bug.** Commit `424a710` removed this exact line last
round; the v0.3.0 rewrite of `notifier.dart` put it back. Two rounds, two
identical CI failures, ~2 minutes of runner time each. Worth a cheap upstream
guard next session — either the authoring session runs `flutter analyze` before
handing the tree over, or `notifier.dart` gains a one-line comment at the import
block saying `widgets.dart` already covers `foundation.dart`. Not applied here:
it touches a file the CI-fix rules keep to mechanical edits only.

## Unresolved

None. All 13 steps are green on both `main` and the tag, and the release asset is
published and downloadable.

Non-blocking annotation on every run (informational, not a failure), unchanged
from last round:

```
Node.js 20 is deprecated. The following actions target Node.js 20 but are being
forced to run on Node.js 24: actions/checkout@v4, actions/upload-artifact@v4,
softprops/action-gh-release@v2.
```

Nothing to do yet — the runner transparently runs them on Node 24. When those
actions publish v5 majors, bump them in one commit.

## Carried-over notes — still true, still worth reading before touching CI

- **`unnecessary_import` in `notifier.dart` has now failed two rounds running.**
  If Analyze is red, check that import first.
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
  token. Not observed in the v0.2.0 or v0.3.0 sessions (likely fresh-repo
  replication lag that has since settled), but if it returns: retry until a 200,
  and never read a 404 as "the run does not exist."
