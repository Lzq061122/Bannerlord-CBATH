# Zero-touch acceptance for CBATH: three consecutive unattended rounds.
#
# Each round, with no mouse or keyboard input:
#   start game -> connect -> identity -> open CustomBattle -> ExecuteStart
#   -> auto_finish_deployment -> delegate_team_to_ai -> hold 60s of real combat
#   -> collect engine/telemetry evidence -> end mission -> stop game -> verify clean
#
# A round PASSes only if all eight hard criteria hold. A failed round is retried
# up to 2 extra times; a round still failing after retries stops the batch.
#
# Writes evidence\runs\<run_id>.json per round and prints a final verdict.

param(
    [string]$OutDir = 'E:\MBmod\CombatBrain Autonomous test harness\RD\CombatBrain-Autonomous-Test-Harness\evidence\runs',
    [string]$Tools = 'E:\MBmod\CombatBrain Autonomous test harness\tools',
    [string]$GameId = 'bannerlord148',
    [int]$Rounds = 3,
    [int]$MaxAttemptsPerRound = 3,
    [int]$PollTimeoutSec = 150,
    [int]$CombatHoldSec = 60,
    [int]$MinSamples = 40,
    [int]$MinRouteAEvents = 10,
    [int]$McpPort = 19580
)

$ErrorActionPreference = 'Continue'
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

$LogPath = Join-Path $env:LOCALAPPDATA 'Temp\CombatBrain.log'

# Criterion 7 scans these trees for Win32 input-simulation entry points. The pattern is
# assembled at runtime so this script does not match its own source text.
$CbathSourceDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'RD\CombatBrain-Autonomous-Test-Harness\experiments\test-mod\CBATH'
if (-not (Test-Path $CbathSourceDir)) { $CbathSourceDir = 'E:\MBmod\CombatBrain Autonomous test harness\RD\CombatBrain-Autonomous-Test-Harness\experiments\test-mod\CBATH' }
$InputSimPattern = ('Send' + 'Input|keybd_' + 'event|mouse_' + 'event|SetCursor' + 'Pos|Post' + 'Message')

function Say([string]$m) { Write-Host $m }
function NowUtc { return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }

function Unescape([string]$s) {
    return $s -replace '\\"', '"' -replace '\\u003c', '<' -replace '\\u003e', '>' -replace '\\\\', '\'
}

# Extracts a CBATH tool payload from a games_call_tool response.
#
# The response carries the payload twice: as escaped text inside content[].text,
# and as a real object under result.structuredContent. The text form is escaped in a
# way that does not match a naive regex for successful calls, so structuredContent is
# the reliable source; the text form is only a fallback.
function AsObject([string]$json, [string]$toolName) {
    if (-not $json) { return $null }
    try {
        $outer = $json | ConvertFrom-Json
        $sc = $outer.result.structuredContent
        if ($sc -and ($sc.psobject.Properties.Count -gt 0)) { return $sc }
    } catch { }

    $m = [regex]::Match($json, '\\"text\\":\\"(?<p>\{.*?\})\\"')
    if (-not $m.Success) { $m = [regex]::Match($json, '"text":"(?<p>\{.*?\})"') }
    if (-not $m.Success) { return $null }
    try { return (Unescape $m.Groups['p'].Value) | ConvertFrom-Json } catch { return $null }
}

function Get-LogLength() {
    if (Test-Path $LogPath) { return (Get-Item $LogPath).Length }
    return 0
}

# Counts RouteAEvent lines in the log bytes appended since $offset.
function Count-RouteAEvents([long]$offset) {
    if (-not (Test-Path $LogPath)) { return 0 }
    $fs = [System.IO.File]::Open($LogPath, 'Open', 'Read', 'ReadWrite')
    try {
        if ($offset -gt $fs.Length) { return 0 }
        $fs.Seek($offset, 'Begin') | Out-Null
        $sr = New-Object System.IO.StreamReader($fs)
        try { $new = $sr.ReadToEnd() } finally { $sr.Close() }
    } finally { $fs.Close() }
    $n = 0
    foreach ($l in ($new -split "`n")) { if ($l -match '\[RouteAEvent\]') { $n++ } }
    return $n
}

