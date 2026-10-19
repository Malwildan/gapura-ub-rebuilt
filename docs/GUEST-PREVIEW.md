# Guest-only synthetic preview

Run the local public UI preview on Chrome from PowerShell:

```powershell
$env:FLUTTER_ROOT = 'C:\path\to\flutter-3.35.3'
.\tool\run-guest-demo.ps1
```

To use another Flutter device, pass its ID first: `tool/run-guest-demo.ps1 -Device <id>`. The launcher uses the repository's Flutter 3.35.3 wrapper and does not read `.local/native-config.json` or pass service credentials.

This separate entry starts directly in guest mode. Its public news, calendar, statistics, gallery, achievements, and announcement fixtures are synthetic and served through the existing service boundary in memory. The demo does not initialize Firebase, restore or create an account session, or open external links. Guest university information and carousel images use local placeholders. The data selector demonstrates populated, loading, empty, and failed reads; changing it resets navigation and cached reads while keeping the selected theme.

The normal `lib/main.dart` entry keeps its existing startup, service, Firebase, account, and theme behavior. The preview includes only the guest role and does not offer a role selector.

Focused checks:

```powershell
$env:FLUTTER_ROOT = 'C:\path\to\flutter-3.35.3'
.\tool\flutter-original.ps1 test --no-pub test/guest_demo_test.dart
```
