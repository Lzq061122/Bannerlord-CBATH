# Launches Bannerlord itself and samples the startup timeline from process creation.
# Records each second: the game's own visible window titles, and whether the CBATH
# GABP bridge file exists yet.
# Usage: powershell -File sample-startup.ps1 [-SendEscape] [-Seconds 120] -Out <csv>

param(
    [int]$Seconds = 120,
    [string]$Out,
    [switch]$SendEscape,
    [string]$Exe = 'E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord\bin\Win64_Shipping_Client\Bannerlord.exe',
    [string]$WorkingDir = 'E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord\bin\Win64_Shipping_Client',
    [string]$ArgsString = '/singleplayer _MODULES_*Native*CombatBrainAutonomousTestHarness*_MODULES_ /anticheat'
)

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class StartupWin {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int max);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wParam, IntPtr lParam);
  public static string TitlesFor(uint target) {
    var list = new List<string>();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == target && IsWindowVisible(h)) {
        var t = new StringBuilder(512); GetWindowText(h, t, 512);
        if (t.Length > 0) list.Add(t.ToString());
      }
      return true;
    }, IntPtr.Zero);
    return string.Join(" ;; ", list.ToArray());
  }
  public static IntPtr FirstWindowFor(uint target) {
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
    const uint WM_KEYDOWN = 0x0100;
    const uint WM_KEYUP = 0x0101;
    const int VK_ESCAPE = 0x1B;
    PostMessage(h, WM_KEYDOWN, (IntPtr)VK_ESCAPE, IntPtr.Zero);
    PostMessage(h, WM_KEYUP, (IntPtr)VK_ESCAPE, IntPtr.Zero);
  }
}
'@

$procsBefore = Get-Process -Name 'Bannerlord','Bannerlord.Native' -ErrorAction SilentlyContinue
if ($procsBefore) { Write-Output "ERROR: game already running"; exit 2 }

$idDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CommandBrainATH'

$p = Start-Process -FilePath $Exe -ArgumentList $ArgsString -WorkingDirectory $WorkingDir -PassThru
$gamePid = $p.Id
Write-Output ("launched pid=" + $gamePid)

$bridgeFile = Join-Path $idDir ("cbath-gabp-" + $gamePid + ".txt")
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add('elapsedSec,gabpFilePresent,titles')

$gabpSec = -1
for ($i = 0; $i -lt $Seconds; $i++) {
    $gabp = 'no'
    if (Test-Path $bridgeFile) {
        $gabp = 'yes'
        if ($gabpSec -lt 0) { $gabpSec = $i }
    }
    $titles = [StartupWin]::TitlesFor([uint32]$gamePid)
    if ([string]::IsNullOrEmpty($titles)) { $titles = '(none)' }
    $rows.Add(('{0},{1},"{2}"' -f $i, $gabp, $titles))

    if ($SendEscape -and $i -ge 1) { [StartupWin]::SendEscape([uint32]$gamePid) }

    Start-Sleep -Seconds 1
}

$rows.Add(('# gabpFirstSeenSec=' + $gabpSec + ',,'))
[System.IO.File]::WriteAllLines($Out, $rows)
Write-Output ("gabpFirstSeenSec=" + $gabpSec)
Write-Output ("sampling done -> " + $Out)
Write-Output ("pid=" + $gamePid)
