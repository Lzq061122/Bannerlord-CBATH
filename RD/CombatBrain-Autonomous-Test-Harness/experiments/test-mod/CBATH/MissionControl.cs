using System;
using System.Collections.Generic;
using TaleWorlds.Core;
using TaleWorlds.Localization;
using TaleWorlds.MountAndBlade;
using TaleWorlds.MountAndBlade.CustomBattle;
using TaleWorlds.MountAndBlade.CustomBattle.CustomBattle;

namespace CombatBrainAutonomousTestHarness
{
    internal static class MissionControl
    {
        internal const string DefaultScene = "battle_terrain_biome_096";

        // Opens a fixed battle mission without any UI interaction.
        internal static Dictionary<string, object> Start(string scene)
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();

                if (Mission.Current != null)
                {
                    result.Add("status", "already_in_mission");
                    result.Add("mission_name", SafeName());
                    return result;
                }

                var sceneName = string.IsNullOrEmpty(scene) ? DefaultScene : scene;
                try
                {
                    var data = BuildMinimalData(sceneName);
                    CustomBattleHelper.StartGame(data);
                    result.Add("status", "ok");
                    result.Add("requested_scene", sceneName);
                    result.Add("mission_name", SafeName());
                    result.Add("error", "");
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("requested_scene", sceneName);
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                    result.Add("stack", ex.StackTrace ?? "");
                    var inner = ex.InnerException;
                    if (inner != null) result.Add("inner", inner.GetType().FullName + ": " + inner.Message);
                }

