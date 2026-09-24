# Brings the Bannerlord window to the foreground.
# Standalone external helper - deliberately NOT part of CBATH, so the CBATH core
# keeps zero window-management responsibility.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools\focus-bannerlord.ps1

param(
    [string]$ProcessName = 'Bannerlord'
)

$src = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public class WinFocus
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);

    public static IntPtr Found = IntPtr.Zero;

    public static void Find(uint targetPid)
    {
        Found = IntPtr.Zero;
        EnumWindows((h, l) =>
        {
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            if (pid != targetPid || !IsWindowVisible(h)) return true;
            var cls = new StringBuilder(128);
            GetClassName(h, cls, 128);
            if (cls.ToString() == "TWApplication") { Found = h; return false; }
            return true;
        }, IntPtr.Zero);
    }

    public static bool Focus(IntPtr h)
    {
        if (IsIconic(h)) ShowWindow(h, 9);   // SW_RESTORE
        ShowWindow(h, 5);                    // SW_SHOW
        SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040); // TOPMOST, then un-topmost below
        SetWindowPos(h, new IntPtr(-2), 0, 0, 0, 0, 0x0001 | 0x0002);

        uint fg = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        uint cur = GetCurrentThreadId();
        AttachThreadInput(cur, fg, true);
        BringWindowToTop(h);
        SetForegroundWindow(h);
        AttachThreadInput(cur, fg, false);

        return GetForegroundWindow() == h;
    }

    public static string ForegroundInfo()
    {
        var h = GetForegroundWindow();
        uint pid;
        GetWindowThreadProcessId(h, out pid);
        var t = new StringBuilder(512);
        GetWindowText(h, t, 512);
        return "pid=" + pid + " title=" + t;
    }
}
'@

Add-Type -TypeDefinition $src -ErrorAction SilentlyContinue

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue |
        Where-Object { -not $_.HasExited } |
        Select-Object -First 1

if (-not $proc) {
    Write-Output "FOCUS_RESULT=no_process"
    exit 1
}

[WinFocus]::Find([uint32]$proc.Id)
$hwnd = [WinFocus]::Found

if ($hwnd -eq [IntPtr]::Zero) {
    Write-Output "FOCUS_RESULT=no_window (pid=$($proc.Id))"
    exit 1
}

$ok = [WinFocus]::Focus($hwnd)
Start-Sleep -Milliseconds 800

Write-Output "hwnd=$hwnd"
Write-Output "focus_requested=$ok"
Write-Output "foreground=$([WinFocus]::ForegroundInfo())"

if ($ok) { Write-Output "FOCUS_RESULT=ok"; exit 0 } else { Write-Output "FOCUS_RESULT=denied"; exit 2 }