$script:GabsPid = $null

function Invoke-Tool([string]$name, [int]$timeout = 30) {
    return Invoke-McpHttp -Tool 'games_call_tool' -Arguments @{ gameId = $GameId; tool = $name; timeout = $timeout } -TimeoutSec ($timeout + 40)
}

# Guarantees steam is up, kills any stale game process, and only then resets
# safely_exited. The order matters: a dying game writes safely_exited=0 back to
# engine_config.txt, which would silently override a reset done beforehand and make
# the next launch show the blocking Safe Mode dialog instead of loading mods.
function Preflight() {
    # ProcessName -eq 'steam' exactly: the -Name prefix match also hits steamwebhelper.
    $steam = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'steam' }
    if (-not $steam) {
        $se = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
        if (-not $se) { $se = 'E:\SteamLibrary\steamapps\common\..\..\..\Program Files (x86)\Steam\steam.exe' }
        Say "steam not running, starting: $se"
        Start-Process -FilePath $se -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 45
    }

    # Prefer a graceful stop through GABS: a force-kill leaves the game to record
    # safely_exited=0 on its way out and can take steam down with it. The force-kill
    # below is only the fallback for a game GABS cannot reach.
    $live = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
    if ($live) {
        [void](Invoke-McpHttp -Tool 'games_stop' -Arguments @{ gameId = $GameId } -TimeoutSec 180)
    }

    $stale = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
    if ($stale) {
        $stale | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        # Confirm the process is really gone: a lingering entry would make the next
        # games_start answer already_running against a game that is no longer usable.
        $deadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $deadline) {
            $still = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
            if (-not $still) { break }
            Start-Sleep -Milliseconds 500
        }
        # Give the dying process a moment to finish flushing engine_config.txt.
        Start-Sleep -Seconds 2
    }

    # A crashed game can also take the steam client down with it.
    $steam = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'steam' }
    if (-not $steam) {
        $se = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
        if (-not $se) { $se = 'E:\SteamLibrary\steamapps\common\..\..\..\Program Files (x86)\Steam\steam.exe' }
        Say "steam gone after stop, restarting: $se"
        Start-Process -FilePath $se -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 45
    }

    $ec = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Mount and Blade II Bannerlord\Configs\engine_config.txt'
    if (Test-Path $ec) {
        $lines = Get-Content $ec | ForEach-Object { if ($_ -match '^safely_exited') { 'safely_exited = 1' } else { $_ } }
        [System.IO.File]::WriteAllLines($ec, $lines)
    }

    Remove-Item (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CommandBrainATH') -Recurse -Force -ErrorAction SilentlyContinue
}

function Get-CombatEvidence([object]$formations) {
    $nonStand = 0
    $totalUnits = 0
    $orders = @()
    foreach ($team in $formations.teams) {
        foreach ($f in $team.formations) {
            $totalUnits += [int]$f.unit_count
            $orders += ("{0}/f{1}:{2}" -f $team.team_id, $f.formation_index, $f.movement_order)
            if ($f.movement_order -ne 'StandYourGround') { $nonStand++ }
        }
    }
    return [ordered]@{ non_stand_your_ground = $nonStand; total_units = $totalUnits; orders = $orders }
}

