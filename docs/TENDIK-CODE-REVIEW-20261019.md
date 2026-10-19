# Tendik publication code review

Reviewed on 19 October 2026 with independent Standards and Spec reviewers.
Baseline: `33167b1c2d7d51f1c7bdac4c14cff8d0227e8d01`.
Reviewed source: `5879fcb92031f7ea9e9903486c5cb58e626a40b7`.
Comparison: `git diff 33167b1...5879fcb` (50 files).

The review covers Tendik Menu items 2–5 and the shared role-preview changes
included since the baseline. The accepted scope is synthetic personnel,
remuneration, income/tax, and library views using the recovered structures.
It does not require live employee authentication or original-screen parity.

## Standards

Documented-standard violations: **0**. Judgment-call findings: **2**.

- **Possible Duplicated Code** — `lib/common/features.dart:166`:
  `employeeMenuFeatures` and `lecturerMenuFeatures` repeat the same five
  `Feature` entries, from `survey_employee` / `Presensi` through `library` /
  `Layanan Perpustakaan`. A shared list could hold those entries.
- **Possible Divergent Change** — `lib/ui/dosen/dosen_academic.dart:160`:
  one file contains separate `_Schedule`, `_Teaching`, `_Roster`, `_Recap`,
  `_Announcements`, `_Reminder`, `_Advisees`, and `_Publications` flows.
  Splitting them by flow could make maintenance more local.

Both are nonblocking maintainability observations. This publication retains
the tested code rather than introducing a broader refactor.

## Spec

Findings: **0**. The Tendik routes, SISTER role gate, history categories,
remuneration details, income filters, synthetic document actions, and library
route match the accepted scope. The guest-only preview retains synthetic
data and local image placeholders; demo library launches remain disabled.

The documented limits remain: staff services use synthetic records, tax
preview/export does not reproduce the original PDF viewer, and original
screen parity and physical-device document saving remain unverified.

## Review summary

Standards: 2 nonblocking heuristic findings, no documented-rule violations;
the main concern is the lecturer screen file covering several independent
flows. Spec: 0 findings, no outstanding requirement mismatch.

## Validation

Validation used Flutter 3.35.3 / Dart 3.9.2 on the reviewed source snapshot.

- Dependency resolution and Flutter analysis passed with no issues.
- The full Flutter suite passed: **244 passed, 0 skipped, 0 failed**.
  Tests ran with concurrency 1 and synthetic service configuration values.
- The role-demo release web build passed with an explicitly captured exit
  code of 0 (`flutter build web --release -t lib/demo_main.dart`).
- Publication scanning found **0 issues** across 258 tracked files, including
  this report. All 106 recorded asset hashes matched; eight local private
  configuration values were checked without copying them into publication.
  No outside-checkout evidence references or path dependencies were found.

No fresh Android build, live staff request, original-screen comparison, or
physical-device document-save check was performed during this review.
