param([int]$Port = 8792)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'flutter-original.ps1') run -d web-server -t lib/demo_main.dart --web-hostname 127.0.0.1 --web-port $Port
exit $LASTEXITCODE