# Runs one round. Returns an ordered dict; caller decides retry.
function Invoke-Round([string]$RunId, [int]$Attempt) {
    $rec = [ordered]@{
        run_id                       = $RunId
        attempt                      = $Attempt
        started_utc                  = (NowUtc)
        finished_utc                 = $null
        game_process_id              = $null
        test_mod_build_id            = $null
        mvid                         = $null
        assembly_sha256              = $null
        game_version                 = $null
        loaded_modules               = $null
        mcp_connect                  = $null
        provider_start_result        = $null
        c1_mission_running           = $false
        c2_deployment_finished       = $false
        c2_auto_finish_status        = $null
        c2_allow_ai_ticking_after    = $null
        c3_real_engagement           = $false
        c4_dynamic_state_change      = $false
        c4a_unit_count_dropped       = $false
        c4b_orders_changed           = $false
        c5_routeA_events             = 0
        c6_sample_count              = 0
        c7_no_win32_input            = $true
        c7_input_sim_hits            = @()
        c8_no_residue_process        = $false
        log_offset_start             = $null
        log_offset_end               = $null
        combat_window_sec            = $null
        early_orders                 = $null
        late_orders                  = $null
        units_early                  = $null
        units_late                   = $null
        delegate_result              = $null
        auto_finish_result           = $null
        cleanup_result               = $null
        errors                       = @()
        verdict                      = 'FAIL'
    }

    $logOffset = Get-LogLength
    $rec.log_offset_start = $logOffset

    # --- start + connect ---
    # Success is reported through structuredContent (code started_connected /
    # processStarted / gameStillRunning). The human-readable text carries no pid,
    # so a pid regex alone would misreport a successful start as a failure.
    # already_running means preflight's kill did not take effect; the surviving game may
    # be mid-mission, where h3_provider_start cannot work, so that is a hard failure
    # rather than something to attach to.
    $startLine = Invoke-McpHttp -Tool 'games_start' -Arguments @{ gameId = $GameId; timeout = 150 } -TimeoutSec 240
    $alreadyRunning = ($startLine -match 'already_running|already running')
    $started = ($startLine -match 'started_connected') -or ($startLine -match 'processStarted\\?":true')
    if ($startLine -match 'pid (\d+)') { $rec.game_process_id = [int]$Matches[1] }
    elseif ($started) { $rec.game_process_id = -1 }
    if ($alreadyRunning) {
        $rec.errors += 'games_start found a game still running; preflight kill did not take effect'
        $rec.cleanup_result = 'skipped:dirty_game'
        $rec.verdict = 'FAIL'
        return $rec
    }
    if (-not $started) {
        $rec.errors += 'games_start did not report a started game: ' + ($startLine -replace '"', '')
        $rec.cleanup_result = 'skipped:no_game'
        $rec.verdict = 'FAIL'
        return $rec
    }

    # forceTakeover: this batch runs its own gabs instance, and the DSH session's gabs
    # normally owns the game. Without takeover games_connect is skipped ("already owned
    # by another active GABS session"), which leaves the tool snapshot empty and makes
    # every cbath call answer "not found".
    $connLine = Invoke-McpHttp -Tool 'games_connect' -Arguments @{ gameId = $GameId; timeout = 40; forceTakeover = $true } -TimeoutSec 100
    $rec.mcp_connect = if ($connLine -match 'Discovered|Re-synced|Already connected|Force-took') { 'ok' } else { 'failed' }
    if ($rec.mcp_connect -ne 'ok') { $rec.errors += 'games_connect failed: ' + ($connLine -replace '"', '') }

    # --- wait until the test mod's bridge actually answers ---
    # games_connect returning ok only means GABS attached; the game still has to finish
    # loading its modules and start the CBATH GABP bridge. Calling a cbath tool before
    # that returns no payload, so poll ping instead of assuming readiness.
    $bridgeDeadline = (Get-Date).AddSeconds($PollTimeoutSec)
    $bridgeReady = $false
    while ((Get-Date) -lt $bridgeDeadline) {
        $ping = AsObject (Invoke-Tool 'cbath/ping' 20) 'cbath_ping'
        if ($ping -and $ping.pong -eq $true) { $bridgeReady = $true; break }
        Start-Sleep -Seconds 3
    }
    if (-not $bridgeReady) { $rec.errors += 'cbath bridge never answered ping' }

    # --- identity (also proves the re-synced tool snapshot loaded our DLL) ---
    $ident = AsObject (Invoke-Tool 'cbath/get_build_identity' 25) 'get_build_identity'
    if ($ident) {
        $rec.test_mod_build_id = $ident.build_id
        $rec.mvid = $ident.mvid
        $rec.assembly_sha256 = $ident.assembly_sha256
        $rec.game_version = $ident.game_version
        $rec.loaded_modules = $ident.active_modules
    } else {
        $rec.errors += 'get_build_identity returned no payload'
    }

    # --- wait until the game sits at the main menu ---
    # h3_provider_start pushes a fresh CustomBattle state, which only works from the
    # main menu. A game left mid-mission by a previous run would make it error out.
    $menuDeadline = (Get-Date).AddSeconds($PollTimeoutSec)
    $atMenu = $false
    while ((Get-Date) -lt $menuDeadline) {
        $gs = AsObject (Invoke-Tool 'cbath/get_game_state' 25) 'get_game_state'
        if ($gs -and $gs.activeGameState -match 'InitialState') { $atMenu = $true; break }
        Start-Sleep -Seconds 3
    }
    if (-not $atMenu) { $rec.errors += 'game never reached the main menu (InitialState)' }

    # --- reach the CustomBattle screen ---
    $prov = AsObject (Invoke-Tool 'cbath/h3_provider_start' 40) 'h3_provider_start'
    if ($prov) { $rec.provider_start_result = $prov.status } else { $rec.provider_start_result = 'no_payload' }
    if (-not $prov -or $prov.status -ne 'ok') {
        $rec.errors += 'h3_provider_start status=' + $(if ($prov) { $prov.status } else { 'no_payload' })
    }

    $deadline = (Get-Date).AddSeconds($PollTimeoutSec)
    $onScreen = $false
    while ((Get-Date) -lt $deadline) {
        $g = AsObject (Invoke-Tool 'cbath/get_game_state' 25) 'get_game_state'
        if ($g -and $g.topScreenType -match 'CustomBattleScreen') { $onScreen = $true; break }
        Start-Sleep -Seconds 3
    }
    if (-not $onScreen) { $rec.errors += 'never reached CustomBattleScreen' }

    # --- ExecuteStart -> deployment ---
    if ($onScreen) {
        $st = AsObject (Invoke-Tool 'cbath/h3_start_from_screen' 40) 'h3_start_from_screen'
        if (-not $st -or $st.status -ne 'ok') { $rec.errors += 'h3_start_from_screen failed' }
    }

    $deadline2 = (Get-Date).AddSeconds($PollTimeoutSec)
    while ((Get-Date) -lt $deadline2) {
        $ms = AsObject (Invoke-Tool 'cbath/get_mission_state' 25) 'get_mission_state'
        if ($ms -and $ms.mission_running -eq $true) { $rec.c1_mission_running = $true; break }
        Start-Sleep -Seconds 3
    }
    if (-not $rec.c1_mission_running) { $rec.errors += 'mission never became running' }

    if ($rec.c1_mission_running) {
        # --- criterion 2: finish deployment. Poll: not_ready means the scene is still loading. ---
        $deadline3 = (Get-Date).AddSeconds($PollTimeoutSec)
        while ((Get-Date) -lt $deadline3) {
            $af = AsObject (Invoke-Tool 'cbath/auto_finish_deployment' 30) 'auto_finish_deployment'
            $rec.auto_finish_result = $af
            if (-not $af) { $rec.errors += 'auto_finish_deployment returned no payload'; break }
            if ($af.status -eq 'ok') {
                $rec.c2_deployment_finished = $true
                $rec.c2_auto_finish_status = 'ok'
                if ($af.after) { $rec.c2_allow_ai_ticking_after = $af.after.allow_ai_ticking }
                break
            }
            if ($af.status -eq 'not_ready') { Start-Sleep -Seconds 2; continue }
            $rec.c2_auto_finish_status = $af.status
            $rec.errors += 'auto_finish_deployment status=' + $af.status
            break
        }
        if (-not $rec.c2_deployment_finished) { $rec.errors += 'deployment never finished (auto_finish_deployment never returned ok)' }

        # --- hand the player's formations to the engine AI (the F6 equivalent) ---
        $rec.delegate_result = AsObject (Invoke-Tool 'cbath/delegate_team_to_ai' 30) 'delegate_team_to_ai'

        # --- criterion 3/4 baseline: orders right after deployment ---
        $early = AsObject (Invoke-Tool 'cbath/get_all_formations' 25) 'get_all_formations'
        if ($early) {
            $e = Get-CombatEvidence $early
            $rec.units_early = $e.total_units
            $rec.early_orders = $e.orders
        }

        # --- combat window: hold until casualties appear, bounded by CombatHoldSec ---
        # Casualties are the evidence that the two armies have actually met, so the window
        # is driven by that condition rather than by a blind sleep. It never closes before
        # MinSamples seconds, because criterion 6 needs at least that many 1 Hz samples and
        # ending on a fast first casualty would make the two criteria contradict.
        $minWindow = [Math]::Max(5, $MinSamples)
        Say "  combat window $minWindow..$CombatHoldSec s (waiting for casualties)..."
        $windowEnd = (Get-Date).AddSeconds($CombatHoldSec)
        $late = $null
        $waited = 0
        while ((Get-Date) -lt $windowEnd) {
            Start-Sleep -Seconds 5
            $waited += 5
            $late = AsObject (Invoke-Tool 'cbath/get_all_formations' 25) 'get_all_formations'
            if (-not $late) { continue }
            $l = Get-CombatEvidence $late
            $hasCasualties = ($null -ne $rec.units_early -and [int]$l.total_units -lt [int]$rec.units_early)
            if ($hasCasualties -and $waited -ge $minWindow) { break }
        }
        $rec.combat_window_sec = $waited

        if ($late) {
            $l = Get-CombatEvidence $late
            $rec.units_late = $l.total_units
            $rec.late_orders = $l.orders

            $rec.c3_real_engagement = ($l.non_stand_your_ground -gt 0)

            # Criterion 4 requires real casualties: unit_count must actually fall.
            # An orders change alone is recorded as supporting evidence (c4b) but is NOT
            # sufficient, because it does not prove the two armies have met.
            $casualties = $false
            $ordersChanged = $false
            if ($null -ne $rec.units_early -and $null -ne $rec.units_late) {
                $casualties = ([int]$rec.units_late -lt [int]$rec.units_early)
                $ordersChanged = (($rec.early_orders -join ';') -ne ($rec.late_orders -join ';'))
            }
            $rec.c4a_unit_count_dropped = $casualties
            $rec.c4b_orders_changed = $ordersChanged
            $rec.c4_dynamic_state_change = $casualties
        }

        # --- end the mission first: the run record is only finalised in OnEndMission ---
        $endLine = Invoke-Tool 'cbath/end_mission' 40
        if ($endLine -notmatch '\\"status\\":\\"ok\\"') { $rec.errors += 'end_mission failed' }

        # --- criterion 6: engine-side timeline, read after the run has been finalised ---
        $run = $null
        $runDeadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $runDeadline) {
            $run = AsObject (Invoke-Tool 'cbath/get_last_run' 30) 'get_last_run'
            if ($run -and $run.status -eq 'ok' -and $run.sample_count) { break }
            Start-Sleep -Seconds 2
        }
        if ($run -and $run.sample_count) { $rec.c6_sample_count = [int]$run.sample_count }
    }

    # --- criterion 5: telemetry produced during this round ---
    if ($rec.c1_mission_running) {
        Start-Sleep -Seconds 3
        $rec.log_offset_end = Get-LogLength
        $rec.c5_routeA_events = Count-RouteAEvents $logOffset
    }

    # --- stop + criterion 8 ---
    $stopLine = Invoke-McpHttp -Tool 'games_stop' -Arguments @{ gameId = $GameId } -TimeoutSec 180
    Start-Sleep -Seconds 8
    $left = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
    if ($left) {
        $left | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 4
        $left = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
    }
    if ($left) {
        $rec.cleanup_result = 'residue:' + (($left.Id) -join ',')
        $rec.c8_no_residue_process = $false
        $rec.errors += 'residual game processes after stop'
    } else {
        $rec.cleanup_result = 'clean'
        $rec.c8_no_residue_process = $true
    }

    # criterion 7: no mouse/keyboard input. Checked, not assumed. The scan covers the
    # CBATH sources (the tools actually shipped) and this script only; unrelated legacy
    # helpers under tools\ that this batch never invokes are deliberately not included.
    $inputHits = @()
    $scanFiles = @()
    if (Test-Path $CbathSourceDir) {
        $scanFiles += Get-ChildItem $CbathSourceDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\' }
    }
    $scanFiles += Get-Item $PSCommandPath -ErrorAction SilentlyContinue

    foreach ($file in $scanFiles) {
        $hits = Select-String -Path $file.FullName -Pattern $InputSimPattern -ErrorAction SilentlyContinue
        foreach ($h in $hits) { $inputHits += ($file.Name + ':' + $h.LineNumber) }
    }
    $rec.c7_input_sim_hits = $inputHits
    $rec.c7_no_win32_input = ($inputHits.Count -eq 0)
    if ($inputHits.Count -gt 0) { $rec.errors += 'input simulation found: ' + ($inputHits -join ', ') }

    $all = $rec.c1_mission_running -and
           $rec.c2_deployment_finished -and
           ($rec.c2_allow_ai_ticking_after -eq $true) -and
           $rec.c3_real_engagement -and
           $rec.c4_dynamic_state_change -and
           ($rec.c5_routeA_events -ge $MinRouteAEvents) -and
           ($rec.c6_sample_count -ge $MinSamples) -and
           $rec.c7_no_win32_input -and
           $rec.c8_no_residue_process

    $rec.verdict = if ($all) { 'PASS' } else { 'FAIL' }
    $rec.finished_utc = NowUtc
    return $rec
}

