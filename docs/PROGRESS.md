# Progress against Gapura UB 3.3.38

Checkpoint: **19 October 2026**. Target: Android release **3.3.38 / 194**. The initially supplied attachment identified as Aptoide; reconstruction instead used the verified Gapura artifacts retained in the development workspace. No original APK or reverse-engineering dump is included here.

## Implemented and checked

| Area | Current behavior | Verification boundary |
| --- | --- | --- |
| Home and news | Eight public shortcuts, six bundled university information screens, statistics/calendar readers, `PENGHARGAAN` carousel, six ordered news tabs and public readers | Source tests and rebuilt browser checks; no original-versus-rebuilt pixel comparison |
| Student navigation | Four connected tabs and seven vertical Menu cards, including separate timetable/history, Presensi Kelas and library entries | Rebuilt browser checked; screenshot in this repository contains no account details |
| Profile | Student bio reader, recovered header/portrait layout and six detail rows | `getBioMhs_v2` succeeded; separate original bodyless POST `/profile` returned HTTP 401 through the browser client. Missing NIM/email remain blank with a visible error |
| Academic services | Regular/short timetable, term-selected KRS/KHS, transcript, finance, announcements, materials and class history | Real-account readers checked. One checkpoint returned 11 schedule, 8 KRS, 8 KHS, 23 transcript and 6 finance rows; these are observations, not fixed expectations |
| Attendance viewing | Running/missed meetings, server status gate, toolbar and pull-to-refresh | Running was empty and missed contained 3 meetings in the observed session. Refresh preserved the selected view and reread status/meetings |
| Attendance submission | Explicit H/I/S selection, confirmation, duplicate/in-flight guards and exact `STAT_ISI == "1"` gate | Synthetic tests only; **no live submission or backend acceptance confirmed** |
| Health survey | Ordered four-question tuples, explicit confirmation, guarded writer and refreshed status | Synthetic tests only; **no live submission**. Unknown tuple escaping is rejected rather than guessed |
| Library | Nine bundled external links; original refresh appends the Android link again | Ordered content and launch tests; browser launch is a compatibility adaptation |
| General announcements | Android Firebase Core 4.0.0 / Remote Config 6.0.0, 10-second timeout, zero fetch interval, `fetchAndActivate`, `global_pengumuman`, full-list dialog | SDK calls tested through a fake adapter. Live Firebase content/acceptance unverified. Original literal date predicate `start >= now && end <= now` retained. Browser registration unavailable |
| Session changes | Account changes/disconnect clear student state and invalidate pending results, including A → B → A transitions | Regression tests. Class-history selection starts a fresh versioned request; wide-layout portrait position is bounded |

## Local role preview checkpoint

The credential-free five-role preview includes Tendik Menu items 2-5: Kepegawaian, Remunerasi, Pendapatan & PPh21, and Layanan Perpustakaan. These screens use synthetic local readers and a synthetic PDF. Staff authentication, role resolution, backend readers, Pendapa, staff presence, and shared staff profile are not implemented as live services. Existing Dosen demo integrations remain in the shared role shell. The prior 156-test export checkpoint predates this role work and is not validation of the current publication snapshot; current targeted validation is recorded by the task review, not inferred from those historical counts.

## Toolchain and reconstruction evidence

