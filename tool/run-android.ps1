param(
    [string]$Device,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$flutterCommand = Join-Path $PSScriptRoot 'flutter-original.ps1'

Push-Location -LiteralPath $projectRoot
try {
    $configArguments = @()
    if (Test-Path -LiteralPath '.local/native-config.json') {
        $configArguments = @('--dart-define-from-file=.local/native-config.json')
    } else {
        Write-Host 'Starting without private service configuration. See config/native.example.json.'
    }
    if (-not $Device) {
        $devices = & $flutterCommand devices --machine | ConvertFrom-Json
        $androidDevices = @($devices | Where-Object { $_.targetPlatform -like 'android-*' -and $_.isSupported })
        if ($androidDevices.Count -eq 0) {
            throw 'No Android device is connected. Start an Android emulator or connect a phone with USB debugging, then run this command again.'
        }
        if ($androidDevices.Count -gt 1) {
            throw 'Multiple Android devices are connected. Pass -Device with the desired ID from flutter devices.'
        }
        $Device = $androidDevices[0].id
    }
    & $flutterCommand run -d $Device @configArguments @FlutterArguments
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($null -ne $flutterExitCode) { exit $flutterExitCode }
