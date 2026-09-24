# MCP over HTTP against one long-lived GABS instance.
# HTTP avoids the stdio stream-read problems and keeps every call in the SAME gabs
# process, which is required: a second gabs instance sees the first one's runtime claim
# and refuses to connect.

$script:GabsProc = $null
$script:McpListenPort = 0

function Open-McpHttp {
    param(
        [string]$GabsExe = 'E:\MBmod\CombatBrain Autonomous test harness\_source-cache\gabs\gabs.exe',
        [string]$ConfigDir = 'E:\MBmod\CombatBrain Autonomous test harness\gabs-config',
        [int]$ListenPort = 19580
    )

    $script:McpListenPort = $ListenPort
    $script:GabsProc = Start-Process -FilePath $GabsExe `
        -ArgumentList "server --http localhost:$ListenPort --configDir `"$ConfigDir`" --log-level warn" `
        -PassThru -WindowStyle Hidden

    # wait for the endpoint to accept connections
    $deadline = (Get-Date).AddSeconds(40)
    while ((Get-Date) -lt $deadline) {
        try {
            [void](Invoke-RestMethod -Uri "http://localhost:$ListenPort/mcp" -Method Post `
                -Body '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cbath-run","version":"1.0.0"}}}' `
                -ContentType 'application/json' -TimeoutSec 10)
            return $script:GabsProc.Id
        } catch {
            Start-Sleep -Milliseconds 800
        }
    }
    throw "gabs HTTP endpoint never became ready on port $ListenPort"
}

function Invoke-McpHttp {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [hashtable]$Arguments = @{},
        [int]$TimeoutSec = 60
    )

    $body = @{
        jsonrpc = '2.0'
        id      = [int](Get-Date).Ticks % 100000
        method  = 'tools/call'
        params  = @{ name = $Tool; arguments = $Arguments }
    } | ConvertTo-Json -Depth 6 -Compress

    $r = Invoke-RestMethod -Uri "http://localhost:$($script:McpListenPort)/mcp" -Method Post `
        -Body $body -ContentType 'application/json' -TimeoutSec $TimeoutSec
    return ($r | ConvertTo-Json -Depth 10 -Compress)
}

function Close-McpHttp {
    if ($null -ne $script:GabsProc -and -not $script:GabsProc.HasExited) {
        Stop-Process -Id $script:GabsProc.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    $script:GabsProc = $null
}
