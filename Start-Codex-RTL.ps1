param(
    [switch]$CreateShortcut,
    [switch]$DiagnosticsOnly,
    [switch]$ActivationProbe
)

$ErrorActionPreference = 'Stop'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ChatGPT Arabic RTL.lnk'
$legacyShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Codex Arabic RTL.lnk'
$logPath = Join-Path $PSScriptRoot 'launcher.log'

function Write-LauncherLog([string]$Message) {
    Add-Content -LiteralPath $logPath -Value ("{0:u} {1}" -f (Get-Date), $Message) -ErrorAction SilentlyContinue
}

$package = Get-AppxPackage | Where-Object { $_.Name -eq 'OpenAI.Codex' } | Select-Object -First 1
if (-not $package) { throw 'The ChatGPT desktop app is not installed.' }

$appDirectory = Join-Path $package.InstallLocation 'app'
$appExe = @('ChatGPT.exe', 'Codex.exe') |
    ForEach-Object { Join-Path $appDirectory $_ } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not $appExe) { throw "ChatGPT.exe was not found under $appDirectory" }
$processName = [IO.Path]::GetFileNameWithoutExtension($appExe)
$manifest = Get-AppxPackageManifest -Package $package.PackageFullName
$application = @($manifest.Package.Applications.Application) |
    Where-Object { $_.EntryPoint -eq 'Windows.FullTrustApplication' } |
    Select-Object -First 1
if (-not $application) { throw 'The ChatGPT packaged-app entry point was not found.' }
$appUserModelId = '{0}!{1}' -f $package.PackageFamilyName, $application.Id

