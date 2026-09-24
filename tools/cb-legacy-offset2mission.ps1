# legacy CombatBrain temporary adapter
#
# TEMPORARY, DELETE-ABLE, NOT PART OF CBATH.
# Reads only the newly appended portion of the legacy CombatBrain log (via a byte
# offset) and extracts RouteAEvent records, which are the only legacy log lines
# that carry a Mission-time-aligned `time=` field.
#
# This exists purely to correlate ONE CombatBrain-reported event against the
# CBATH engine timeline for a single run. It performs NO attribution.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\cb-legacy-offset2mission.ps1 `
#       -LogOffset <bytes-before-mission> -OutFile <json-path>

param(
    [Parameter(Mandatory = $true)][long]$LogOffset,
    [string]$LogPath = "$env:LOCALAPPDATA\Temp\CombatBrain.log",
    [Parameter(Mandatory = $true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $LogPath)) { throw "log not found: $LogPath" }

$fs = [System.IO.File]::Open($LogPath, 'Open', 'Read', 'ReadWrite')
try {
    $fs.Seek($LogOffset, 'Begin') | Out-Null
    $sr = New-Object System.IO.StreamReader($fs)
    try { $new = $sr.ReadToEnd() } finally { $sr.Close() }
} finally { $fs.Close() }

$lines = $new -split "`n"

$events = New-Object System.Collections.Generic.List[object]

foreach ($l in $lines) {
    # RouteAEvent is the only family whose time= is Mission.CurrentTime aligned.
    if ($l -notmatch '\[RouteAEvent\]') { continue }

    $wall = $null; $mt = $null
    if ($l -match '^(\d\d:\d\d:\d\d\.\d+)') { $wall = $Matches[1] }
    if ($l -match 'time=([0-9.]+)')        { $mt = [double]$Matches[1] }

    $rec = [ordered]@{
        wall_clock    = $wall
        mission_time  = $mt
        family        = 'RouteAEvent'
    }
    foreach ($k in @('run','session','seq','identity','team','f','domain','event','intent','revision','source','orderType','reason')) {
        if ($l -match ("(?<![A-Za-z])" + $k + "=(\S+)")) { $rec[$k] = $Matches[1] }
    }
    $events.Add([pscustomobject]$rec)
}

$payload = [ordered]@{
    adapter            = 'legacy CombatBrain temporary adapter'
    log_path           = $LogPath
    log_offset_start   = $LogOffset
    new_bytes_read     = $new.Length
    line_count_read    = $lines.Count
    event_count        = $events.Count
    time_basis_note    = 'RouteAEvent time= is Mission.CurrentTime (verified against BattleDuration)'
    events             = $events
}

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($OutFile, ($payload | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))

Write-Output "adapter: read $($new.Length) new bytes, $($events.Count) RouteAEvent records"
Write-Output "written: $OutFile"
