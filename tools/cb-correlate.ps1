# legacy CombatBrain temporary adapter
#
# TEMPORARY, DELETE-ABLE, NOT PART OF CBATH.
# Correlates legacy CombatBrain RouteAEvent records against a CBATH engine-side
# timeline (the JSON returned by cbath/get_last_run).
#
# Produces correlation evidence only. Performs NO attribution: it shows that two
# event streams can be placed on one time axis, and never claims the engine change
# was caused by the reported command.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\cb-correlate.ps1 `
#       -CbEvents <p2-006-cb-events-*.json> -Timeline <get_last_run.json> -OutFile <md>

param(
    [Parameter(Mandatory = $true)][string]$CbEvents,
    [Parameter(Mandatory = $true)][string]$Timeline,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [string]$FocusList = '',
    [int]$Window = 4
)

$ErrorActionPreference = 'Stop'

$FocusTimes = @()
if ($FocusList) { foreach ($p in ($FocusList -split ',')) { $v = 0.0; if ([double]::TryParse($p.Trim(), [ref]$v)) { $FocusTimes += $v } } }

$ev = (Get-Content $CbEvents -Raw | ConvertFrom-Json).events
$tl = Get-Content $Timeline -Raw | ConvertFrom-Json

$samples = @($tl.samples)

function Get-FormationState($sample, [int]$teamId, [int]$fIndex) {
    foreach ($tm in $sample.teams) {
        if ($tm.team_id -ne $teamId) { continue }
        foreach ($fo in $tm.formations) {
            if ($fo.formation_index -eq $fIndex) { return $fo }
        }
    }
    return $null
}

# Which (team,f) pairs actually changed in the engine timeline?
$state = @{}
$changeTimes = @{}
foreach ($s in $samples) {
    foreach ($tm in $s.teams) {
        foreach ($fo in $tm.formations) {
            $k = "$($tm.team_id)/$($fo.formation_index)"
            $cur = "$($fo.active_behavior)|$($fo.movement_order)|$($fo.arrangement_order)|$($fo.unit_count)"
            if (-not $state.ContainsKey($k)) { $state[$k] = $cur; $changeTimes[$k] = New-Object System.Collections.Generic.List[double] }
            elseif ($state[$k] -ne $cur) { $changeTimes[$k].Add([double]$s.t); $state[$k] = $cur }
        }
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# Correlation evidence - CombatBrain command vs CBATH engine timeline')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> legacy CombatBrain temporary adapter output. **Correlation, NOT attribution.**')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("| field | value |")
[void]$sb.AppendLine("|---|---|")
[void]$sb.AppendLine("| CBATH run_id | $($tl.run_id) |")
[void]$sb.AppendLine("| CBATH samples | $($tl.sample_count) |")
[void]$sb.AppendLine("| CBATH mission window | $($tl.mission_start_time) .. $($tl.mission_end_time) s |")
[void]$sb.AppendLine("| CombatBrain records | $($ev.Count) |")
[void]$sb.AppendLine("| sampling interval | $($tl.sample_interval_seconds) s |")
[void]$sb.AppendLine('')

[void]$sb.AppendLine('## Engine-side change counts per formation')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| formation | changes | first change times (s) |')
[void]$sb.AppendLine('|---|---:|---|')
foreach ($k in ($changeTimes.Keys | Sort-Object)) {
    $t = $changeTimes[$k]
    $first = if ($t.Count -gt 0) { (($t | Select-Object -First 6) -join ', ') } else { '-' }
    [void]$sb.AppendLine("| $k | $($t.Count) | $first |")
}
[void]$sb.AppendLine('')

# For each focus time, print the CB record and the surrounding engine samples.
foreach ($ft in $FocusTimes) {
    [void]$sb.AppendLine("## Focus: t = $ft s")
    [void]$sb.AppendLine('')

    $cb = $ev | Where-Object { [math]::Abs([double]$_.mission_time - $ft) -lt 0.6 } | Select-Object -First 3
    if (-not $cb) { [void]$sb.AppendLine('_(no CombatBrain record within 0.6 s)_'); [void]$sb.AppendLine(''); continue }

    [void]$sb.AppendLine('**CombatBrain reported command**')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| mission_time | team | f | domain | event | intent | orderType |')
    [void]$sb.AppendLine('|---|---:|---:|---|---|---|---|')
    foreach ($r in $cb) {
        [void]$sb.AppendLine("| $($r.mission_time) | $($r.team) | $($r.f) | $($r.domain) | $($r.event) | $($r.intent) | $($r.orderType) |")
    }
    [void]$sb.AppendLine('')

    $anchor = $cb | Select-Object -First 1
    $tid = [int]$anchor.team
    $fid = [int]$anchor.f

    $near = @($samples | Sort-Object { [math]::Abs([double]$_.t - $ft) } | Select-Object -First (2 * $Window + 1) | Sort-Object { [double]$_.t })

    [void]$sb.AppendLine("**engine-observed state (CBATH, independent) - team $tid f$fid**")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| CBATH t | delta | active_behavior | movement | arrange | units | position |')
    [void]$sb.AppendLine('|---|---:|---|---|---|---:|---|')
    foreach ($s in $near) {
        $fo = Get-FormationState $s $tid $fid
        $d = [double]$s.t - $ft
        if ($null -eq $fo) {
            [void]$sb.AppendLine("| $($s.t) | $($d.ToString('+0.000;-0.000')) | _(formation absent)_ | | | | |")
        } else {
            $pos = "$($fo.position.x),$($fo.position.y)"
            [void]$sb.AppendLine("| $($s.t) | $($d.ToString('+0.000;-0.000')) | $($fo.active_behavior) | $($fo.movement_order) | $($fo.arrangement_order) | $($fo.unit_count) | $pos |")
        }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('**NOT PROVEN**: the engine state above is not shown to be caused by the reported command; only the time relationship is established.')
    [void]$sb.AppendLine('')
}

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Output "correlation written: $OutFile"
Write-Output ("formations tracked: {0}, samples: {1}, cb records: {2}" -f $changeTimes.Count, $samples.Count, $ev.Count)
