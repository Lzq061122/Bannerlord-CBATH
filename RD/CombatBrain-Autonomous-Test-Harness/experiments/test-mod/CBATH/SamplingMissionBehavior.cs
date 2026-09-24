using System;
using System.Collections.Generic;
using TaleWorlds.Library;
using TaleWorlds.MountAndBlade;

namespace CombatBrainAutonomousTestHarness
{
    // Records a 1 Hz engine-side timeline for the duration of one mission.
    // Engine types only - no dependency on any AI mod's types, logs or enums.
    internal class SamplingMissionBehavior : MissionBehavior
    {
        internal const float SampleIntervalSeconds = 1.0f;
        internal const int MaxSamples = 900;

        private readonly List<Dictionary<string, object>> _samples = new List<Dictionary<string, object>>();
        private float _nextSampleAt;
        private float _startedAt;
        private float _lastTickAt;
        private string _sceneName = "";
        private bool _started;

        public override MissionBehaviorType BehaviorType { get { return MissionBehaviorType.Other; } }

        // AddMissionBehavior does not invoke OnBehaviorInitialize on the added instance,
        // so the run record is opened lazily from the first tick instead.
        private void EnsureStarted(TaleWorlds.MountAndBlade.Mission mission, float now)
        {
            if (_started) return;
            _started = true;
            _startedAt = now;
            _nextSampleAt = now;
            _sceneName = mission == null ? "" : mission.SceneName;
            RunRecord.Begin(_sceneName, _startedAt);
        }

        public override void OnMissionTick(float dt)
        {
            base.OnMissionTick(dt);
            var mission = Mission.Current;
            if (mission == null) return;

            float now = mission.CurrentTime;
            EnsureStarted(mission, now);
            _lastTickAt = now;
            if (string.IsNullOrEmpty(_sceneName)) _sceneName = mission.SceneName;
            if (now < _nextSampleAt) return;
            _nextSampleAt = now + SampleIntervalSeconds;

            if (_samples.Count >= MaxSamples) return;
            _samples.Add(Capture(now));
        }

        protected override void OnEndMission()
        {
            base.OnEndMission();
            var mission = Mission.Current;
            string scene = string.IsNullOrEmpty(_sceneName)
                ? (mission == null ? "<unknown>" : mission.SceneName)
                : _sceneName;
            float end = mission == null ? _lastTickAt : mission.CurrentTime;
            RunRecord.Complete(scene, _startedAt, end, _samples);
        }

        private static Dictionary<string, object> Capture(float now)
        {
            var sample = new Dictionary<string, object> { { "t", now.ToString("F3") } };

            var mission = Mission.Current;
            if (mission == null)
            {
                sample.Add("teams", new List<object>());
                return sample;
            }

            var teams = new List<object>();
            foreach (var team in mission.Teams)
            {
                var formations = new List<object>();
                foreach (var f in team.FormationsIncludingEmpty)
                {
                    if (f.CountOfUnits == 0) continue;

                    formations.Add(new Dictionary<string, object>
                    {
                        { "formation_index", (int)f.FormationIndex },
                        { "formation_class", Safe(() => f.RepresentativeClass.ToString(), "<unknown>") },
                        { "unit_count", f.CountOfUnits },
                        { "position", Safe(() => Vec2ToObj(f.CurrentPosition), null) },
                        { "facing", Safe(() => Vec2ToObj(f.Direction), null) },
                        { "movement_order", Safe(() => OrderController.GetActiveMovementOrderOf(f).ToString(), "<unknown>") },
                        { "arrangement_order", Safe(() => OrderController.GetActiveArrangementOrderOf(f).ToString(), "<unknown>") },
                        { "firing_order", Safe(() => OrderController.GetActiveFiringOrderOf(f).ToString(), "<unknown>") },
                        { "is_ai_controlled", f.IsAIControlled },
                        { "active_behavior", Safe(() => DescribeActiveBehavior(f), "<unknown>") },
                        { "closest_enemy_formation_index", Safe(() => DescribeClosestEnemy(f), "<unknown>") }
                    });
                }

                teams.Add(new Dictionary<string, object>
                {
                    { "team_id", team.TeamIndex },
                    { "side", Safe(() => team.Side.ToString(), "<unknown>") },
                    { "is_player_team", team.IsPlayerTeam },
                    { "formation_count", formations.Count },
                    { "formations", formations }
                });
            }

            sample.Add("teams", teams);
            return sample;
        }

        // Observation-only read of the engine's current AI behavior name.
        private static string DescribeActiveBehavior(Formation f)
        {
            var ai = f.AI;
            if (ai == null) return "<no_ai>";
            var behavior = ai.ActiveBehavior;
            if (behavior == null) return "<null>";
            return behavior.GetType().Name;
        }

        // Target-formation identity is NOT reliably obtainable: both
        // Formation.QuerySystem.ClosestSignificantlyLargeEnemyFormation and
        // Formation.CachedClosestEnemyFormation return a FormationQuerySystem,
        // which exposes no FormationIndex. Emitting a substitute value such as
        // "0.00/Inf" would be mistaken for a real identifier, so this reports
        // unavailable and the stable-identity gap is left open on purpose.
        private const string TargetUnavailable = "unavailable:no_stable_formation_id";

        private static string DescribeClosestEnemy(Formation f)
        {
            var qs = f.QuerySystem;
            if (qs == null) return TargetUnavailable;
            var enemy = qs.ClosestSignificantlyLargeEnemyFormation;
            if (enemy == null) return TargetUnavailable;
            return TargetUnavailable;
        }

        private static object Vec2ToObj(Vec2 v)
        {
            return new Dictionary<string, object>
            {
                { "x", v.x.ToString("F3") },
                { "y", v.y.ToString("F3") }
            };
        }

        private static string Safe(Func<string> f, string fallback)
        {
            try { return f() ?? fallback; }
            catch (Exception e) { return fallback + ":" + e.GetType().Name; }
        }

        private static object Safe(Func<object> f, object fallback)
        {
            try { return f() ?? fallback; }
            catch (Exception) { return fallback; }
        }
    }
}
