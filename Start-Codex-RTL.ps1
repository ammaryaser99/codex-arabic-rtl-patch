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

$debuggingReady = $false
foreach ($port in @(9223, 9222, 9224, 9225)) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$port/json" -TimeoutSec 1
        if ($response.StatusCode -eq 200) { $debuggingReady = $true; break }
    } catch { }
}
if ($debuggingReady) { exit 0 }

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

