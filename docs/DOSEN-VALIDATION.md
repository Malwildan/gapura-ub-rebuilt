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


## Integration with the complete current main history

The local merge candidate `63dfaff1910a97381616c2dfa678e6871a7f6e89` has parents `cf053d540adb0b675aad9be70475e5d088b21019` (main) and `87f9c1cbf6027f4a28c72ceb39eb46f430f74f04` (DOSEN). Both histories are preserved. The review compared `git diff cf053d5...63dfaff` (12 files, 170 additions and 34 deletions), both unique commit ranges, and the entire main history:

- `dee5a25`: initial student reconstruction.
- `33167b1`: isolated synthetic guest preview.
- `3a8b737`: role previews, shared employee screens and Android document-save handler.
- `832231a`: accessible guest library route.
- `5879fcb`: shared role-module and export-boundary documentation.
- `cf053d5`: Tendik publication review.

Conflict resolution retains main's guest app migration and Android handler, preserves both preview modes' local images and disabled external launches, and removes the unused duplicate staff/tax dispatcher. Android saving support is present in source; device runtime behavior is unverified. The earlier statement that no platform handler existed applied only to the standalone DOSEN export before this integration.

### Standards

The independent review of the integrated diff found zero documented-standard violations and zero clear smell findings. The preview guards protect distinct entry points. Previous low-severity suggestions concern unchanged code and are not new merge findings.

### Spec

The independent review report records zero findings. Lecturer routes, shared employee screens, guest/library isolation and main's Android save handler are preserved. TINJAU's selectable-text preview remains the explicit reconstruction approximation described above.

### Integrated validation

On `63dfaff`, with Flutter 3.35.3 and the unchanged dependency lockfile: full analysis reported no issues; the full suite passed 244 tests with two configuration-dependent skips and zero failures; the demo release web build succeeded. No configuration defines were supplied. The parent verified the three retained validation log hashes. The working tree remained clean. A publication scan found no issues across 261 tracked files and verified all 106 bundled asset hashes.

These checks cover the integrated source, not original-runtime parity, browser acceptance, native device saving or live lecturer services. The possible mobile form action-row clipping observation remains unconfirmed. Review summary for this merge: Standards 0 findings, no worst issue; Spec 0 findings, no worst issue.
