# A long-lived MCP-over-stdio session against one GABS instance.
# The same gabs process must do both games_start and tools/call, otherwise the second
# instance sees the first one's runtime claim and refuses to connect.
#
# Usage (dot-source then use):
#   . .\mcp-session.ps1
#   Open-McpSession -GabsExe <exe> -ConfigDir <dir>
#   Invoke-Mcp '{"jsonrpc":"2.0","id":1,...}'      # returns the raw response line
#   Close-McpSession

$script:McpProc = $null
$script:McpId = 0

function Open-McpSession {
    param(
        [string]$GabsExe = 'E:\MBmod\CombatBrain Autonomous test harness\_source-cache\gabs\gabs.exe',
        [string]$ConfigDir = 'E:\MBmod\CombatBrain Autonomous test harness\gabs-config'
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $GabsExe
    $psi.Arguments = "server stdio --configDir `"$ConfigDir`" --log-level warn"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $script:McpProc = [System.Diagnostics.Process]::Start($psi)
    $script:McpId = 0

    $init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cbath-run","version":"1.0.0"}}}'
    [void](Invoke-Mcp $init 1)
    return $script:McpProc.Id
}

function Invoke-Mcp {
    param(
        [Parameter(Mandatory = $true)][string]$Request,
        [int]$Id = 0,
        [int]$TimeoutSec = 90
    )

    if ($null -eq $script:McpProc) { throw 'session not open' }

    if ($Id -eq 0) {
        $script:McpId++
        $Id = $script:McpId
        # rewrite the request id so each call is unique within the session
        $Request = [regex]::Replace($Request, '"id":\d+', ('"id":' + $Id), 1)
        if ($Request -notmatch '"id":') {
            $Request = $Request.TrimEnd('}') + ', "id":' + $Id + '}'
        }
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Request + "`n")
    $script:McpProc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $script:McpProc.StandardInput.BaseStream.Flush()

    # Non-blocking poll: ReadLine() blocks forever when gabs sends nothing, so check
    # Peek() before reading.
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $peeked = -1
        try { $peeked = $script:McpProc.StandardOutput.Peek() } catch { return $null }
        if ($peeked -lt 0) { Start-Sleep -Milliseconds 200; continue }

        $line = $script:McpProc.StandardOutput.ReadLine()
        if ($null -eq $line) { return $null }
        if ($line.Trim() -eq '') { continue }
        $id = $null
        try { $id = ($line | ConvertFrom-Json).id } catch { $id = $null }
        if ($id -ne $null -and [int]$id -eq $Id) { return $line }
    }
    return $null
}

function Close-McpSession {
    if ($null -ne $script:McpProc) {
        try { $script:McpProc.StandardInput.Close() } catch { }
        Start-Sleep -Milliseconds 500
        if (-not $script:McpProc.HasExited) { $script:McpProc.Kill() }
        $script:McpProc.WaitForExit(5000) | Out-Null
        $script:McpProc = $null
    }
}
