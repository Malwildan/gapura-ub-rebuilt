param(
    [string]$AppUrl = 'http://127.0.0.1:8790',
    [int]$WaitSeconds = 180
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$extensionPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'account-extension')).Path
$browserProfile = Join-Path $projectRoot '.local/edge-profile'
$edgeCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft/Edge/Application/msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft/Edge/Application/msedge.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft/Edge/Application/msedge.exe')
)
$edgeCommand = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $edgeCommand) { throw 'Microsoft Edge was not found. Install Edge or open the Flutter server manually in Chrome with the account extension loaded.' }
if (-not (Test-Path -LiteralPath (Join-Path $extensionPath 'manifest.json'))) { throw 'The account bridge extension is missing.' }

$deadline = [DateTime]::UtcNow.AddSeconds($WaitSeconds)
$ready = $false
while ([DateTime]::UtcNow -lt $deadline) {
    try {
        $response = Invoke-WebRequest -Uri $AppUrl -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200 -and $response.Content -match 'account_bridge\.js') {
            $ready = $true
            break
        }
    } catch {}
    Start-Sleep -Milliseconds 700
}
if (-not $ready) { throw "The Gapura Flutter server did not become ready at $AppUrl." }

New-Item -ItemType Directory -Path $browserProfile -Force | Out-Null
# Launch independently from Flutter's Edge device driver, which disables extensions.
# This profile belongs only to this local reconstruction and keeps its own UB login.
$browserArguments = @(
    ('--user-data-dir="' + $browserProfile + '"'),
    ('--load-extension="' + $extensionPath + '"'),
    ('--disable-extensions-except="' + $extensionPath + '"'),
    '--no-first-run',
    '--no-default-browser-check',
    ('"' + $AppUrl + '"')
)
Start-Process -FilePath $edgeCommand -ArgumentList $browserArguments | Out-Null
