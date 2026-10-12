using System;
using System.Collections.Generic;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;
using TaleWorlds.MountAndBlade.CustomBattle;
using TaleWorlds.MountAndBlade.CustomBattle.CustomBattle;
using TaleWorlds.MountAndBlade.CustomBattle.CustomBattle.SelectionItem;

namespace CombatBrainAutonomousTestHarness
{
    // Writes a battle composition into the live CustomBattle screen view model, using only
    // engine public members. The VM chain is walked reflectively because CustomBattleScreen
    // keeps its CustomBattleVM in a private field; every value written is a public member.
    internal static class BattleSetup
    {
        internal const string DefaultMapId = "battle_terrain_biome_096";

        internal sealed class Config
        {
            internal string PlayerFaction = "";
            internal string EnemyFaction = "";
            internal int PlayerArmySize;
            internal int EnemyArmySize;
            // order: melee infantry, ranged infantry, melee cavalry, ranged cavalry
            internal int[] PlayerComposition;
            internal int[] EnemyComposition;
            internal string MapId = "";
        }

        internal static Dictionary<string, object> Apply(object vm, Config cfg)
        {
            var result = new Dictionary<string, object>();

            var playerSide = Prop(vm, "PlayerSide");
            var enemySide = Prop(vm, "EnemySide");
            var mapGroup = Prop(vm, "MapSelectionGroup");
            if (playerSide == null || enemySide == null || mapGroup == null)
            {
                result.Add("status", "error");
                result.Add("error", "CustomBattleVM property chain incomplete");
                return result;
            }

            result.Add("applied_player_army_size", cfg.PlayerArmySize);
            result.Add("applied_enemy_army_size", cfg.EnemyArmySize);
            result.Add("applied_player_composition", JoinInts(cfg.PlayerComposition));
            result.Add("applied_enemy_composition", JoinInts(cfg.EnemyComposition));

            // Culture first: SetCurrentSelectedCulture rebuilds TroopTypes for the new culture,
            // through the same public chain the engine's own randomize uses.
            var playerCulture = SetCulture(playerSide, cfg.PlayerFaction, result, "player");
            var enemyCulture = SetCulture(enemySide, cfg.EnemyFaction, result, "enemy");
            result.Add("player_culture", SafeId(playerCulture));
            result.Add("enemy_culture", SafeId(enemyCulture));
            if (playerCulture == null || enemyCulture == null)
            {
                result.Add("status", "error");
                result.Add("error", "faction not resolved");
                return result;
            }

            WriteSide(playerSide, cfg.PlayerArmySize, cfg.PlayerComposition, result, "player");
            WriteSide(enemySide, cfg.EnemyArmySize, cfg.EnemyComposition, result, "enemy");

            WriteMap(mapGroup, cfg.MapId, result);

            return result;
        }

        private static void WriteSide(object side, int armySize, int[] composition, Dictionary<string, object> result, string prefix)
        {
            var group = Prop(side, "CompositionGroup");
            if (group == null)
            {
                result.Add(prefix + "_composition_error", "CompositionGroup is null");
                return;
            }

            Set(group, "ArmySize", armySize);

            var items = Items(group);
            for (int i = 0; i < items.Length && i < composition.Length; i++)
            {
                Set(items[i], "CompositionValue", composition[i]);
            }

            // CompositionValue only sizes the count split; which troop is used is decided by
            // TroopTypes[x].IsSelected. PopulateTroopTypes already selected the IsDefault item,
            // this aligns every item explicitly to that same choice.
            var selections = new List<string>();
            for (int i = 0; i < items.Length; i++)
            {
                int selected = 0;
                int total = 0;
                var list = Prop(items[i], "TroopTypes") as System.Collections.IEnumerable;
                if (list != null)
                {
                    foreach (var t in list)
                    {
                        total++;
                        bool isDefault = (bool)(Prop(t, "IsDefault") ?? false);
                        Set(t, "IsSelected", isDefault);
                        if (isDefault) selected++;
                    }
                }
                selections.Add(selected + "/" + total);
            }
            result.Add(prefix + "_troop_selection", string.Join(",", selections));

            result.Add(prefix + "_army_size_readback", ReadInt(side, "ArmySize"));
            result.Add(prefix + "_composition_readback", ReadInts(items, "CompositionValue"));
            result.Add(prefix + "_percentage_text", ReadStrings(items, "CompositionValuePercentageText"));
        }

