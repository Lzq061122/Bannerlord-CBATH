using System;
using System.Collections.Generic;
using TaleWorlds.Library;
using TaleWorlds.MountAndBlade;

namespace CombatBrainAutonomousTestHarness
{
    internal static class FormationProbe
    {
        internal static Dictionary<string, object> Read()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                var mission = Mission.Current;

                if (mission == null)
                {
                    result.Add("status", "no_mission");
                    result.Add("reason", "Mission.Current is null");
                    result.Add("teams", new List<object>());
                    return result;
                }

                result.Add("status", "ok");
                result.Add("mission_name", Safe(() => mission.SceneName, "<unknown>"));
                result.Add("mission_time", Safe(() => mission.CurrentTime.ToString("F3"), "<unknown>"));

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
                            { "is_ai_controlled", f.IsAIControlled }
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

                result.Add("teams", teams);
                return result;
            }).GetAwaiter().GetResult();
        }

        private static object Vec3ToObj(Vec3 v)
        {
            return new Dictionary<string, object>
            {
                { "x", v.x.ToString("F3") },
                { "y", v.y.ToString("F3") },
                { "z", v.z.ToString("F3") }
            };
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
