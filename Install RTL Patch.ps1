param([switch]$Silent)

$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'ChatGPTArabicRTL'
$legacyInstallDir = Join-Path $env:LOCALAPPDATA 'CodexArabicRTL'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'ChatGPTArabicRTL'
$runValues = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
$autoUpdateEnabled = [bool]($runValues.ChatGPTArabicRTLAutoUpdate -or $runValues.CodexArabicRTLAutoUpdate)
$files = @(
    'codex-rtl-patch.js',
    'watch-codex-rtl.ps1',
    'update-codex-rtl.ps1',
    'auto-update-loop.ps1',
    'Start-Codex-RTL.ps1',
    'version.json'
)

New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTL' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTLAutoUpdate' -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*$legacyInstallDir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item -LiteralPath (Join-Path $installDir 'codex-rtl-patch.mjs') -Force -ErrorAction SilentlyContinue
foreach ($file in $files) {
    $source = Join-Path $PSScriptRoot $file
    if (-not (Test-Path -LiteralPath $source)) { throw "Required file is missing: $file" }
    Copy-Item -LiteralPath $source -Destination $installDir -Force
}

$watcher = Join-Path $installDir 'watch-codex-rtl.ps1'
$command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $watcher
if (-not (Test-Path -LiteralPath $runKey)) { New-Item -Path $runKey | Out-Null }
Set-ItemProperty -Path $runKey -Name $runName -Value $command

Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*codex-rtl-patch.mjs*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*$installDir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
    '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $watcher)
)
if ($autoUpdateEnabled) {
    $loop = Join-Path $installDir 'auto-update-loop.ps1'
    $autoUpdateCommand = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $loop
    Set-ItemProperty -Path $runKey -Name 'ChatGPTArabicRTLAutoUpdate' -Value $autoUpdateCommand
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $loop)
    )
}
& (Join-Path $installDir 'Start-Codex-RTL.ps1') -CreateShortcut
Remove-Item -LiteralPath $legacyInstallDir -Recurse -Force -ErrorAction SilentlyContinue

if (-not $Silent) {
    $version = (Get-Content -Raw -LiteralPath (Join-Path $installDir 'version.json') | ConvertFrom-Json).version
    Write-Host "ChatGPT Arabic RTL patch v$version installed." -ForegroundColor Green
    Write-Host 'Close ChatGPT, then use the new desktop shortcut: ChatGPT Arabic RTL' -ForegroundColor Cyan
}