                return result;
            }).GetAwaiter().GetResult();
        }

        // Real state check, not a sleep: reports whether a mission exists and its elapsed time.
        internal static Dictionary<string, object> State()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                var m = Mission.Current;
                result.Add("mission_running", m != null);
                result.Add("mission_name", m == null ? "" : Safe(() => m.SceneName, "<unknown>"));
                result.Add("mission_time", m == null ? "" : Safe(() => m.CurrentTime.ToString("F3"), "<unknown>"));
                return result;
            }).GetAwaiter().GetResult();
        }

        internal static Dictionary<string, object> End()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                var m = Mission.Current;
                if (m == null)
                {
                    result.Add("status", "no_mission");
                    return result;
                }

                try
                {
                    m.EndMission();
                    result.Add("status", "ok");
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                }
                return result;
            }).GetAwaiter().GetResult();
        }

        // Reports the global objects a mission-creating call may depend on, so we can tell
        // from real runtime state which entry route is viable instead of guessing.
        internal static Dictionary<string, object> ProbeEnv()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();

                result.Add("game_current", Safe(() => Game.Current == null ? "<null>" : Game.Current.GetType().FullName, "<err>"));
                result.Add("game_state_manager", Safe(() => GameStateManager.Current == null ? "<null>" : GameStateManager.Current.GetType().FullName, "<err>"));
                result.Add("active_state", Safe(() =>
                {
                    var g = GameStateManager.Current;
                    if (g == null) return "<null>";
                    var a = g.ActiveState;
                    return a == null ? "<null>" : a.GetType().FullName;
                }, "<err>"));
                result.Add("mission_current", Safe(() => Mission.Current == null ? "<null>" : Mission.Current.SceneName, "<err>"));
                result.Add("top_screen", Safe(() =>
                {
                    var s = TaleWorlds.ScreenSystem.ScreenManager.TopScreen;
                    return s == null ? "<null>" : s.GetType().FullName;
                }, "<err>"));

                // does a CustomBattleState push work from here?
                try
                {
                    var state = GameStateManager.Current.CreateState<TaleWorlds.MountAndBlade.CustomBattle.CustomBattleState>();
                    result.Add("custombattle_state_create", state == null ? "<null>" : state.GetType().FullName);
                }
                catch (Exception ex)
                {
                    result.Add("custombattle_state_create", "error: " + ex.GetType().Name + ": " + ex.Message);
                }

                return result;
            }).GetAwaiter().GetResult();
        }

        // Custom Battle is a standalone GameState and does not need a Campaign, so pushing it
        // is the structured way to reach a battle from the main menu.
        internal static Dictionary<string, object> PushCustomBattleState()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                try
                {
                    var gsm = GameStateManager.Current;
                    if (gsm == null) { result.Add("status", "error"); result.Add("error", "GameStateManager.Current is null"); return result; }

                    gsm.PushState(gsm.CreateState<CustomBattleState>());
                    result.Add("status", "ok");
                    result.Add("active_state", Safe(() =>
                    {
                        var a = GameStateManager.Current.ActiveState;
                        return a == null ? "<null>" : a.GetType().FullName;
                    }, "<err>"));
                    result.Add("top_screen", Safe(() =>
                    {
                        var s = TaleWorlds.ScreenSystem.ScreenManager.TopScreen;
                        return s == null ? "<null>" : s.GetType().FullName;
                    }, "<err>"));
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                    result.Add("stack", ex.StackTrace ?? "");
                }
                return result;
            }).GetAwaiter().GetResult();
        }

        // Fill a CustomBattleData from the values the game itself offers, so we do not
        // hardcode ids that may not exist in this build.
        private static CustomBattleData BuildMinimalData(string scene)
        {
            var data = new CustomBattleData();
            data.SceneId = scene;

            var factions = new List<BasicCultureObject>();
            foreach (var f in CustomBattleData.Factions) factions.Add(f);
            var cultures = new List<BasicCharacterObject>();
            foreach (var c in CustomBattleData.Characters) cultures.Add(c);

            var culture = factions.Count > 0 ? factions[0] : null;
            var character = cultures.Count > 0 ? cultures[0] : null;

            data.PlayerParty = new CustomBattleCombatant(new TextObject("CBATH Attacker"), culture, null);
            data.EnemyParty = new CustomBattleCombatant(new TextObject("CBATH Defender"), culture, null);
            data.PlayerCharacter = character;
            data.IsPlayerAttacker = true;
            data.IsPlayerGeneral = true;
            return data;
        }

        // H1: create the Game object first, then push CustomBattleState.
        // Hypothesis: CustomBattle's VMs NRE because Game.Current is null at the main menu,
        // so the game data objects (troops, cultures) are not initialised yet.
        internal static Dictionary<string, object> H1CreateGameThenPush()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                try
                {
                    result.Add("game_before", Safe(() => Game.Current == null ? "<null>" : Game.Current.GetType().FullName, "<err>"));

                    if (Game.Current == null)
                    {
                        var gm = new CustomGameManager();
                        result.Add("game_manager", gm.GetType().FullName);
                        var gt = new CustomGame();
                        result.Add("game_type", gt.GetType().FullName);
                        var game = Game.CreateGame(gt, gm);
                        result.Add("game_created", game == null ? "<null>" : "ok");
                    }
                    else
                    {
                        result.Add("game_created", "already_exists");
                    }

                    result.Add("game_after", Safe(() => Game.Current == null ? "<null>" : Game.Current.GetType().FullName, "<err>"));

                    // now retry the push
                    var gsm = GameStateManager.Current;
                    gsm.PushState(gsm.CreateState<CustomBattleState>());
                    result.Add("status", "ok");
                    result.Add("active_state", Safe(() =>
                    {
                        var a = GameStateManager.Current.ActiveState;
                        return a == null ? "<null>" : a.GetType().FullName;
                    }, "<err>"));
                    result.Add("top_screen", Safe(() =>
                    {
                        var s = TaleWorlds.ScreenSystem.ScreenManager.TopScreen;
                        return s == null ? "<null>" : s.GetType().FullName;
                    }, "<err>"));
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                    result.Add("stack", ex.StackTrace ?? "");
                }
                return result;
            }).GetAwaiter().GetResult();
        }

        // H3: let CustomBattle's own provider start the battle instead of us pushing the
        // state ourselves. Tested on its own (no Game creation) to isolate the variable.
        internal static Dictionary<string, object> H3ProviderStart()
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                try
                {
                    result.Add("game_before", Safe(() => Game.Current == null ? "<null>" : Game.Current.GetType().FullName, "<err>"));

                    var provider = new CustomBattleProvider();
                    result.Add("provider", provider.GetType().FullName);
                    result.Add("provider_name", Safe(() => provider.GetName().ToString(), "<err>"));
                    provider.StartCustomBattle();

                    result.Add("status", "ok");
                    result.Add("game_after", Safe(() => Game.Current == null ? "<null>" : Game.Current.GetType().FullName, "<err>"));
                    result.Add("active_state", Safe(() =>
                    {
                        var a = GameStateManager.Current == null ? null : GameStateManager.Current.ActiveState;
                        return a == null ? "<null>" : a.GetType().FullName;
                    }, "<err>"));
                    result.Add("top_screen", Safe(() =>
                    {
                        var s = TaleWorlds.ScreenSystem.ScreenManager.TopScreen;
                        return s == null ? "<null>" : s.GetType().FullName;
                    }, "<err>"));
                    result.Add("mission", Safe(() => Mission.Current == null ? "<null>" : Mission.Current.SceneName, "<err>"));
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                    result.Add("stack", ex.StackTrace ?? "");
                }
                return result;
            }).GetAwaiter().GetResult();
        }

        // H3b: after the provider puts us on the CustomBattle screen, trigger its Start.
        // With no composition arguments this behaves exactly as before; arguments write the
        // battle setup into the same VM before ExecuteStart, inside the same main-thread task
        // so no UI frame can refresh the view model in between.
        internal static Dictionary<string, object> H3StartFromScreen()
        {
            return H3StartFromScreen(0, 0, "", "", "", "", "");
        }

        internal static Dictionary<string, object> H3StartFromScreen(
            int playerArmySize, int enemyArmySize, string playerComposition,
            string enemyComposition, string playerFaction, string enemyFaction, string mapId)
        {
            return MainThreadDispatcher.EnqueueAsync(() =>
            {
                var result = new Dictionary<string, object>();
                try
                {
                    var screen = TaleWorlds.ScreenSystem.ScreenManager.TopScreen;
                    result.Add("top_screen", screen == null ? "<null>" : screen.GetType().FullName);
                    if (screen == null) { result.Add("status", "error"); result.Add("error", "no top screen"); return result; }

                    // find the CustomBattleVM instance the screen holds
                    object vm = null;
                    string vmField = "";
                    foreach (var f in screen.GetType().GetFields(
                        System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public |
                        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.DeclaredOnly))
                    {
                        if (f.FieldType.Name == "CustomBattleVM")
                        {
                            vm = f.GetValue(screen);
                            vmField = f.Name;
                            break;
                        }
                    }

                    result.Add("vm_field", vmField == "" ? "<not found>" : vmField);
                    if (vm == null) { result.Add("status", "error"); result.Add("error", "CustomBattleVM instance not found"); return result; }

                    var cfg = ParseComposition(playerComposition, enemyComposition,
                                               playerArmySize, enemyArmySize,
                                               playerFaction, enemyFaction, mapId);
                    if (cfg != null)
                    {
                        var setup = BattleSetup.Apply(vm, cfg);
                        result.Add("setup", setup);
                        if (setup.ContainsKey("status") && (string)setup["status"] == "error")
                        {
                            result.Add("status", "error");
                            result.Add("error", "battle setup rejected: " + setup["error"]);
                            return result;
                        }
                        var selectedMap = setup.ContainsKey("map_selected_id") ? (string)setup["map_selected_id"] : "";
                        var wantedMap = string.IsNullOrEmpty(mapId) ? "" : mapId;
                        if (wantedMap.Length > 0 && selectedMap != wantedMap)
                        {
                            result.Add("status", "error");
                            result.Add("error", "map selection did not take effect: wanted " + wantedMap + " got " + selectedMap);
                            return result;
                        }
                    }

                    var mi = vm.GetType().GetMethod("ExecuteStart",
                        System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic);
                    if (mi == null) { result.Add("status", "error"); result.Add("error", "ExecuteStart not found"); return result; }

                    mi.Invoke(vm, null);
                    result.Add("status", "ok");
                    result.Add("invoked", "ExecuteStart");
                    result.Add("mission", Safe(() => Mission.Current == null ? "<null>" : Mission.Current.SceneName, "<err>"));
                    result.Add("top_screen_after", Safe(() =>
                    {
                        var s = TaleWorlds.ScreenSystem.ScreenManager.TopScreen;
                        return s == null ? "<null>" : s.GetType().FullName;
                    }, "<err>"));
                }
                catch (Exception ex)
                {
                    result.Add("status", "error");
                    result.Add("error", ex.GetType().FullName + ": " + ex.Message);
                    result.Add("stack", ex.StackTrace ?? "");
                }
                return result;
            }).GetAwaiter().GetResult();
        }

        // Null when no composition argument was supplied, so the original launch path is used.
        private static BattleSetup.Config ParseComposition(string playerComposition, string enemyComposition,
                                                           int playerArmySize, int enemyArmySize,
                                                           string playerFaction, string enemyFaction, string mapId)
        {
            if (string.IsNullOrEmpty(playerComposition) && string.IsNullOrEmpty(enemyComposition) &&
                playerArmySize <= 0 && enemyArmySize <= 0 &&
                string.IsNullOrEmpty(playerFaction) && string.IsNullOrEmpty(enemyFaction) &&
                string.IsNullOrEmpty(mapId))
            {
                return null;
            }

            return new BattleSetup.Config
            {
                PlayerFaction = playerFaction,
                EnemyFaction = enemyFaction,
                PlayerArmySize = playerArmySize,
                EnemyArmySize = enemyArmySize,
                PlayerComposition = ParseInts(playerComposition),
                EnemyComposition = ParseInts(enemyComposition),
                MapId = mapId
            };
        }

        private static int[] ParseInts(string csv)
        {
            var parts = (csv ?? "").Split(',');
            var values = new int[parts.Length];
            for (int i = 0; i < parts.Length; i++)
            {
                int parsed;
                int.TryParse(parts[i].Trim(), out parsed);
                values[i] = parsed;
            }
            return values;
        }

        private static string SafeName()
        {
            var m = Mission.Current;
            return m == null ? "" : Safe(() => m.SceneName, "<unknown>");
        }

        private static string Safe(Func<string> f, string fallback)
        {
            try { return f() ?? fallback; }
            catch (Exception) { return fallback; }
        }
    }
}
