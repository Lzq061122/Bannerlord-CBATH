# One full CBATH lifecycle run:
#   preflight -> start game -> connect -> build identity -> enter fixed mission
#   -> snapshot both sides' formations -> end mission -> stop game -> cleanup
#
# All MCP traffic goes through ONE GABS instance over HTTP, because a second gabs
# instance would see the first one's runtime claim and refuse to connect.
# Writes a per-run JSON record. Exit 0 = this run passed.

param(
    [string]$RunId,
    [string]$OutDir = 'E:\MBmod\CombatBrain Autonomous test harness\RD\CombatBrain-Autonomous-Test-Harness\evidence\runs',
    [string]$Tools = 'E:\MBmod\CombatBrain Autonomous test harness\tools',
    [string]$GameId = 'bannerlord148',
    [int]$PollTimeoutSec = 150,
    [int]$McpPort = 19580,
    [switch]$Redeploy
)

$ErrorActionPreference = 'Continue'
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

function Say([string]$m) { Write-Host $m }

function Payload([string]$json, [string]$toolName) {
    if (-not $json) { return $null }
    if ($json -notmatch [regex]::Escape($toolName)) { return $null }
    $m = [regex]::Match($json, '\\"text\\":\\"(?<p>\{.*?\})\\"')
    if (-not $m.Success) { $m = [regex]::Match($json, '"text":"(?<p>\{.*?\})"') }
    if ($m.Success) { return $m.Groups['p'].Value }
    return $null
}

function Unescape([string]$s) {
    return $s -replace '\\"', '"' -replace '\\u003c', '<' -replace '\\u003e', '>' -replace '\\\\', '\'
}

$record = [ordered]@{
    run_id                    = $RunId
    started_utc               = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    game_process_id           = $null
    game_version              = $null
    test_mod_build_id         = $null
    loaded_module_identity    = $null
    mcp_connection_result     = $null
    game_connection_result    = $null
    mission_state_transitions = @()
    mission_running           = $false
    formation_snapshot        = $null
    mission_exit_result       = $null
    game_exit_result          = $null
    cleanup_result            = $null
    errors                    = @()
    verdict                   = 'FAIL'
}

function Finish([int]$code) {
    $record.finished_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $outFile = Join-Path $OutDir "$RunId.json"
    [System.IO.File]::WriteAllText($outFile, ($record | ConvertTo-Json -Depth 8))
    Say "run $RunId verdict=$($record.verdict) -> $outFile"
    exit $code
}