if ($CreateShortcut) {
    $shortcutLauncherPath = $PSCommandPath
    $shortcutWorkingDirectory = $PSScriptRoot
    $preferredInstallDir = Join-Path $env:LOCALAPPDATA 'ChatGPTArabicRTL'
    $legacyInstallDir = Join-Path $env:LOCALAPPDATA 'CodexArabicRTL'
    $currentDirectory = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
    $legacyDirectory = [IO.Path]::GetFullPath($legacyInstallDir).TrimEnd('\')

    # The v1.4.2 updater runs the newly downloaded launcher from the legacy
    # install directory. Use that guaranteed callback to migrate existing
    # auto-update users before their next Windows sign-in.
    if ($currentDirectory -ieq $legacyDirectory) {
        New-Item -ItemType Directory -Path $preferredInstallDir -Force | Out-Null
        $releaseManifest = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'version.json') | ConvertFrom-Json
        foreach ($file in $releaseManifest.files) {
            if ($file -notmatch '^[A-Za-z0-9._-]+$') { throw "Unsafe migration filename: $file" }
            $source = Join-Path $PSScriptRoot $file
            if (-not (Test-Path -LiteralPath $source)) { throw "Migration file is missing: $file" }
            Copy-Item -LiteralPath $source -Destination $preferredInstallDir -Force
        }

        $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        if (-not (Test-Path -LiteralPath $runKey)) { New-Item -Path $runKey | Out-Null }
        $runValues = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
        $autoUpdateEnabled = [bool]($runValues.ChatGPTArabicRTLAutoUpdate -or $runValues.CodexArabicRTLAutoUpdate)
        $watcher = Join-Path $preferredInstallDir 'watch-codex-rtl.ps1'
        $watcherCommand = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $watcher
        Set-ItemProperty -Path $runKey -Name 'ChatGPTArabicRTL' -Value $watcherCommand
        if ($autoUpdateEnabled) {
            $loop = Join-Path $preferredInstallDir 'auto-update-loop.ps1'
            $loopCommand = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $loop
            Set-ItemProperty -Path $runKey -Name 'ChatGPTArabicRTLAutoUpdate' -Value $loopCommand
        }
        Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTL' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $runKey -Name 'CodexArabicRTLAutoUpdate' -ErrorAction SilentlyContinue

        $shortcutLauncherPath = Join-Path $preferredInstallDir 'Start-Codex-RTL.ps1'
        $shortcutWorkingDirectory = $preferredInstallDir
        Write-LauncherLog 'Migrated the legacy CodexArabicRTL installation to ChatGPTArabicRTL.'
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = 'powershell.exe'
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $shortcutLauncherPath
    $shortcut.WorkingDirectory = $shortcutWorkingDirectory
    $shortcut.IconLocation = "$appExe,0"
    $shortcut.Description = 'Launch ChatGPT with Arabic RTL support'
    $shortcut.Save()
    Remove-Item -LiteralPath $legacyShortcutPath -Force -ErrorAction SilentlyContinue
    Write-LauncherLog ("Desktop shortcut refreshed for package {0}." -f $package.Version)
    exit 0
}

function Get-AppProcesses {
    return @(Get-CimInstance Win32_Process -Filter ("Name='{0}.exe'" -f $processName) |
        Where-Object { $_.ExecutablePath -eq $appExe })
}

function Get-MainAppProcesses {
    return @(Get-AppProcesses | Where-Object { $_.CommandLine -notlike '*--type=*' })
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
    Write-LauncherLog ("Restarted background service {0}." -f [IO.Path]::GetFileName($ScriptPath))
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

function Get-DebugTarget {
    # Avoid Invoke-RestMethod here. On some Windows proxy configurations each
    # closed localhost port can consume the full timeout, making the shortcut
    # appear dead and allowing repeated clicks to race with each other.
    foreach ($port in @(9223, 9222, 9224, 9225)) {
        $response = $null
        $reader = $null
        try {
            $request = [Net.HttpWebRequest]::Create("http://127.0.0.1:$port/json")
            $request.Proxy = $null
            $request.Timeout = 350
            $request.ReadWriteTimeout = 350
            $response = $request.GetResponse()
            $reader = [IO.StreamReader]::new($response.GetResponseStream())
            $targets = @($reader.ReadToEnd() | ConvertFrom-Json)
            $target = $targets | Where-Object {
                $_.type -eq 'page' -and $_.url -like 'app://-/*'
            } | Select-Object -First 1
            if ($target) {
                return [pscustomobject]@{ Port = $port; Target = $target }
            }
        }
        catch { }
        finally {
            if ($reader) { $reader.Dispose() }
            if ($response) { $response.Dispose() }
        }
    }
    return $null
}

function Wait-ForAppExit([int]$TimeoutMilliseconds = 10000) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        if (@(Get-AppProcesses).Count -eq 0) { return $true }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    return $false
}

function Initialize-PackagedAppActivator {
    if ('ChatGptArabicRtl.PackagedAppActivator' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ChatGptArabicRtl
{
    [Flags]
    public enum ActivateOptions
    {
        None = 0x00000000
    }

    [ComImport]
    [Guid("2e941141-7f97-4756-ba1d-9decde894a3d")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IApplicationActivationManager
    {
        [PreserveSig]
        int ActivateApplication(
            [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments,
            ActivateOptions options,
            out uint processId);
    }

    [ComImport]
    [Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
    public class ApplicationActivationManager
    {
    }

    public static class PackagedAppActivator
    {
        public static uint Activate(string appUserModelId, string arguments)
        {
            IApplicationActivationManager manager =
                (IApplicationActivationManager)new ApplicationActivationManager();
            try
            {
                uint processId;
                int result = manager.ActivateApplication(
                    appUserModelId,
                    arguments ?? String.Empty,
                    ActivateOptions.None,
                    out processId);
                if (result < 0)
                {
                    Marshal.ThrowExceptionForHR(result);
                }
                return processId;
            }
            finally
            {
                Marshal.FinalReleaseComObject(manager);
            }
        }
    }
}
'@
}

function Start-PackagedApp([string]$Arguments) {
    Initialize-PackagedAppActivator
    return [ChatGptArabicRtl.PackagedAppActivator]::Activate($appUserModelId, $Arguments)
}

function Start-NormalAppFallback {
    try {
        $fallbackProcessId = Start-PackagedApp ''
        Write-LauncherLog ("RTL launch failed; activated ChatGPT normally as a fallback (PID {0})." -f $fallbackProcessId)
    }
    catch {
        Write-LauncherLog ("Normal fallback failed: {0}" -f $_.Exception.Message)
    }
}

$launcherMutex = [Threading.Mutex]::new($false, 'Local\ChatGPTArabicRTLLauncher')
$hasLauncherMutex = $false
try {
    try {
        $hasLauncherMutex = $launcherMutex.WaitOne(0, $false)
    }
    catch [Threading.AbandonedMutexException] {
        $hasLauncherMutex = $true
    }

    if (-not $hasLauncherMutex) {
        Write-LauncherLog 'Ignored a repeated shortcut click because a launch is already in progress.'
        exit 0
    }

    Write-LauncherLog ("Launcher started for package {0}." -f $package.Version)

    if ($ActivationProbe) {
        $activationProcessId = Start-PackagedApp ''
        Write-LauncherLog ("Packaged-app activation probe succeeded with PID {0}." -f $activationProcessId)
        [pscustomobject]@{
            AppUserModelId = $appUserModelId
            ProcessId = $activationProcessId
        }
        exit 0
    }

    Ensure-BackgroundServices

    $debugTarget = Get-DebugTarget
    if ($DiagnosticsOnly) {
        $watcherPath = Join-Path $PSScriptRoot 'watch-codex-rtl.ps1'
        $updaterPath = Join-Path $PSScriptRoot 'auto-update-loop.ps1'
        [pscustomobject]@{
            PackageVersion = [string]$package.Version
            AppExecutable = $appExe
            MainProcessCount = @(Get-MainAppProcesses).Count
            DebugPort = if ($debugTarget) { $debugTarget.Port } else { $null }
            DebugTargetUrl = if ($debugTarget) { $debugTarget.Target.url } else { $null }
            WatcherRunning = Test-BackgroundScriptRunning $watcherPath
            AutoUpdaterRunning = Test-BackgroundScriptRunning $updaterPath
            ShortcutPath = $shortcutPath
        }
        exit 0
    }

    if ($debugTarget) {
        Write-LauncherLog ("ChatGPT is already ready on debugging port {0}." -f $debugTarget.Port)
        Start-Sleep -Milliseconds 400
        exit 0
    }

    $existingProcesses = @(Get-AppProcesses)
    if ($existingProcesses.Count -gt 0) {
        Write-LauncherLog ("Stopping {0} process(es) from the non-RTL ChatGPT instance." -f $existingProcesses.Count)
        foreach ($process in $existingProcesses) {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
        }
        if (-not (Wait-ForAppExit)) {
            Write-LauncherLog 'Timed out waiting for the existing ChatGPT process tree to exit.'
            Start-NormalAppFallback
            exit 1
        }
    }

    $launchedAt = Get-Date
    try {
        $activationArguments = @(
            '--remote-debugging-address=127.0.0.1',
            '--remote-debugging-port=9223',
            '--no-first-run'
        ) -join ' '
        $activatedProcessId = Start-PackagedApp $activationArguments
        Write-LauncherLog ("Windows activated the RTL ChatGPT instance with PID {0}." -f $activatedProcessId)
    }
    catch {
        Write-LauncherLog ("RTL process launch failed: {0}" -f $_.Exception.Message)
        Start-NormalAppFallback
        exit 1
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    $mainProcessSeen = $false
    do {
        $mainProcessSeen = @(Get-MainAppProcesses).Count -gt 0
        $debugTarget = Get-DebugTarget
        if ($debugTarget) { break }
        Start-Sleep -Milliseconds 300
    } while ([DateTime]::UtcNow -lt $deadline)

    if (-not $mainProcessSeen) {
        Write-LauncherLog ("The RTL process launched at {0:u} exited before a main window was created." -f $launchedAt)
        Start-NormalAppFallback
        exit 1
    }

    if (-not $debugTarget) {
        Write-LauncherLog 'ChatGPT opened, but its debugging endpoint did not become ready within 20 seconds.'
        exit 2
    }

    Ensure-BackgroundServices
    Write-LauncherLog ("ChatGPT opened with RTL debugging target {0} on port {1}." -f $debugTarget.Target.id, $debugTarget.Port)
}
catch {
    Write-LauncherLog ("Launcher error: {0}" -f $_.Exception.Message)
    Start-NormalAppFallback
    exit 1
}
finally {
    if ($hasLauncherMutex) {
        $launcherMutex.ReleaseMutex()
    }
    $launcherMutex.Dispose()
}
