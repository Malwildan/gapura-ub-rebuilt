# Dosen local demo

Run `tool/run-demo.ps1` from the repository root. The launcher selects the project's matched Flutter SDK through `tool/flutter-original.ps1`. In the role selector choose **Dosen**; the entry point is `lib/demo_main.dart`. Choose **Berisi**, **Memuat**, **Kosong** or **Gagal** to change the local demo data state.

This is a multi-role demo shell with a Dosen preview. Its role selector and session adapters are shared demo dependencies. Selecting Dosen does not sign in to a lecturer account or connect the lecturer screens to UB services. The regular application entry point remains `lib/main.dart`.

## Included paths

The Dosen menu includes Presensi, Kepegawaian, Remunerasi, Pendapatan & PPh21, Jadwal Mengajar, Bimbingan Akademik, Statistik Publikasi and Layanan Perpustakaan. Kepegawaian, Remunerasi and Pendapatan & PPh21 use the shared employee personnel and finance screens. Dosen-specific teaching, advising, publication, attendance and Pendapa behavior uses local demo data. Shared home, theme, news, public information and library screens remain part of the surrounding app shell.

Role or scenario changes create a fresh demo session. Demo reads return synthetic records, honor the selected loading/empty/error state, and reject unsupported resources. Local edits do not persist to UB or across a new session. University information and library tests use public fixtures; they do not extract data from local configuration.

## Evidence and limits

The menu fixture and tests document recovered role labels, order, routes and artwork. The implementation also draws on described screen structures and data fields from static reconstruction evidence. Those source catalogs and raw reverse-engineering reports are not included in this publication candidate. Reconstructed field names and screen structure are evidence-informed; fixture values, mutable local state, option lists and unverified form behavior are demonstrations rather than claims about live lecturer records.

An inherited implementation checkpoint records 238 passing tests and two configuration-dependent skips, plus a clean targeted analysis. That result belongs to the implementation workspace and is not a test result for this publication candidate. No export-candidate tests or analysis were run as part of this preparation.

An independent code review reported no material findings. Browser verification is incomplete: browser tasks were cancelled before a final acceptance report, and a possible mobile form action-row clipping issue remains unresolved. Partial captures are not proof that all actions are reachable. Original-versus-rebuilt pixel parity, live lecturer data, full permission and status gates, UB request behavior, and native device integration are not established.

Calendar writes, file selection, document transmission, electronic signing and tax documents are local simulations. A displayed success means the local demo state changed; it does not mean UB accepted a request. No original APK or UB account was run for this demo.
