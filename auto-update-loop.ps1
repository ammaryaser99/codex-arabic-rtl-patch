$ErrorActionPreference = 'SilentlyContinue'
$mutex = [Threading.Mutex]::new($false, 'Local\ChatGPTArabicRTLAutoUpdate')
if (-not $mutex.WaitOne(0, $false)) { exit 0 }

try {
    while ($true) {
        $updater = Join-Path $PSScriptRoot 'update-codex-rtl.ps1'
        & powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File $updater -Silent
        Start-Sleep -Seconds 21600
    }
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