        private static void WriteMap(object mapGroup, string mapId, Dictionary<string, object> result)
        {
            var wanted = string.IsNullOrEmpty(mapId) ? DefaultMapId : mapId;
            var selection = Prop(mapGroup, "MapSelection");
            var itemList = selection == null ? null : Prop(selection, "ItemList") as System.Collections.IEnumerable;
            if (itemList == null)
            {
                result.Add("map_selection_error", "MapSelection.ItemList unavailable");
                return;
            }

            int index = -1;
            int count = 0;
            foreach (var item in itemList)
            {
                if ((Prop(item, "MapId") as string) == wanted) index = count;
                count++;
            }

            result.Add("map_item_count", count);
            result.Add("map_requested", wanted);
            if (index < 0)
            {
                result.Add("map_selection_error", "requested map not present in the battle map list");
                return;
            }

            // SelectedIndex does not raise the change callback when the value is unchanged,
            // so the resulting SelectedMap is read back and reported as the actual fact.
            Set(selection, "SelectedIndex", index);
            result.Add("map_selected_index", index);

            var selected = Prop(mapGroup, "SelectedMap");
            result.Add("map_selected_id", selected == null ? "<null>" : (Prop(selected, "MapId") as string ?? "<null>"));
            result.Add("map_selected_name", selected == null ? "<null>" : (Prop(selected, "MapName") as string ?? "<null>"));
        }

        private static BasicCultureObject SetCulture(object side, string factionId, Dictionary<string, object> result, string prefix)
        {
            var group = Prop(side, "FactionSelectionGroup");
            if (group == null)
            {
                result.Add(prefix + "_faction_error", "FactionSelectionGroup is null");
                return null;
            }

            var current = Prop(group, "SelectedItem");
            var currentFaction = current == null ? null : Prop(current, "Faction") as BasicCultureObject;
            if (string.IsNullOrEmpty(factionId)) return currentFaction;

            BasicCultureObject wanted = null;
            foreach (var f in CustomBattleData.Factions)
            {
                if (f != null && string.Equals(SafeId(f), factionId, StringComparison.OrdinalIgnoreCase))
                {
                    wanted = f;
                    break;
                }
            }
            if (wanted == null)
            {
                result.Add(prefix + "_faction_error", "faction not found: " + factionId);
                return currentFaction;
            }

            // FactionItemVM.IsSelected is the engine's own selection path and ends in
            // ArmyCompositionGroupVM.SetCurrentSelectedCulture.
            var item = new FactionItemVM(wanted, null);
            Set(item, "IsSelected", true);

            var after = Prop(group, "SelectedItem");
            var afterFaction = after == null ? null : Prop(after, "Faction") as BasicCultureObject;
            return afterFaction ?? currentFaction;
        }

        private static object[] Items(object group)
        {
            return new[]
            {
                Prop(group, "MeleeInfantryComposition"),
                Prop(group, "RangedInfantryComposition"),
                Prop(group, "MeleeCavalryComposition"),
                Prop(group, "RangedCavalryComposition")
            };
        }

        internal static object Prop(object target, string name)
        {
            if (target == null) return null;
            try { return PropInfo(target, name).GetValue(target, null); }
            catch (Exception) { return null; }
        }

        internal static void SetProp(object target, string name, object value)
        {
            if (target == null) return;
            try { PropInfo(target, name).SetValue(target, value, null); }
            catch (Exception) { }
        }

        internal static object ReadProp(object owner, string name)
        {
            var box = Prop(owner, name);
            if (box == null) return null;
            try { return PropInfo(box, "Value").GetValue(box, null); }
            catch (Exception) { return null; }
        }

        private static System.Reflection.PropertyInfo PropInfo(object target, string name)
        {
            var p = target.GetType().GetProperty(name, System.Reflection.BindingFlags.Instance |
                                                       System.Reflection.BindingFlags.Public |
                                                       System.Reflection.BindingFlags.NonPublic);
            if (p == null) throw new MissingMemberException(target.GetType().FullName, name);
            return p;
        }

        private static void Set(object owner, string name, object value)
        {
            SetProp(owner, name, value);
        }

        private static int ReadInt(object owner, string name)
        {
            var v = ReadProp(owner, name);
            try { return v == null ? -1 : Convert.ToInt32(v); }
            catch (Exception) { return -1; }
        }

        private static string ReadInts(object[] items, string name)
        {
            var parts = new List<string>();
            foreach (var item in items) parts.Add(ReadInt(item, name).ToString());
            return string.Join(",", parts);
        }

        private static string ReadStrings(object[] items, string name)
        {
            var parts = new List<string>();
            foreach (var item in items)
            {
                var v = ReadProp(item, name);
                parts.Add(v == null ? "<null>" : Convert.ToString(v));
            }
            return string.Join("|", parts);
        }

        private static string SafeId(BasicCultureObject faction)
        {
            try { return faction == null ? "<null>" : faction.StringId; }
            catch (Exception) { return "<error>"; }
        }

        private static string JoinInts(int[] values)
        {
            return values == null ? "" : string.Join(",", values);
        }
    }
}