# ---------------- main ----------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

. (Join-Path $Tools 'mcp-http.ps1')
try { $script:GabsPid = Open-McpHttp -ListenPort $McpPort }
catch { Say "FATAL: gabs http failed: $($_.Exception.Message)"; exit 1 }
Say "gabs http pid=$script:GabsPid"

$batch = [ordered]@{
    batch_id   = 'zero-touch-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    started_utc= NowUtc
    rounds     = @()
    verdict    = 'FAIL'
}

for ($r = 1; $r -le $Rounds; $r++) {
    $passed = $false
    for ($attempt = 1; $attempt -le $MaxAttemptsPerRound; $attempt++) {
        $runId = "zt-r$r-a$attempt-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Say ""
        Say "=== round $r attempt $attempt : $runId ==="
        Preflight

        $rec = Invoke-Round $runId $attempt
        $outFile = Join-Path $OutDir "$runId.json"
        [System.IO.File]::WriteAllText($outFile, ($rec | ConvertTo-Json -Depth 8))
        Say "  verdict=$($rec.verdict)  c1=$($rec.c1_mission_running) c2=$($rec.c2_deployment_finished) c3=$($rec.c3_real_engagement) c4=$($rec.c4_dynamic_state_change) c5=$($rec.c5_routeA_events) c6=$($rec.c6_sample_count) c8=$($rec.c8_no_residue_process)"

        if ($rec.verdict -eq 'PASS') { $passed = $true; break }
        if ($attempt -lt $MaxAttemptsPerRound) { Say "  round $r failed, retrying..." }
    }
    $batch.rounds += [ordered]@{ round = $r; passed = $passed }
    if (-not $passed) {
        Say ""
        Say "round $r failed after $MaxAttemptsPerRound attempts - stopping batch"
        break
    }
}

Close-McpHttp

# Counted from the per-round tally, not from an accumulated record list: appending an
# ordered dictionary with += splices its entries into the array instead of adding one
# element, which would inflate the count.
$passedRounds = ($batch.rounds | Where-Object { $_.passed }).Count
$batch.passed_rounds = $passedRounds
$batch.total_rounds = $Rounds
$batch.finished_utc = NowUtc
$batch.verdict = if ($passedRounds -eq $Rounds) { 'PASS' } else { 'FAIL' }
$batchFile = Join-Path $OutDir ($batch.batch_id + '.json')
[System.IO.File]::WriteAllText($batchFile, ($batch | ConvertTo-Json -Depth 6))

Say ""
Say "=== ZERO-TOUCH RESULT : $($batch.verdict) ($passedRounds/$Rounds) ==="
Say "batch file: $batchFile"
if ($batch.verdict -eq 'PASS') { exit 0 } else { exit 1 }
