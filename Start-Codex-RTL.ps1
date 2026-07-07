param([switch]$CreateShortcut)

$ErrorActionPreference = 'Stop'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex Arabic RTL.lnk'
$package = Get-AppxPackage -Name 'OpenAI.Codex' | Select-Object -First 1
if (-not $package) { throw 'The Codex desktop app is not installed.' }
$codexExe = Join-Path $package.InstallLocation 'app\Codex.exe'
if (-not (Test-Path -LiteralPath $codexExe)) { throw "Codex.exe was not found at $codexExe" }

if ($CreateShortcut) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = 'powershell.exe'
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = "$codexExe,0"
    $shortcut.Description = 'Launch Codex with Arabic RTL support'
    $shortcut.Save()
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
    $autoUpdate = Get-ItemPropertyValue -Path $runKey -Name 'CodexArabicRTLAutoUpdate' -ErrorAction SilentlyContinue
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

$mainProcesses = Get-CimInstance Win32_Process -Filter "Name='Codex.exe'" |
    Where-Object { $_.ExecutablePath -eq $codexExe -and $_.CommandLine -notlike '*--type=*' }
foreach ($process in $mainProcesses) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}

for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $stillRunning = Get-CimInstance Win32_Process -Filter "Name='Codex.exe'" |
        Where-Object { $_.ExecutablePath -eq $codexExe -and $_.CommandLine -notlike '*--type=*' }
    if (-not $stillRunning) { break }
    Start-Sleep -Milliseconds 250
}

Start-Process -FilePath $codexExe -ArgumentList @(
    '--remote-debugging-address=127.0.0.1',
    '--remote-debugging-port=9223',
    '--no-first-run'
)
Ensure-BackgroundServices
