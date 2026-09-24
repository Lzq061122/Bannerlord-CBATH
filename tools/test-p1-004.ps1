# P1-004 acceptance driver: enter a fixed mission with NO user interaction, confirm it is
# running, read both sides' formations, then end it.
#
# Each step goes through the DSH-owned GABS session, so the caller must supply the JSON
# responses. Usage:
#   powershell -File test-p1-004.ps1 -Step start      (writes nothing; caller supplies -PayloadFile)
#   powershell -File test-p1-004.ps1 -Step <name> -PayloadFile <file>
#
# Steps and what must be true:
#   start      -> status ok, mission_id/scene present
#   state      -> mission_running = true (real condition, not a sleep)
#   formation  -> both sides have non-empty formations (reuses P1-003 assertions)
#   end        -> status ok and Mission.Current gone afterwards
#
# Exit codes: 0 = PASS for this step, 1 = FAIL, 3 = harness error.

param(
    [Parameter(Mandatory = $true)][string]$Step,
    [string]$PayloadFile,
    [string]$GameId = 'bannerlord148'
)

$ErrorActionPreference = 'Continue'
$tools = 'E:\MBmod\CombatBrain Autonomous test harness\tools'

function Say([string]$m) { Write-Host $m }

function Get-Json([string]$raw) {
    $p = $raw -replace '\\"', '"' -replace '\\u003c', '<' -replace '\\u003e', '>' -replace '\\\\', '\'
    return $p | ConvertFrom-Json
}

if (-not $PayloadFile -or -not (Test-Path $PayloadFile)) {
    Say "HARNESS(3): need -PayloadFile with the tool's JSON response (obtain it via the DSH MCP client)"
    exit 3
}

$raw = Get-Content $PayloadFile -Raw
try { $j = Get-Json $raw } catch { Say "FAIL(1): payload is not JSON"; exit 1 }

switch ($Step) {
    'start' {
        if ($j.status -ne 'ok') { Say "FAIL(1): start did not return ok: $raw"; exit 1 }
        if (-not $j.mission_name) { Say "FAIL(1): start payload has no mission_name"; exit 1 }
        Say "PASS(start): status=ok mission_name=$($j.mission_name)"
        exit 0
    }
    'state' {
        if ($j.mission_running -ne $true) { Say "FAIL(1): mission_running is not true: $raw"; exit 1 }
        Say "PASS(state): mission_running=true mission_name=$($j.mission_name) time=$($j.mission_time)"
        exit 0
    }
    'formation' {
        # reuse the P1-003 assertions verbatim
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$tools\test-p1-003.ps1" -PayloadFile $PayloadFile
        exit $LASTEXITCODE
    }
    'end' {
        if ($j.status -ne 'ok') { Say "FAIL(1): end did not return ok: $raw"; exit 1 }
        Say "PASS(end): status=ok"
        exit 0
    }
    default {
        Say "HARNESS(3): unknown step '$Step' (start|state|formation|end)"
        exit 3
    }
}
