$ErrorActionPreference = 'SilentlyContinue'
$installDir = Join-Path $env:LOCALAPPDATA 'ChatGPTArabicRTL'
$legacyInstallDir = Join-Path $env:LOCALAPPDATA 'CodexArabicRTL'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT Arabic RTL.lnk'
$legacyShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex Arabic RTL.lnk'

Remove-ItemProperty -Path $runKey -Name 'ChatGPTArabicRTL' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $runKey -Name 'ChatGPTArabicRTLAutoUpdate' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTL' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTLAutoUpdate' -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*codex-rtl-patch.mjs*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object {
        $_.ProcessId -ne $PID -and
        ($_.CommandLine -like "*$installDir*" -or $_.CommandLine -like "*$legacyInstallDir*")
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $legacyInstallDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $shortcutPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $legacyShortcutPath -Force -ErrorAction SilentlyContinue

Write-Host 'ChatGPT Arabic RTL patch removed. Restart ChatGPT to clear the current page.' -ForegroundColor Yellow
