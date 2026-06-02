# ============================================================
#  Navigator AI - one-click bootstrap for Windows (pure ASCII)
#
#  Why this file exists:
#  The real installer (install.ps1) contains Chinese text. On older
#  Windows PowerShell, piping a UTF-8 script straight into `iex` can
#  garble those characters. This tiny launcher is ASCII-only, so it
#  never garbles. It forces the console to UTF-8, then downloads and
#  runs install.ps1 with an explicit UTF-8 decode. End result: the
#  student only pastes one clean line:
#
#     irm https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/go.ps1 | iex
#
#  Detect-only mode: set $env:CHECK_ONLY=1 before running the line above.
# ============================================================

$ErrorActionPreference = 'Stop'
try { chcp 65001 > $null 2>&1 } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$ProgressPreference = 'SilentlyContinue'

$installer = 'https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/install.ps1'

try {
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
    $code = $wc.DownloadString($installer)
}
catch {
    Write-Host ""
    Write-Host "[X] Download failed - cannot reach the installer." -ForegroundColor Red
    Write-Host "    Make sure your browser can open github.com, then run the command again." -ForegroundColor Yellow
    return
}

Invoke-Expression $code
