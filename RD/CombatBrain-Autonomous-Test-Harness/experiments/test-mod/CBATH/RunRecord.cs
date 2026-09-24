using System;
using System.Collections.Generic;

namespace CombatBrainAutonomousTestHarness
{
    // Holds the most recent completed sampling run in memory so cbath/get_last_run
    // can return the whole timeline in one call.
    internal static class RunRecord
    {
        private static readonly object Gate = new object();

        private static Dictionary<string, object> _lastRun;
        private static string _lastRunId;
        private static int _runCounter;

        internal static void Begin(string sceneName, float startedAt)
        {
            lock (Gate)
            {
                _runCounter++;
                _lastRunId = "run-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + _runCounter;
            }
        }

        internal static void Complete(string sceneName, float startedAt, float endedAt,
                                      List<Dictionary<string, object>> samples)
        {
            lock (Gate)
            {
                var copy = new List<object>();
                foreach (var s in samples) copy.Add(s);

                _lastRun = new Dictionary<string, object>
                {
                    { "run_id", _lastRunId },
                    { "mission_name", sceneName },
                    { "mission_start_time", startedAt.ToString("F3") },
                    { "mission_end_time", endedAt.ToString("F3") },
                    { "sample_interval_seconds", SamplingMissionBehavior.SampleIntervalSeconds },
                    { "sample_count", copy.Count },
                    { "samples", copy }
                };
            }
        }

        internal static Dictionary<string, object> Get()
        {
            lock (Gate)
            {
                if (_lastRun == null)
                {
                    return new Dictionary<string, object>
                    {
                        { "status", "no_run" },
                        { "reason", "no mission has completed since this module loaded" }
                    };
                }

                var result = new Dictionary<string, object> { { "status", "ok" } };
                foreach (var kv in _lastRun) result[kv.Key] = kv.Value;
                return result;
            }
        }
    }
}
