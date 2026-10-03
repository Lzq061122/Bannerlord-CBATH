using System;
using System.Collections.Generic;
using TaleWorlds.MountAndBlade;

namespace CombatBrainAutonomousTestHarness
{
    // Replaces the two manual inputs that start a real battle:
    //   - the "ready" button  -> DeploymentMissionController.FinishDeployment()
    //   - the F6 key          -> Formation.SetControlledByAI on every player formation
    // Engine public API only; no Win32 input simulation.
    //
    // These run on the game's main thread, so neither method may spin or sleep while
    // waiting for deployment readiness - the caller polls the returned state instead.
    internal static class AutoDeployControl
    {
        // Single check: if deployment is ready, finish it and report the before/after state.
        internal static Dictionary<string, object> AutoFinishDeployment()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();

                var mission = Mission.Current;
                if (mission == null)
                {
                    result.Add("status", "no_mission");
                    return result;
                }

                var controller = FindDeploymentController(mission);
                if (controller == null)
                {
                    result.Add("status", "no_deployment_controller");
                    result.Add("allow_ai_ticking_before", AllowAiTicking(mission));
                    return result;
                }

                var before = DeploymentState(mission, controller);
                result.Add("before", before);

                if (!controller.TeamSetupOver)
                {
                    result.Add("status", "not_ready");
                    result.Add("reason", "DeploymentMissionController.TeamSetupOver is false");
                    return result;
                }

                try
                {
                    controller.FinishDeployment();
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                    return result;
                }

                result.Add("after", DeploymentState(mission, controller));
                result.Add("status", "ok");
                return result;
            }).GetAwaiter().GetResult();
        }

        // Mirrors the F6 key: hand every formation of the player's team to the engine AI.
        internal static Dictionary<string, object> DelegateTeamToAi()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();

                var mission = Mission.Current;
                if (mission == null)
                {
                    result.Add("status", "no_mission");
                    return result;
                }

                var team = mission.PlayerTeam;
                if (team == null)
                {
                    result.Add("status", "no_player_team");
                    return result;
                }

                var formations = new List<object>();
                var beforeTeamAiControlled = true;

                // FormationsIncludingEmpty matches Team.DelegateCommandToAI exactly, so empty
                // formations are handed over too rather than silently skipped.
                foreach (var f in team.FormationsIncludingEmpty)
                {
                    var entry = new Dictionary<string, object>();
                    entry.Add("formation_index", SafeInt(() => (int)f.FormationIndex));
                    entry.Add("formation_class", Safe(() => f.RepresentativeClass.ToString(), "<unknown>"));
                    entry.Add("unit_count", SafeInt(() => f.CountOfUnits));
                    entry.Add("is_ai_controlled_before", f.IsAIControlled);

                    string error = "";
                    try
                    {
                        f.SetControlledByAI(true, false);
                    }
                    catch (Exception ex)
                    {
                        error = ex.GetType().Name + ": " + ex.Message;
                    }

                    entry.Add("is_ai_controlled_after", f.IsAIControlled);
                    entry.Add("error", error);
                    formations.Add(entry);

                    if (!f.IsAIControlled) beforeTeamAiControlled = false;
                }

                result.Add("status", "ok");
                result.Add("team_index", team.TeamIndex);
                result.Add("formation_count", formations.Count);
                result.Add("all_ai_controlled", beforeTeamAiControlled);
                result.Add("formations", formations);
                return result;
            }).GetAwaiter().GetResult();
        }

        // The deployment behaviour is a MissionBehavior; BattleDeploymentMissionController
        // derives from DeploymentMissionController, so the base type covers both.
        private static DeploymentMissionController FindDeploymentController(Mission mission)
        {
            foreach (var behavior in mission.MissionBehaviors)
            {
                var controller = behavior as DeploymentMissionController;
                if (controller != null) return controller;
            }
            return null;
        }

        private static Dictionary<string, object> DeploymentState(Mission mission,
                                                                  DeploymentMissionController controller)
        {
            return new Dictionary<string, object>
            {
                { "team_setup_over", controller.TeamSetupOver },
                { "allow_ai_ticking", AllowAiTicking(mission) },
                { "mission_time", Safe(() => mission.CurrentTime.ToString("F3"), "<unknown>") },
                { "player_team_formations", SafeInt(() => mission.PlayerTeam == null
                    ? 0 : mission.PlayerTeam.FormationsIncludingEmpty.Count) }
            };
        }

        private static bool AllowAiTicking(Mission mission)
        {
            try { return mission.AllowAiTicking; }
            catch (Exception) { return false; }
        }

        private static int SafeInt(Func<int> f)
        {
            try { return f(); }
            catch (Exception) { return -1; }
        }

        private static string Safe(Func<string> f, string fallback)
        {
            try { return f() ?? fallback; }
            catch (Exception) { return fallback; }
        }
    }
}
