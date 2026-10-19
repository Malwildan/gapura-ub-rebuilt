param(
    [string]$Device = 'chrome',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$flutterWrapper = Join-Path $PSScriptRoot 'flutter-original.ps1'
& $flutterWrapper run --target=lib/guest_demo_main.dart -d $Device @FlutterArguments
exit $LASTEXITCODE
