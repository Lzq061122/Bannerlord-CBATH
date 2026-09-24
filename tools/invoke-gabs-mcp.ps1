# Minimal MCP-over-stdio driver for GABS.
# Sends initialize -> tools/list -> tools/call sequences and prints raw responses.
# Usage: powershell -File invoke-gabs-mcp.ps1 -ScriptFile <path to jsonl of requests>

param(
    [string]$GabsExe = 'E:\MBmod\CombatBrain Autonomous test harness\_source-cache\gabs\gabs.exe',
    [string]$ConfigDir = 'E:\MBmod\CombatBrain Autonomous test harness\gabs-config',
    [string]$ScriptFile
)

$ErrorActionPreference = 'Stop'
$requests = Get-Content $ScriptFile | Where-Object { $_.Trim().StartsWith('{') }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $GabsExe
$psi.Arguments = "server stdio --configDir `"$ConfigDir`" --log-level warn"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$p = [System.Diagnostics.Process]::Start($psi)
$p.PriorityClass = 'Normal'

function Send-Line([string]$s) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($s + "`n")
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.BaseStream.Flush()
}

function Read-Line([int]$timeoutMs = 20000) {
    $task = $p.StandardOutput.ReadLineAsync()
    if ($task.Wait($timeoutMs)) { return $task.Result }
    throw "TIMEOUT waiting for response"
}

$transcript = New-Object System.Collections.Generic.List[string]

try {
    foreach ($req in $requests) {
        $transcript.Add(">> " + $req)
        Send-Line $req

        # Read until the response carrying this request's id arrives. Notifications
        # (no "id") and out-of-order frames are logged but skipped.
        $reqId = ($req | ConvertFrom-Json).id
        $deadline = [DateTime]::Now.AddSeconds(45)
        while ([DateTime]::Now -lt $deadline) {
            $line = Read-Line 45000
            if ($null -eq $line) { break }
            if ($line.Trim() -eq '') { continue }
            $isMatch = $false
            try { $isMatch = ($line | ConvertFrom-Json).id -eq $reqId } catch { }
            if ($isMatch) { $transcript.Add("<< " + $line); break }
            $transcript.Add("<< [skip] " + $line)
        }
    }
} finally {
    try { $p.StandardInput.Close() } catch { }
    Start-Sleep -Milliseconds 800
    if (-not $p.HasExited) { $p.Kill() }
    $err = $p.StandardError.ReadToEnd()
    if ($err) { $transcript.Add("STDERR: " + $err) }
    $p.WaitForExit(5000) | Out-Null
}

$transcript | ForEach-Object { Write-Output $_ }
