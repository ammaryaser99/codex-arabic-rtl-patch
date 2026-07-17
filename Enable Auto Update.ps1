$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'ChatGPTArabicRTL'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

if (-not (Test-Path -LiteralPath (Join-Path $installDir 'codex-rtl-patch.js'))) {
    & (Join-Path $PSScriptRoot 'Install RTL Patch.ps1') -Silent
}

foreach ($file in @('update-codex-rtl.ps1', 'auto-update-loop.ps1', 'version.json')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $installDir -Force
}

$loop = Join-Path $installDir 'auto-update-loop.ps1'
$command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $loop
if (-not (Test-Path -LiteralPath $runKey)) { New-Item -Path $runKey | Out-Null }
Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTLAutoUpdate' -ErrorAction SilentlyContinue
Set-ItemProperty -Path $runKey -Name 'ChatGPTArabicRTLAutoUpdate' -Value $command

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*ChatGPTArabicRTL*auto-update-loop.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $loop)
)

Write-Host 'Automatic patch updates enabled. GitHub will be checked every 6 hours.' -ForegroundColor Green
