param([switch]$CreateShortcut)

$ErrorActionPreference = 'Stop'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT Arabic RTL.lnk'
$legacyShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex Arabic RTL.lnk'
$package = Get-AppxPackage | Where-Object { $_.Name -eq 'OpenAI.Codex' } | Select-Object -First 1
if (-not $package) { throw 'The ChatGPT desktop app is not installed.' }

$appDirectory = Join-Path $package.InstallLocation 'app'
$appExe = @('ChatGPT.exe', 'Codex.exe') |
    ForEach-Object { Join-Path $appDirectory $_ } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $appExe) { throw "ChatGPT.exe was not found under $appDirectory" }
$processName = [IO.Path]::GetFileNameWithoutExtension($appExe)

if ($CreateShortcut) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = 'powershell.exe'
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = "$appExe,0"
    $shortcut.Description = 'Launch ChatGPT with Arabic RTL support'
    $shortcut.Save()
    Remove-Item -LiteralPath $legacyShortcutPath -Force -ErrorAction SilentlyContinue
    exit 0
}

function Test-BackgroundScriptRunning([string]$ScriptPath) {
    return [bool](Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like "*$ScriptPath*" })
}

function Start-BackgroundScript([string]$ScriptPath) {
    if (-not (Test-Path -LiteralPath $ScriptPath)) { return }
    if (Test-BackgroundScriptRunning $ScriptPath) { return }
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $ScriptPath)
    )
}

function Ensure-BackgroundServices {
    Start-BackgroundScript (Join-Path $PSScriptRoot 'watch-codex-rtl.ps1')
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $runValues = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
    $autoUpdate = $runValues.ChatGPTArabicRTLAutoUpdate
    if (-not $autoUpdate) {
        $autoUpdate = $runValues.CodexArabicRTLAutoUpdate
    }
    if ($autoUpdate) {
        Start-BackgroundScript (Join-Path $PSScriptRoot 'auto-update-loop.ps1')
    }
}

Ensure-BackgroundServices

$debuggingReady = $false
foreach ($port in @(9223, 9222, 9224, 9225)) {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json" -TimeoutSec 1
        $targets = @($response | ForEach-Object { $_ })
        if ($targets | Where-Object { $_.type -eq 'page' -and $_.url -like 'app://-/*' }) {
            $debuggingReady = $true
            break
        }
    } catch { }
}
if ($debuggingReady) {
    Start-Sleep -Milliseconds 500
    exit 0
}

$mainProcesses = Get-CimInstance Win32_Process -Filter ("Name='{0}.exe'" -f $processName) |
    Where-Object { $_.ExecutablePath -eq $appExe -and $_.CommandLine -notlike '*--type=*' }
foreach ($process in $mainProcesses) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}

for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $stillRunning = Get-CimInstance Win32_Process -Filter ("Name='{0}.exe'" -f $processName) |
        Where-Object { $_.ExecutablePath -eq $appExe -and $_.CommandLine -notlike '*--type=*' }
    if (-not $stillRunning) { break }
    Start-Sleep -Milliseconds 250
}

Start-Process -FilePath $appExe -ArgumentList @(
    '--remote-debugging-address=127.0.0.1',
    '--remote-debugging-port=9223',
    '--no-first-run'
)
Ensure-BackgroundServices
