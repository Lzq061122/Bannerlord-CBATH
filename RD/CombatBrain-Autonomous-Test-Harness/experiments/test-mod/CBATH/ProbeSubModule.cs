using System;
using System.IO;
using TaleWorlds.MountAndBlade;

namespace CombatBrainAutonomousTestHarness
{
    public class ProbeSubModule : MBSubModuleBase
    {
        private static Lib.GAB.Server.GabpServer _server;
        private static string _serverState = "not_started";
        private static string _serverError = "";

        private bool _identityEmitted;

        protected override void OnSubModuleLoad()
        {
            base.OnSubModuleLoad();
            RuntimeIdentity.Emit();
            _identityEmitted = true;
            ScreenProbe.EnsureTimer();
            StartGabpServer();
        }

        protected override void OnBeforeInitialModuleScreenSetAsRoot()
        {
            base.OnBeforeInitialModuleScreenSetAsRoot();
            if (!_identityEmitted)
            {
                RuntimeIdentity.Emit();
                _identityEmitted = true;
            }
        }

        protected override void OnApplicationTick(float dt)
        {
            base.OnApplicationTick(dt);
            MainThreadDispatcher.ProcessQueue();
            if (!_identityEmitted)
            {
                RuntimeIdentity.Emit();
                _identityEmitted = true;
            }
            ScreenProbe.Sample();
        }

        public override void OnMissionBehaviorInitialize(Mission mission)
        {
            base.OnMissionBehaviorInitialize(mission);
            mission.AddMissionBehavior(new SamplingMissionBehavior());
        }

        private static void StartGabpServer()
        {
            if (_server != null) return;
            try
            {
                var tools = new CbathTools();
                _server = Lib.GAB.Gabp.CreateGabsAwareServerWithInstance(
                    "CombatBrainAutonomousTestHarness",
                    BuildIdentity.BuildId,
                    tools,
                    fallbackPort: 0);

                _server.StartAsync();
                _serverState = "starting";
                WriteBridgeInfo();
            }
            catch (Exception ex)
            {
                _serverState = "error";
                _serverError = ex.ToString();
                WriteBridgeInfo();
            }
        }

        private static void WriteBridgeInfo()
        {
            try
            {
                var dir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
                    "CommandBrainATH");
                Directory.CreateDirectory(dir);
                var file = Path.Combine(dir, "cbath-gabp-" + System.Diagnostics.Process.GetCurrentProcess().Id + ".txt");
                var lines = new[]
                {
                    "CBATH_GABP_STATE",
                    "state=" + _serverState,
                    "gabs_aware=" + Lib.GAB.Gabp.IsRunningUnderGabs(),
                    "port=" + (_server != null ? _server.Port.ToString() : "-1"),
                    "token=" + (_server != null ? _server.Token : ""),
                    "build_id=" + BuildIdentity.BuildId,
                    "error=" + _serverError
                };
                File.AppendAllText(file, string.Join("\n", lines) + "\n\n", System.Text.Encoding.UTF8);
            }
            catch (Exception) { }
        }
    }
}
