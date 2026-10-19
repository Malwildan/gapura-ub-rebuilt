# Reconstructed architecture

This describes the current source. It is not a claim that the original application's full architecture was recovered.

| Component | Responsibility |
| --- | --- |
| `lib/main.dart` and `lib/ui/` | Flutter navigation, live guest/student widgets, loading/error/empty states and confirmation flows |
| `lib/demo_main.dart`, `lib/demo/` | Separate five-role preview, synthetic readers and local mutations; role/state changes remount the session |
| `lib/guest_demo_main.dart`, `lib/guest_demo/` | Separate guest-only preview using the shared demo shell and its own four-state public fixtures |
| `lib/ui/employee/`, `lib/service/staff_modules.dart` | Shared personnel, remuneration and income/tax views with injected readers; the demo uses synthetic employee records |
| `lib/ui/dosen/`, `lib/demo/dosen_data.dart` | Lecturer attendance/tasks, academic, Pendapa and profile views backed by session-local synthetic data |
| `lib/service/demo_document_export*`, Android `MainActivity` | Synthetic tax PDF export through browser download or Android's user-selected document destination |
| `lib/model/`, `lib/common/` | Typed/parsing helpers, bundled public records, theme and feature definitions |
| `lib/services.dart` | Public readers and Android direct-service requests; shared configuration supplied through Dart defines |
| `lib/account_bridge_native.dart`, `lib/service/session_store.dart` | Native AppAuth flow, fixed student API operations and app-private SQLite session storage |
| `lib/account_bridge_web.dart`, `web/account_bridge.js` | Browser messages for a bounded set of account operations |
| `tool/account-extension/` | Official-dashboard account bridge with fixed routes and local origins |
| `tool/api_relay.py` | Loopback-only public news/shared-service readers, fixed upstream allowlists, bounded responses, and a separate notification reader; no student session handling |
| `lib/service/general_announcements.dart` | Android Firebase Remote Config adapter and announcement parsing; no speculative REST replacement |
| `test/` | Synthetic account/service fixtures, widget/state regressions and public target-version content fixtures |

## Request paths

On Android, AppAuth uses the recovered mobile flow, sessions stay in private SQLite storage, and fixed requests go directly to UB. Optional service/Firebase configuration is supplied at build time. Native login has not been verified end to end.

In the browser, student requests execute in the official `https://akun.ub.ac.id/dashboard` session. The bridge returns account records to Flutter and retains bearer tokens in the official context. The extension limits local app origins to `http://127.0.0.1:8790` and `http://localhost:8790`. It supports a bounded action list rather than arbitrary URLs. Public news/shared-service reads use the separate loopback relay on port 8791.

Attendance/survey writers are distinct from readers. The UI requires explicit confirmation and enforces server eligibility, input bounds and in-flight guards. Unknown write outcomes are surfaced for status refresh; no automatic retries or generated survey answers are sent.

The preview entry points inject synthetic service and announcement sources and do not initialize Firebase or restore a live account session. Role/scenario switching replaces navigation and local data while preserving the selected theme. Parent, staff and lecturer previews do not add live authentication or backend integration; unsupported operations are rejected. Lecturer document, calendar and signing actions are simulations. The shared tax preview can export a clearly marked synthetic PDF.

## Optional official-dashboard popup pairing

The extension workflow is the normal local launcher path. For an explicit dashboard pairing in a development browser:

1. Start the local Flutter web server and relay using the README commands.
2. Sign in on the official dashboard. In that page's developer console, evaluate the contents of the reviewed local file `tool/account-extension/official-session-bridge.js`.
3. Add a temporary button from the dashboard console, then click it to open Flutter with an explicit user gesture. Keep the dashboard open:

   ```js
   const gapuraButton = document.createElement('button');
   gapuraButton.textContent = 'Open local Gapura rebuild';
   gapuraButton.onclick = () => gapuraOpenApp();
   document.body.prepend(gapuraButton);
   ```

4. Connect from the Flutter popup. Closing/reloading the official page ends this pairing; local session data is not exported to files.

The script also exposes an iframe helper, but the observed browser blocked dashboard-to-loopback iframe loading with `ERR_BLOCKED_BY_LOCAL_NETWORK_ACCESS_CHECKS`. The recorded milestone used the popup. This is a developer compatibility route; it does not establish native behavior parity.

## Local configuration

`config/native.example.json` lists the eight supported, blank Dart defines. Copy it to ignored `.local/native-config.json` and supply only authorized application/service configuration. The relay reads `GAPURA_CLIENT_ID` and `GAPURA_SERVICE_TOKEN` from that file; Flutter receives the file through `--dart-define-from-file` when needed. The IAM login itself belongs in the official authentication flow.

No APK, engine, SDK, browser profile, account records, recovered secret or analysis dump is required in the published tree. `pubspec.lock`, `.fvmrc`, Android Gradle configuration and the standard wrapper provide the reproducible source inputs. Original source, a complete original lockfile and the original publisher signing key were not recovered.
