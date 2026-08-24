param([switch]$Silent)

$ErrorActionPreference = 'Stop'
$repo = 'ammaryaser99/codex-arabic-rtl-patch'
$preferredInstallDir = Join-Path $env:LOCALAPPDATA 'ChatGPTArabicRTL'
$legacyInstallDir = Join-Path $env:LOCALAPPDATA 'CodexArabicRTL'
$installDir = if (Test-Path -LiteralPath (Join-Path $preferredInstallDir 'version.json')) {
    $preferredInstallDir
} elseif (Test-Path -LiteralPath (Join-Path $legacyInstallDir 'version.json')) {
    $legacyInstallDir
} else {
    $preferredInstallDir
}
$manifestPath = Join-Path $installDir 'version.json'
$apiHeaders = @{ 'User-Agent' = 'ChatGPT-Arabic-RTL-Patch' }
$cacheBust = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

function Write-UpdateStatus([string]$message, [ConsoleColor]$color = 'Gray') {
    if (-not $Silent) { Write-Host $message -ForegroundColor $color }
}

try {
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw 'The RTL patch is not installed. Run option 1 first.'
    }

    $local = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=20&cache=$cacheBust" -Headers $apiHeaders -UseBasicParsing
    $releases = @($releaseResponse | ForEach-Object { $_ })
    $release = $releases | Where-Object { -not $_.draft } | Select-Object -First 1
    if (-not $release) { throw 'No published GitHub release was found.' }
    $remoteVersion = [version]($release.tag_name -replace '^v', '')
    if ($remoteVersion -le [version]$local.version) {
        Write-UpdateStatus "Already current (v$($local.version))." Green
        exit 0
    }

    $asset = $release.assets | Where-Object { $_.name -eq 'Codex-Arabic-RTL-Patch.zip' } | Select-Object -First 1
    if (-not $asset) { throw "Release v$remoteVersion does not contain Codex-Arabic-RTL-Patch.zip." }

    $temp = Join-Path $env:TEMP ("ChatGPTArabicRTL-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    try {
        $archive = Join-Path $temp 'patch.zip'
        $expanded = Join-Path $temp 'expanded'
        Invoke-WebRequest -Uri $asset.browser_download_url -Headers $apiHeaders -UseBasicParsing -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
        $remoteManifestPath = Join-Path $expanded 'version.json'
        if (-not (Test-Path -LiteralPath $remoteManifestPath)) { throw 'The release ZIP has no version.json.' }
        $remote = Get-Content -Raw -LiteralPath $remoteManifestPath | ConvertFrom-Json
        if ([version]$remote.version -ne $remoteVersion) { throw 'The release tag and manifest version do not match.' }

        Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
            Where-Object { $_.CommandLine -like '*codex-rtl-patch.mjs*' } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
            Where-Object {
                $_.ProcessId -ne $PID -and
                ($_.CommandLine -like '*ChatGPTArabicRTL*watch-codex-rtl.ps1*' -or
                 $_.CommandLine -like '*CodexArabicRTL*watch-codex-rtl.ps1*')
            } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

        foreach ($file in $remote.files) {
            if ($file -notmatch '^[A-Za-z0-9._-]+$') { throw "Unsafe update filename: $file" }
            Copy-Item -LiteralPath (Join-Path $expanded $file) -Destination $installDir -Force
        }

        $launcher = Join-Path $installDir 'Start-Codex-RTL.ps1'
        if (Test-Path -LiteralPath $launcher) { & $launcher -CreateShortcut }
        if (Test-Path -LiteralPath (Join-Path $preferredInstallDir 'version.json')) {
            $installDir = $preferredInstallDir
        }
        $watcher = Join-Path $installDir 'watch-codex-rtl.ps1'
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $watcher)
        )
        Write-UpdateStatus "Updated from v$($local.version) to v$remoteVersion." Green
    }
    finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-UpdateStatus "Update check failed: $($_.Exception.Message)" Red
    if ($Silent) { exit 1 }
    throw
}
