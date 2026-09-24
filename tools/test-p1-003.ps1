# P1-003 acceptance assertions for cbath/get_all_formations.
#
# Usage (payload obtained through the official DSH MCP client):
#   powershell -File test-p1-003.ps1 -PayloadFile <file with the tool's JSON response>
#
# A standalone gabs process cannot fetch the payload itself while the DSH session owns
# the game ("already owned by another active GABS session"), so the caller passes the
# response in. With no -PayloadFile the script attempts the call and exits 3 if refused.
#
# Exit codes: 0 = PASS, 1 = FAIL, 2 = tool correct but no live mission, 3 = harness error.

param(
    [string]$PayloadFile,
    [string]$GameId = 'bannerlord148',
    [string]$Tools = 'E:\MBmod\CombatBrain Autonomous test harness\tools'
)

$ErrorActionPreference = 'Continue'

$requiredTeamFields = @('team_id','side','formations')
$requiredFormationFields = @('formation_index','formation_class','unit_count',
                             'position','facing','movement_order','arrangement_order','firing_order','is_ai_controlled')

function Say([string]$m) { Write-Host $m }

function Assert-Payload([string]$payload) {
    if (-not $payload) {
        Say "FAIL(1): empty payload"
        return 1
    }

    $p = $payload -replace '\\"', '"' -replace '\\u003c', '<' -replace '\\u003e', '>' -replace '\\\\', '\'
    try { $j = $p | ConvertFrom-Json } catch {
        Say "FAIL(1): payload is not valid JSON: $p"
        return 1
    }

    # No live mission: the tool must report that rather than fabricate data.
    if ($j.PSObject.Properties.Name -contains 'status' -and $j.status -eq 'no_mission') {
        Say "PARTIAL(2): tool present and correctly reports no_mission"
        Say "            remaining: run inside a real battle with both sides present"
        return 2
    }

    if (-not ($j.PSObject.Properties.Name -contains 'teams')) {
        Say "FAIL(1): payload has no 'teams' field"
        return 1
    }

    $teams = @($j.teams)
    Say "teams reported: $($teams.Count)"
    if ($teams.Count -lt 2) {
        Say "FAIL(1): expected at least 2 teams, got $($teams.Count)"
        return 1
    }

    $sides = @{}
    foreach ($t in $teams) {
        foreach ($rt in $requiredTeamFields) {
            if (-not ($t.PSObject.Properties.Name -contains $rt)) {
                Say "FAIL(1): team missing field '$rt'"
                return 1
            }
        }

        $fms = @($t.formations)
        $nonEmpty = @($fms | Where-Object { $_.unit_count -gt 0 })
        Say ("team side={0} team_id={1} formations={2} nonEmpty={3}" -f $t.side, $t.team_id, $fms.Count, $nonEmpty.Count)
        if ($nonEmpty.Count -gt 0) { $sides[[string]$t.side] = $true }

        foreach ($f in $nonEmpty) {
            foreach ($rf in $requiredFormationFields) {
                if (-not ($f.PSObject.Properties.Name -contains $rf)) {
                    Say "FAIL(1): formation missing field '$rf'"
                    return 1
                }
            }
        }
    }

    if ($sides.Count -lt 2) {
        Say "FAIL(1): need non-empty formations on 2 different sides, got $($sides.Count)"
        return 1
    }

    Say "PASS: $($sides.Count) sides with non-empty formations"
    Say "      team fields + formation fields all present"
    return 0
}

if ($PayloadFile) {
    if (-not (Test-Path $PayloadFile)) {
        Say "HARNESS(3): payload file not found: $PayloadFile"
        exit 3
    }
    $code = Assert-Payload (Get-Content $PayloadFile -Raw)
    exit $code
}

$init    = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cbath-test","version":"1.0.0"}}}'
$connect = '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"games_connect","arguments":{"gameId":"' + $GameId + '","timeout":30}}}'
$call    = '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"games_call_tool","arguments":{"gameId":"' + $GameId + '","tool":"cbath/get_all_formations","timeout":25}}}'

$tmp = Join-Path $env:TEMP ("cbath-t-" + [guid]::NewGuid().ToString('N') + ".txt")
[System.IO.File]::WriteAllLines($tmp, @($init, $connect, $call))
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Tools\invoke-gabs-mcp.ps1" -ScriptFile $tmp 2>$null | Out-String
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

if ($out -match 'already owned by another active GABS session') {
    Say "HARNESS(3): another GABS session owns '$GameId'; get the payload from that session and pass -PayloadFile"
    exit 3
}

$line = ''
foreach ($l in ($out -split "`n")) { if ($l -match 'get_all_formations') { $line = $l } }
if ($line -match 'not found for game') {
    Say "FAIL(1): tool not registered"
    exit 1
}

$m = [regex]::Match($line, '"text":"(?<p>\{.*?\})"')
if (-not $m.Success) {
    Say "FAIL(1): no JSON payload in response"
    exit 1
}
exit (Assert-Payload $m.Groups['p'].Value)
