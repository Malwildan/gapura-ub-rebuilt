# Dosen publication scope

This specification scopes the DOSEN publication candidate at the selected baseline. It is based on the intended requirements recorded in the source documents `DOSEN-IMPLEMENTATION-WORK.md` and `DOSEN-DEMO.md`; those workspace documents contain private paths and task history and are not copied here.

## Intended requirements

The implementation work calls for `DosenDemoData(DemoSession session)` to expose session-aware reads, saves and removals. As the source brief states, “Data reads honor DemoSession.read and return no records for the empty scenario. Unknown resources throw.” Synthetic IDs link related courses and documents; all writes stay in memory. Session or scenario changes remount the demo so local writes and pending responses do not cross sessions.

The demo brief says the normal `lib/main.dart` entry remains separate and that Dosen workflows use synthetic local data, not a live lecturer login. The publication entry is `lib/demo_main.dart`, where the user selects Dosen in the shared multi-role demo shell. That shared shell, demo roles, session and adapters are dependencies of the Dosen preview; they do not represent live lecturer integration.

Required lecturer surfaces are Presensi; Kepegawaian; Remunerasi; Pendapatan & PPh21; Jadwal Mengajar; Bimbingan Akademik; Statistik Publikasi; Pendapa; Profil; and the shared library route. Kepegawaian, Remunerasi and Pendapatan & PPh21 reuse the shared employee personnel and finance screens. The Dosen-only screens use local demo adapters. Existing shared app shell, public information and library behavior remain dependencies where wired into these routes.

The source work brief explicitly limits the behavior: “No UB requests, original APK execution, real calendar/filesystem/signing mutation or configuration exposure is authorized by this implementation brief.” Accordingly, demo-side calendar, document, signing and tax actions are simulations. No real lecturer session or external write is part of this candidate.

## Evidence basis

Public test fixtures record the recovered role menu labels, order, routes and artwork. The implementation's structure and field choices were informed by static descriptions of recovered screens, forms and display data. These are evidence sources, not proof of complete runtime parity. Private evidence catalogs, machine-specific paths, reverse-engineering reports, screenshots and raw artifacts are excluded from the proposed publication set.

The source history reports an implementation-workspace regression of 238 passing tests and two configuration-dependent skips, a clean targeted analysis, and an independent code review with no material findings. Those checks were performed before this export preparation and do not establish that the publication candidate has been tested. Browser attempts were cancelled before a final acceptance report; possible mobile form action-row clipping remains unresolved. No browser acceptance or pixel-parity claim is made.

## Publication boundary

Publish only the Dosen behavior, its shared demo shell and session adapters, required shared employee screens, narrowly required public fixture-backed dependencies, associated tests and SDK-selecting demo launcher. Keep normal live-service behavior separate. The standard app's blank native configuration guidance and fixture tests must not refer to the source-only configuration generator or local binary/config extraction.

Do not include unrelated role-specific feature work, private source work logs, machine paths, reverse-engineering reports, screenshots, APKs, credentials, caches, generated build output or local verification logs. Preserve the existing README, Android manifest and progress document; their concurrent installation changes are outside this candidate's DOSEN allowlist.

## Explicit preview approximation

The recovered original tax TINJAU sequence downloads through a helper before opening its PDF viewer. The synthetic preview currently opens selectable text directly from in-memory records; it does not reproduce that sequence or a PDF viewer. UNDUH generates a local synthetic PDF, with browser export implemented and Android saving dependent on an unimplemented platform handler. This retained Spec gap is documented rather than represented as complete parity. Calendar, signing, server acceptance and native operations remain unverified. Publication validation is recorded separately in [DOSEN-VALIDATION.md](DOSEN-VALIDATION.md).
