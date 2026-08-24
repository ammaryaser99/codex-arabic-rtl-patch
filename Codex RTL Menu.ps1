$ErrorActionPreference = 'Continue'

do {
    Clear-Host
    Write-Host '=========================================' -ForegroundColor Cyan
    Write-Host '      ChatGPT Arabic RTL Patch Menu      ' -ForegroundColor Cyan
    Write-Host '=========================================' -ForegroundColor Cyan
    Write-Host '1. Install / repair patch'
    Write-Host '2. Enable automatic patch updates'
    Write-Host '3. Check GitHub for updates now'
    Write-Host '4. Uninstall patch'
    Write-Host '0. Exit'
    Write-Host
    $choice = Read-Host 'Choose an option'

    switch ($choice) {
        '1' { & (Join-Path $PSScriptRoot 'Install RTL Patch.ps1') }
        '2' { & (Join-Path $PSScriptRoot 'Enable Auto Update.ps1') }
        '3' { & (Join-Path $PSScriptRoot 'update-codex-rtl.ps1') }
        '4' { & (Join-Path $PSScriptRoot 'Uninstall RTL Patch.ps1') }
        '0' { break }
        default { Write-Host 'Invalid option.' -ForegroundColor Yellow }
    }

    if ($choice -ne '0') {
        Write-Host
        Read-Host 'Press Enter to return to the menu' | Out-Null
    }
} while ($choice -ne '0')