- Flutter **3.35.3**, Dart **3.9.2**, framework revision `a402d9a4376add5bc2d6b1e33e53edaae58c07f8`, engine revision `ddf47dd3ff96dbde6d9c614db0d7f019d7c7a2b7`. The original ARMv7 Flutter engine matched the official engine after symbol stripping. This establishes engine identity, not recovery of the Dart source.
- The original workspace produced Android and web release builds. Its final ARMv7 development APK was 21,282,804 bytes, SHA-256 `5e9faa19923739292dadfb316b53ef4760d474ec5846f20f190f9aa12843f8c8`. That artifact is excluded from this source repository and is distinct from a future build of this export.
- Packaged engine and two Android build metadata resources matched the originals byte for byte; 47 original native dependency declarations matched and 26 original-only declarations remained absent. Dependency constraints only align modules already in use; they do not reproduce the full original dependency graph.
- All 106 retained artwork/font assets match their recorded original hashes. Public fixture files retain only expected institutional content needed by tests, without machine paths or complete analysis reports. Historical officials/content reflect the target release and may be outdated.
- Across all roles, 103 relative endpoint families were recovered; 13 are represented and 90 absent. This is an inventory, not an overall completion percentage. The reconstructed lockfile and architecture are newly written, with selected recovered pins and explicit compatibility choices.

## Validation checkpoints

The original workspace milestone reported **156 Flutter tests, no skips**, clean Flutter analysis, **25 relay tests**, passing JavaScript bridge checks, and successful Android/web builds. Rebuilt browser checks covered profile, finance, KRS/KHS/transcript, timetable filtering, Menu, attendance viewing and refresh. No attendance or survey write was sent.

An earlier publication checkpoint passed **156 Flutter tests with no skips**, **28 relay tests** (including three configuration-boundary tests), Flutter analysis, JavaScript bridge checks, and a release web build. That checkpoint predates the current Tendik and Dosen role additions and is historical evidence, not validation of this snapshot.

The public export replaces machine-specific SDK/config discovery and uses curated fixtures instead of the source workspace recovery files. At the time of that earlier checkpoint, no Android build or live account request had been made from its publication copy. Generated builds and test logs are excluded from Git.

## Android installation compatibility follow-up (19 October 2026)

The launcher now reads **Gapura UB Rebuilt**. The package remains `id.ac.ub.gapura_rebuilt`, separate from the official app. Updated the README to build a universal ARMv7/ARM64/x86_64 APK instead of the previous ARMv7-only artifact, which cannot install on 64-bit-only phones. Minimum Android version remains 9.

The original workspace produced a fresh universal release: 57,579,987 bytes, SHA-256 `67406f4c89101d476e9cf3d1bd52f44365812c677ec59c0a1e7496dc733ab1ae`. All three architectures contain the Flutter engine, app library and native Datastore library. Archive integrity, Android signature, unchanged signing certificate and 16 KiB ZIP alignment checks passed. This is a new artifact checkpoint, separate from the earlier ARMv7 engine/dependency comparison above. No APK, local configuration, or screen-control tool is included in this source export.

After USB authorization, the universal APK installed successfully on a Redmi Note 8 Pro running Android API 29. Android reported a successful cold launch with the rebuilt MainActivity foreground; the process remained running and a local screenshot confirmed the public home screen. The installed native ABI is ARM64. No login or authenticated service was exercised, no app was uninstalled, and no app data was cleared. This phone also supports ARMv7, so its earlier generic installation failure cannot be attributed solely to the old artifact's architecture; the exact previous failure was not reproduced.

## Remaining work

1. Capture and compare original 3.3.38 runtime screens. Current UI is evidence-guided; **1:1 pixel parity is unproven**.
2. Verify mobile AppAuth login, restored session/startup/onboarding behavior and Android Firebase runtime responses. Rebuilt installation/public-home startup is now checked on the phone above. The available original emulator failed to boot, so original runtime capture remains blocked.
3. Resolve the browser identity endpoint's HTTP 401 without inventing identity fields or changing the original route.
4. Verify attendance/survey submission in an authorized real session with deliberate user confirmation; implementation alone does not prove acceptance.
5. Recover omitted roles, endpoint families, native features and the remaining original dependencies. Complete original architecture and dependency parity remain open.

The recorded browser session used a separate Flutter popup paired with the official dashboard after an iframe was blocked by local-network access checks. No browser security setting was changed. Android login and original-versus-rebuilt runtime behavior remain separate, unverified claims.
