# Keep this a plain script: advanced parameters would consume Flutter's -d as
# PowerShell's common -Debug parameter instead of forwarding the device flag.
$FlutterArguments = $args

# Use an installed SDK matching the shipped Gapura UB engine.
# This wrapper never upgrades or switches the selected SDK.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$sdkRoot = $env:FLUTTER_ROOT
if (-not $sdkRoot) {
    foreach ($candidate in @('.fvm/flutter_sdk', '.local/flutter-3.35.3')) {
        $candidateRoot = Join-Path $projectRoot $candidate
        if (Test-Path -LiteralPath (Join-Path $candidateRoot 'bin/flutter.bat')) {
            $sdkRoot = $candidateRoot
            break
        }
    }
}
if (-not $sdkRoot) {
    $installed = Get-Command flutter -ErrorAction SilentlyContinue
    if ($installed) { $sdkRoot = Split-Path -Parent (Split-Path -Parent $installed.Source) }
}
if (-not $sdkRoot) { throw 'Install Flutter 3.35.3 and set FLUTTER_ROOT to its SDK directory.' }
$flutterName = if ($env:OS -eq 'Windows_NT') { 'flutter.bat' } else { 'flutter' }
$flutterCommand = Join-Path $sdkRoot "bin/$flutterName"
$expectedRevision = 'a402d9a4376add5bc2d6b1e33e53edaae58c07f8'

if (-not (Test-Path -LiteralPath $flutterCommand)) {
    throw 'Flutter was not found in the selected SDK. Set FLUTTER_ROOT to Flutter 3.35.3.'
}
$revision = & git -C $sdkRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $revision.Trim() -ne $expectedRevision) {
    throw 'The selected SDK revision does not match verified Flutter 3.35.3. Set FLUTTER_ROOT to the matching SDK.'
}

Push-Location -LiteralPath $projectRoot
try {
    & $flutterCommand @FlutterArguments
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
