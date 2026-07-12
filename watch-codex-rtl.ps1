$ErrorActionPreference = 'SilentlyContinue'
$logPath = Join-Path $PSScriptRoot 'watcher.log'
function Write-PatchLog([string]$Message) {
    Add-Content -LiteralPath $logPath -Value ("{0:u} {1}" -f (Get-Date), $Message) -ErrorAction SilentlyContinue
}
$mutex = [Threading.Mutex]::new($false, 'Local\ChatGPTArabicRTLPatch')
if (-not $mutex.WaitOne(0, $false)) { exit 0 }
Add-Type -AssemblyName System.Web.Extensions
$serializer = [Web.Script.Serialization.JavaScriptSerializer]::new()
$serializer.MaxJsonLength = 1048576

function Send-CdpMessage {
    param(
        [Net.WebSockets.ClientWebSocket]$Socket,
        [int]$Id,
        [string]$Method,
        [string]$Source
    )
    $parameters = [Collections.Generic.Dictionary[string,object]]::new()
    $parameters.Add('source', $Source)
    if ($Method -eq 'Runtime.evaluate') {
        $parameters.Remove('source')
        $parameters.Add('expression', $Source)
    }
    $message = [Collections.Generic.Dictionary[string,object]]::new()
    $message.Add('id', $Id)
    $message.Add('method', $Method)
    $message.Add('params', $parameters)
    $json = $serializer.Serialize($message)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    for ($offset = 0; $offset -lt $bytes.Length; $offset += 1024) {
        $count = [Math]::Min(1024, $bytes.Length - $offset)
        $isFinal = ($offset + $count -ge $bytes.Length)
        $segment = [ArraySegment[byte]]::new($bytes, $offset, $count)
        $Socket.SendAsync($segment, [Net.WebSockets.WebSocketMessageType]::Text, $isFinal, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    }
}

try {
    Write-PatchLog 'Watcher started.'
    $source = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'codex-rtl-patch.js')
    $clients = @{}

    while ($true) {
        $targets = @()
        foreach ($hostName in @('localhost', '127.0.0.1')) {
            foreach ($port in @(9223, 9222, 9224, 9225)) {
                try {
                    $response = Invoke-RestMethod -Uri "http://${hostName}:$port/json" -TimeoutSec 1
                    $targets = @($response | ForEach-Object { $_ })
                    if ($targets.Count -gt 0) { break }
                } catch { }
            }
            if ($targets.Count -gt 0) { break }
        }

        $liveIds = @($targets | ForEach-Object { $_.id })
        foreach ($id in @($clients.Keys)) {
            if ($id -notin $liveIds -or $clients[$id].State -ne [Net.WebSockets.WebSocketState]::Open) {
                $clients[$id].Dispose()
                $clients.Remove($id)
            }
        }

        foreach ($target in $targets) {
            if ($target.type -ne 'page' -or $target.url -notlike 'app://-/*' -or $clients.ContainsKey($target.id)) { continue }
            try {
                $socket = [Net.WebSockets.ClientWebSocket]::new()
                $socket.ConnectAsync([uri]$target.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
                Send-CdpMessage -Socket $socket -Id 1 -Method 'Page.addScriptToEvaluateOnNewDocument' -Source $source
                Send-CdpMessage -Socket $socket -Id 2 -Method 'Runtime.evaluate' -Source $source
                $clients[$target.id] = $socket
                Write-PatchLog ("Patched target {0}." -f $target.id)
            } catch {
                Write-PatchLog ("Target {0} failed: {1}" -f $target.id, $_.Exception.Message)
            }
        }
        Start-Sleep -Milliseconds 1500
    }
}
finally {
    foreach ($socket in $clients.Values) { $socket.Dispose() }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
