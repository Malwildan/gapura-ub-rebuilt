param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$relayPath = Join-Path $PSScriptRoot 'api_relay.py'
$ownedRelay = $null
$ownedBrowserHelper = $null
$relayIdentity = 'gapura-flutter-public-relay-v1'
$headers = @{ Origin = 'http://127.0.0.1:8790' }

function Test-GapuraRelay {
    try {
        $response = Invoke-RestMethod -Uri 'http://127.0.0.1:8791/health' -Headers $headers -TimeoutSec 2
    } catch {
        return $false
    }
    if ($response.service -ne $relayIdentity) {
        throw 'Port 8791 is in use by another service. Stop that service or choose another GAPURA_API relay.'
    }
    return $true
}

$flutterCommand = Join-Path $PSScriptRoot 'flutter-original.ps1'
$pythonCommand = (Get-Command python -ErrorAction Stop).Source
$powershellCommand = (Get-Process -Id $PID).Path

# Refuse an existing listener so the helper cannot attach to somebody else's app.
$portProbe = [System.Net.Sockets.TcpClient]::new()
try {
    $portTask = $portProbe.ConnectAsync('127.0.0.1', 8790)
    if ($portTask.Wait(500) -and $portProbe.Connected) {
        throw 'Port 8790 is already in use. Stop the existing Flutter server before starting this launcher.'
    }
} catch [System.AggregateException] {
    # Connection refused is the expected result for a free development port.
} finally {
    $portProbe.Dispose()
}

try {
    if (-not (Test-GapuraRelay)) {
        $relayLog = Join-Path $env:TEMP "gapura-flutter-relay-$PID.log"
        $relayErrors = Join-Path $env:TEMP "gapura-flutter-relay-$PID.err.log"
        $ownedRelay = Start-Process -FilePath $pythonCommand -ArgumentList @('"' + $relayPath + '"') `
            -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $relayLog -RedirectStandardError $relayErrors
        $ready = $false
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            if ($ownedRelay.HasExited) {
                throw "Gapura relay could not start. See $relayErrors"
            }
            if (Test-GapuraRelay) {
                $ready = $true
                break
            }
            Start-Sleep -Milliseconds 200
        }
        if (-not $ready) {
            throw "Gapura relay did not become ready. See $relayErrors"
        }
    }
    Push-Location -LiteralPath $projectRoot
    try {
        $browserHelperPath = Join-Path $PSScriptRoot 'open-browser.ps1'
        $browserErrors = Join-Path $env:TEMP "gapura-flutter-browser-$PID.err.log"
        $ownedBrowserHelper = Start-Process -FilePath $powershellCommand `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $browserHelperPath + '"')) `
            -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru `
            -RedirectStandardError $browserErrors
        Write-Host 'Opening Gapura in a dedicated Edge profile when Flutter is ready.'
        Write-Host 'Sign in on akun.ub.ac.id/dashboard in that Edge window, then connect in Gapura.'
        Write-Host "If Edge does not open, see $browserErrors"
        & $flutterCommand run -d web-server --web-hostname 127.0.0.1 --web-port 8790 @FlutterArguments
        $flutterExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
} finally {
    if ($null -ne $ownedBrowserHelper -and -not $ownedBrowserHelper.HasExited) {
        Stop-Process -Id $ownedBrowserHelper.Id -ErrorAction SilentlyContinue
    }
    if ($null -ne $ownedRelay -and -not $ownedRelay.HasExited) {
        Stop-Process -Id $ownedRelay.Id -ErrorAction SilentlyContinue
    }
}

if ($null -ne $flutterExitCode) { exit $flutterExitCode }