# ---------- preflight ----------
$ec = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Mount and Blade II Bannerlord\Configs\engine_config.txt'
if (Test-Path $ec) {
    $lines = Get-Content $ec | ForEach-Object { if ($_ -match '^safely_exited') { 'safely_exited = 1' } else { $_ } }
    [System.IO.File]::WriteAllLines($ec, $lines)
}
if (-not (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) {
    $se = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
    if (-not $se) { $se = 'D:\Program Files (x86)\Steam\steam.exe' }
    Start-Process -FilePath $se -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 45
}
$stale = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
if ($stale) { $stale | ForEach-Object { Stop-Process -Id $_.Id -Force }; Start-Sleep -Seconds 5 }
Remove-Item (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CommandBrainATH') -Recurse -Force -ErrorAction SilentlyContinue

$deployedBuildId = $null
if ($Redeploy) {
    $bd = 'E:\MBmod\CombatBrain Autonomous test harness\RD\CombatBrain-Autonomous-Test-Harness\experiments\test-mod\CBATH\build-deploy.ps1'
    $dOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bd 2>&1 | Out-String
    if ($dOut -match 'build_id\s+=\s+(\S+)') { $deployedBuildId = $Matches[1] }
    $record.deployed_build_id = $deployedBuildId
}

# ---------- one gabs instance for everything ----------
. (Join-Path $Tools 'mcp-http.ps1')
try { $gabsPid = Open-McpHttp -ListenPort $McpPort } catch { $record.errors += 'gabs http failed: ' + $_.Exception.Message; Finish 1 }
Say "gabs http pid=$gabsPid"

function Tool([string]$name, [int]$timeout = 30) {
    return Invoke-McpHttp -Tool 'games_call_tool' -Arguments @{ gameId = $GameId; tool = $name; timeout = $timeout } -TimeoutSec ($timeout + 40)
}

# start game
$startLine = Invoke-McpHttp -Tool 'games_start' -Arguments @{ gameId = $GameId; timeout = 120 } -TimeoutSec 200
if ($startLine -match 'pid (\d+)') { $record.game_process_id = [int]$Matches[1] }
$record.game_connection_result = if ($startLine -match 'connected via GABP') { 'connected' } elseif ($startLine -match 'not ready') { 'deferred' } else { ($startLine -replace '"', '') }
Say "start: pid=$($record.game_process_id)"

if (-not $record.game_process_id) {
    $record.errors += 'start failed: no pid'
    Close-McpHttp
    Finish 1
}

$connLine = Invoke-McpHttp -Tool 'games_connect' -Arguments @{ gameId = $GameId; timeout = 30 } -TimeoutSec 90
$record.mcp_connection_result = if ($connLine -match 'Discovered|Re-synced|Already connected') { 'ok' } else { 'failed' }
Say "connect: $($record.mcp_connection_result)"

$identLine = Tool 'cbath/get_build_identity' 25
$rawIdent = Payload $identLine 'get_build_identity'
if ($rawIdent) {
    $j = Unescape $rawIdent | ConvertFrom-Json
    $record.test_mod_build_id = $j.build_id
    $record.game_version = $j.game_version
    $record.loaded_module_identity = $j.active_modules
}
Say "identity: build=$($record.test_mod_build_id) game=$($record.game_version)"

if ($deployedBuildId -and $record.test_mod_build_id -ne $deployedBuildId) {
    $record.errors += "build id mismatch: deployed=$deployedBuildId runtime=$($record.test_mod_build_id)"
    Close-McpHttp
    Finish 1
}

# enter mission
$provLine = Tool 'cbath/h3_provider_start' 40
$record.mission_state_transitions += 'provider_start:' + ($(if ($provLine -match '\\"status\\":\\"ok\\"') { 'ok' } else { 'failed' }))

$deadline = (Get-Date).AddSeconds($PollTimeoutSec)
$onScreen = $false
while ((Get-Date) -lt $deadline) {
    $rg = Payload (Tool 'cbath/get_game_state' 25) 'get_game_state'
    if ($rg -and (Unescape $rg) -match 'CustomBattleScreen') { $onScreen = $true; break }
    Start-Sleep -Seconds 3
}
$record.mission_state_transitions += "custombattle_screen:$onScreen"

if (-not $onScreen) {
    $record.errors += 'never reached CustomBattleScreen'
} else {
    $stLine = Tool 'cbath/h3_start_from_screen' 40
    $record.mission_state_transitions += 'execute_start:' + ($(if ($stLine -match 'MissionScreen') { 'ok' } else { 'failed' }))

    $deadline2 = (Get-Date).AddSeconds($PollTimeoutSec)
    while ((Get-Date) -lt $deadline2) {
        $rm = Payload (Tool 'cbath/get_mission_state' 25) 'get_mission_state'
        if ($rm -and (Unescape $rm) -match '"mission_running":true') {
            $record.mission_running = $true
            $record.mission_state_transitions += 'mission_running:true'
            break
        }
        Start-Sleep -Seconds 3
    }

    if ($record.mission_running) {
        $record.formation_snapshot = Payload (Tool 'cbath/get_all_formations' 25) 'get_all_formations'
        $endLine = Tool 'cbath/end_mission' 40
        $record.mission_exit_result = if ($endLine -match '\\"status\\":\\"ok\\"') { 'ok' } else { 'failed' }
    } else {
        $record.errors += 'mission never became running'
    }
}

# stop
$stopLine = Invoke-McpHttp -Tool 'games_stop' -Arguments @{ gameId = $GameId } -TimeoutSec 150
$record.game_exit_result = if ($stopLine -match 'termination verified') { 'ok' } else { 'failed' }

Close-McpHttp

Start-Sleep -Seconds 6
$left = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
if ($left) { $left | ForEach-Object { Stop-Process -Id $_.Id -Force }; Start-Sleep -Seconds 3 }
$left2 = Get-Process -Name 'Bannerlord', 'Bannerlord.Native' -ErrorAction SilentlyContinue | Where-Object { -not $_.HasExited }
$record.cleanup_result = if ($left2) { 'residue:' + (($left2.Id) -join ',') } else { 'clean' }

$ok = $record.mcp_connection_result -eq 'ok' -and
      $record.test_mod_build_id -and
      $record.mission_running -and
      $record.formation_snapshot -and
      $record.mission_exit_result -eq 'ok' -and
      $record.game_exit_result -eq 'ok' -and
      $record.cleanup_result -eq 'clean' -and
      $record.errors.Count -eq 0

$record.verdict = if ($ok) { 'PASS' } else { 'FAIL' }
if ($ok) { Finish 0 } else { Finish 1 }
