using System.Collections.Generic;
using System.Text;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;
using TaleWorlds.ScreenSystem;

namespace CombatBrainAutonomousTestHarness
{
    internal static class ScreenProbe
    {
        internal static System.Diagnostics.Stopwatch Timer;
        private static readonly List<string> Transitions = new List<string>();
        private static string _lastScreen = "<unset>";

        internal static void EnsureTimer()
        {
            if (Timer == null) Timer = System.Diagnostics.Stopwatch.StartNew();
        }

        // Called from the main thread every tick. Appends one line whenever the top screen
        // type changes, so startup phases (intro video -> main menu -> ...) are visible.
        internal static void Sample()
        {
            EnsureTimer();
            var current = ScreenManager.TopScreen == null
                ? "<null>"
                : ScreenManager.TopScreen.GetType().Name;

            if (current == _lastScreen) return;

            _lastScreen = current;
            var line = (Timer.ElapsedMilliseconds / 1000).ToString() + "s " + current;
            Transitions.Add(line);
            WriteScreenFile();
        }

        private static void WriteScreenFile()
        {
            try
            {
                var dir = System.IO.Path.Combine(
                    System.Environment.GetFolderPath(System.Environment.SpecialFolder.MyDocuments),
                    "CommandBrainATH");
                System.IO.Directory.CreateDirectory(dir);
                var file = System.IO.Path.Combine(dir, "cbath-screen-" + System.Diagnostics.Process.GetCurrentProcess().Id + ".txt");
                var sb = new StringBuilder();
                sb.AppendLine("CBATH_SCREEN_TRANSITIONS");
                foreach (var t in Transitions) sb.AppendLine(t);
                System.IO.File.WriteAllText(file, sb.ToString(), Encoding.UTF8);
            }
            catch (System.Exception) { }
        }

        internal static Dictionary<string, object> Read()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                EnsureTimer();
                var result = new Dictionary<string, object>
                {
                    { "topScreenType", ScreenManager.TopScreen == null ? "<null>" : (object)ScreenManager.TopScreen.GetType().FullName },
                    { "mission", Mission.Current == null ? "<null>" : (object)Mission.Current.GetType().FullName },
                    { "moduleUptimeSec", Timer.ElapsedMilliseconds / 1000 },
                    { "transitions", string.Join(" | ", Transitions) }
                };

                if (GameStateManager.Current == null)
                {
                    result.Add("activeGameState", "<null>");
                }
                else
                {
                    var active = GameStateManager.Current.ActiveState;
                    result.Add("activeGameState", active == null ? "<null>" : active.GetType().FullName);
                }

                return result;
            }).GetAwaiter().GetResult();
        }
    }
}
