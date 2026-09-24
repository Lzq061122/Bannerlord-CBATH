using System;
using System.Diagnostics;
using Lib.GAB.Tools;

namespace CombatBrainAutonomousTestHarness
{
    public class CbathTools
    {
        [Tool("cbath/ping", Description = "Liveness probe. Returns pong plus process and build identity.")]
        public object Ping()
        {
            return new
            {
                status = "ok",
                pong = true,
                utc = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
                pid = Process.GetCurrentProcess().Id,
                build_id = BuildIdentity.BuildId,
                game_version = RuntimeIdentity.GameVersion()
            };
        }

        [Tool("cbath/get_build_identity", Description = "Full runtime identity of the loaded test mod DLL.")]
        public object GetBuildIdentity()
        {
            return MainThreadDispatcher.EnqueueAsync(() => RuntimeIdentity.AsObject()).GetAwaiter().GetResult();
        }

        [Tool("cbath/get_game_state", Description = "Active game state, top screen type and mission type; used to wait on a real condition instead of sleeping.")]
        public object GetGameState()
        {
            return ScreenProbe.Read();
        }

        [Tool("cbath/get_all_formations", Description = "All non-empty formations of every team in the current mission, with position, facing and the three active orders.")]
        public object GetAllFormations()
        {
            return FormationProbe.Read();
        }

        [Tool("cbath/start_fixed_mission", Description = "Open a fixed battle mission with no UI interaction.")]
        public object StartFixedMission([ToolParameter(Description = "Scene name; defaults to the fixed test scene")] string scene = "")
        {
            return MissionControl.Start(scene);
        }

        [Tool("cbath/get_mission_state", Description = "Whether a mission is running, plus its scene and elapsed time. A real condition check, not a sleep.")]
        public object GetMissionState()
        {
            return MissionControl.State();
        }

        [Tool("cbath/end_mission", Description = "End the current mission.")]
        public object EndMission()
        {
            return MissionControl.End();
        }

        [Tool("cbath/probe_mission_env", Description = "Report the global objects mission creation depends on, to diagnose why an entry route fails.")]
        public object ProbeMissionEnv()
        {
            return MissionControl.ProbeEnv();
        }

        [Tool("cbath/push_custombattle_state", Description = "Push the CustomBattle game state, the structured way to reach a battle without a Campaign.")]
        public object PushCustomBattleState()
        {
            return MissionControl.PushCustomBattleState();
        }

        [Tool("cbath/h1_create_game_then_push", Description = "H1 experiment: create the Game object first, then push CustomBattleState.")]
        public object H1CreateGameThenPush()
        {
            return MissionControl.H1CreateGameThenPush();
        }

        [Tool("cbath/h3_provider_start", Description = "H3 experiment: let CustomBattle's own provider start the battle.")]
        public object H3ProviderStart()
        {
            return MissionControl.H3ProviderStart();
        }

        [Tool("cbath/h3_start_from_screen", Description = "H3b: on the CustomBattle screen, invoke its ExecuteStart to launch the battle.")]
        public object H3StartFromScreen()
        {
            return MissionControl.H3StartFromScreen();
        }

        [Tool("cbath/get_last_run", Description = "Full 1 Hz engine-side Formation timeline recorded during the most recent mission.")]
        public object GetLastRun()
        {
            return RunRecord.Get();
        }
    }
}
