using System;
using System.Collections.Generic;
using TaleWorlds.Library;
using TaleWorlds.MountAndBlade;

namespace CombatBrainAutonomousTestHarness
{
    // P2 派单 §8：引擎侧独立只读取样。每次调用单次读取，不在引擎侧缓存任何状态；
    // 质心由有效 Agent 等权求得，与编队参考位置（positions 字段）分开报告，
    // 供验收方对照 CB2 自采用于在线决策的读数。
    internal static class P2FormationEvidence
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
                result.Add("scene", Safe(() => mission.SceneName, "<unknown>"));
                result.Add("mission_time", Safe(() => mission.CurrentTime.ToString("F3"), "<unknown>"));
                result.Add("sampled_utc", DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"));
                result.Add("build_id", BuildIdentity.BuildId);

                var teams = new List<object>();
                foreach (var team in mission.Teams)
                {
                    var formations = new List<object>();
                    foreach (var f in team.FormationsIncludingEmpty)
                    {
                        if (f.CountOfUnits == 0) continue;
                        formations.Add(ReadFormation(team, f));
                    }

                    teams.Add(new Dictionary<string, object>
                    {
                        { "team_index", team.TeamIndex },
                        { "side", Safe(() => team.Side.ToString(), "<unknown>") },
                        { "is_player_team", team.IsPlayerTeam },
                        { "formations", formations }
                    });
                }

                result.Add("teams", teams);
                return result;
            }).GetAwaiter().GetResult();
        }

        private static Dictionary<string, object> ReadFormation(Team team, Formation f)
        {
            // 有效活跃成员：活着、非坐骑。等权求质心；同时保留引擎人数口径以便对照。
            int activeCount = 0;
            double sumX = 0.0, sumY = 0.0;
            long digest = 17;
            bool positionUnknown = false;

            f.ApplyActionOnEachUnit(agent =>
            {
                if (agent == null)
                {
                    positionUnknown = true;
                    return;
                }
                if (!agent.IsActive() || agent.IsMount)
                {
                    return;
                }

                Vec3 p;
                try { p = agent.Position; }
                catch (Exception) { positionUnknown = true; return; }

                if (double.IsNaN(p.x) || double.IsNaN(p.y) ||
                    double.IsInfinity(p.x) || double.IsInfinity(p.y))
                {
                    positionUnknown = true;
                    return;
                }

                activeCount++;
                sumX += p.x;
                sumY += p.y;
                digest = unchecked(digest * 31 + agent.Index);
            });

            var entry = new Dictionary<string, object>
            {
                { "formation_index", (int)f.FormationIndex },
                { "formation_class", Safe(() => f.RepresentativeClass.ToString(), "<unknown>") },
                { "engine_unit_count", f.CountOfUnits },
                { "active_member_count", activeCount },
                { "member_digest", digest.ToString("x16") },
                { "active_center_known", activeCount > 0 && !positionUnknown },
                { "is_ai_controlled", f.IsAIControlled },
                { "player_owner_present", f.PlayerOwner != null },
                { "movement_order", Safe(() => OrderController.GetActiveMovementOrderOf(f).ToString(), "<unknown>") }
            };

            if (activeCount > 0 && !positionUnknown)
            {
                entry.Add("active_center", new Dictionary<string, object>
                {
                    { "x", (sumX / activeCount).ToString("F3") },
                    { "y", (sumY / activeCount).ToString("F3") }
                });
            }

            // 编队参考位置：与质心分开报告，验收方需要能区分两者。
            entry.Add("positions", Safe(() => PositionObj(f), null));
            entry.Add("move_target", ReadMoveTarget(f));

            return entry;
        }

        private static object PositionObj(Formation f)
        {
            var reference = f.ReferencePosition;
            return new Dictionary<string, object>
            {
                { "current_position", Vec2Obj(f.CurrentPosition) },
                { "cached_average", Vec2Obj(f.CachedAveragePosition) },
                { "smoothed_average_unit", Vec2Obj(f.SmoothedAverageUnitPosition) },
                { "reference_position", reference.HasValue ? Vec2Obj(reference.Value) : null },
                { "has_been_positioned", f.HasBeenPositioned }
            };
        }

        // 实际 Move 有效目标读回。不可读时明确报告 unreadable，不用 0 值冒充。
        private static object ReadMoveTarget(Formation f)
        {
            try
            {
                var reference = f.GetReadonlyMovementOrderReference();
                if (reference == null)
                {
                    return new Dictionary<string, object> { { "readable", false }, { "reason", "no_order_reference" } };
                }

                var kind = reference.OrderType.ToString();
                if (kind != "Move")
                {
                    return new Dictionary<string, object> { { "readable", false }, { "reason", "order_not_move" }, { "order_type", kind } };
                }

                var pos = reference.GetPosition(f);
                return new Dictionary<string, object>
                {
                    { "readable", true },
                    { "order_type", kind },
                    { "x", pos.x.ToString("F3") },
                    { "y", pos.y.ToString("F3") }
                };
            }
            catch (Exception e)
            {
                return new Dictionary<string, object> { { "readable", false }, { "reason", e.GetType().Name } };
            }
        }

        private static object Vec2Obj(Vec2 v)
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
