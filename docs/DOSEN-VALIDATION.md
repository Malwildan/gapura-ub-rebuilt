# DOSEN publication validation and review

The code candidate was reviewed against baseline `33167b1c2d7d51f1c7bdac4c14cff8d0227e8d01` at `8adef0764a166e4f453f33c9b4236e471aa288de`. Later edits record these results and limits in documentation only.

## Standards

No hard documented-standard violations were found. Two low-severity duplication heuristics remain: repeated staff/lecturer menu entries in `lib/common/features.dart`, and similar asynchronous state handling in `DosenLoad` and the academic `_AsyncPane`. These are nonblocking suggestions; the publication avoids introducing a new abstraction solely for them.

## Spec

Two confirmed regressions in the existing guest preview were corrected: local portrait placeholders and disabled external library links are preserved alongside the new demo session. The missing carousel image-provider dependency was added while preserving the existing local-preview API. An unused staff/finance dispatcher and its snackbar-only tax callback were removed; the actual Menu uses the shared staff module.

One acknowledged gap remains: tax TINJAU uses a selectable-text preview instead of the recovered download-helper-before-PDF-viewer flow. The demo guide and scope state this explicitly. Mobile form action-row reachability still needs browser reproduction; it is an unconfirmed observation rather than a proven regression.

## Checks

Flutter 3.35.3 / Dart 3.9.2 and the unchanged lockfile were used. These are publication-candidate results, not borrowed from the implementation workspace:

- Full analysis after correction: `flutter analyze --no-pub` ? no issues found.
- Focused guest/DOSEN interaction tests: 18 passed.
- Full suite: `flutter test --no-pub --no-track-widget-creation --reporter expanded` ? 244 passed, two skipped, zero failed. The skips require native configuration and synthetic service defines; neither was supplied.
- Demo release compilation: `flutter build web --release --no-pub -t lib/demo_main.dart` ? succeeded. A nonfatal Wasm dry-run notice required invoking the same build directly through the matched SDK after the PowerShell wrapper treated stderr as an error.
- Publication content scan: no credential/path-pattern or private configuration value findings; all 106 bundled asset hashes matched their provenance record.

Browser acceptance, Android device execution, UB integration, original-versus-rebuilt pixels and native signing/calendar/filesystem operations were not validated in this publication pass. The original APK and account services were not executed.

Standards: two low-severity heuristics, zero hard violations; Spec: one documented tax-preview approximation remains after correcting the guest regressions.
