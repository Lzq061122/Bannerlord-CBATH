# Launches Bannerlord and polls cbath/get_game_state through GABS until the game
# reports a stable non-null screen/state, recording the elapsed seconds.
# Usage: powershell -File sample-startup-v2.ps1 [-SendEscape] [-Seconds 120] -Out <json>
param(
    [int]$Seconds = 120,
    [string]$Out,
    [switch]$SendEscape
)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class EscSender {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int max);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wParam, IntPtr lParam);
  static IntPtr FirstWindowFor(uint target) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == target && IsWindowVisible(h)) {
        var t = new StringBuilder(512); GetWindowText(h, t, 512);
        if (t.Length > 0 && found == IntPtr.Zero) found = h;
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static void SendEscape(uint target) {
    IntPtr h = FirstWindowFor(target);
    if (h == IntPtr.Zero) return;
    const uint WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101;
    const int VK_ESCAPE = 0x1B;
    PostMessage(h, WM_KEYDOWN, (IntPtr)VK_ESCAPE, IntPtr.Zero);
    PostMessage(h, WM_KEYUP, (IntPtr)VK_ESCAPE, IntPtr.Zero);
  }
}
'@

$gabs  = 'E:\MBmod\CombatBrain Autonomous test harness\_source-cache\gabs\gabs.exe'
$cfg   = 'E:\MBmod\CombatBrain Autonomous test harness\gabs-config'
$tools = 'E:\MBmod\CombatBrain Autonomous test harness\tools'
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

$procsBefore = Get-Process -Name 'Bannerlord','Bannerlord.Native' -ErrorAction SilentlyContinue
if ($procsBefore) { Write-Output "ERROR: game already running"; exit 2 }

$idDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CommandBrainATH'
Remove-Item $idDir -Recurse -Force -ErrorAction SilentlyContinue

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$startOut = & $gabs games start bannerlord148 --configDir $cfg 2>$null | Out-String
$gamePid = 0
if ($startOut -match 'pid (\d+)') { $gamePid = [int]$Matches[1] }
Write-Output ("launched pid=" + $gamePid + " at t=" + $sw.Elapsed.TotalSeconds + "s")

$reqConnect = '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"games_connect","arguments":{"gameId":"bannerlord148","timeout":30}}}'
$reqState   = '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"games_call_tool","arguments":{"gameId":"bannerlord148","tool":"cbath/get_game_state","timeout":20}}}'

$samples = New-Object System.Collections.Generic.List[string]
$firstNonNullScreenSec = -1
$connected = $false

for ($i = 0; $i -lt $Seconds; $i++) {
    if ($SendEscape) { [EscSender]::SendEscape([uint32]$gamePid) }

    # one-shot driver invocation; a fresh gabs session per poll keeps this simple
    $tmpIn  = Join-Path $env:TEMP ("cbath-poll-" + [guid]::NewGuid().ToString('N') + ".txt")
    $lines = @()
    $lines += '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cbath-poll","version":"1.0.0"}}}'
    if (-not $connected) { $lines += $reqConnect }
    $lines += $reqState
    [System.IO.File]::WriteAllLines($tmpIn, $lines)

    $outText = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$tools\invoke-gabs-mcp.ps1" -ScriptFile $tmpIn 2>$null | Out-String
    Remove-Item $tmpIn -Force -ErrorAction SilentlyContinue

    $stateLine = ''
    foreach ($l in ($outText -split "`n")) {
        if ($l -match 'topScreenType') { $stateLine = $l }
    }

    $screen = '<none>'
    if ($stateLine -ne '') {
        if ($stateLine -match '\\"topScreenType\\":\\"([^\\]+)\\"') { $screen = $Matches[1] }
        elseif ($stateLine -match '"topScreenType":"([^"]+)"') { $screen = $Matches[1] }
    }

    if ($screen -ne '<none>' -and $screen -ne '<null>' -and $firstNonNullScreenSec -lt 0) {
        $firstNonNullScreenSec = [int]$sw.Elapsed.TotalSeconds
    }

    $samples.Add(('{0},{1},{2}' -f [int]$sw.Elapsed.TotalSeconds, $screen, ($outText -match 'Discovered 2 tools')))
    if ($screen -ne '<none>' -and $screen -ne '<null>') { $connected = $true }

    if ($firstNonNullScreenSec -gt 0 -and ([int]$sw.Elapsed.TotalSeconds) -gt ($firstNonNullScreenSec + 8)) { break }
    Start-Sleep -Milliseconds 700
}

$result = @{
    gamePid = $gamePid
    sendEscape = [bool]$SendEscape
    firstNonNullScreenSec = $firstNonNullScreenSec
    samples = $samples
} | ConvertTo-Json -Depth 6

[System.IO.File]::WriteAllText($Out, $result)
Write-Output ("firstNonNullScreenSec=" + $firstNonNullScreenSec)
Write-Output ("out -> " + $Out)
