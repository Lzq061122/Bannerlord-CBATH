# P1-004 固定 Mission 自动进入 — 当前状态：BLOCKED（已记录 OPEN-P1-004）

日期：2026-09-24

## 目标

无需用户点击，Agent 进入一个固定、真实、可观测的 Battle Mission，
并能判定 MissionLoading / MissionRunning / MissionEnded。

## 已证明的事实（不是猜测）

1. **结构化 API 存在且能从 GABP 调用。**
   - `CPUBenchmarkMissionLogic.OpenCPUBenchmarkMission(String scene)` → `Mission`
   - `CustomBattleHelper.StartGame(CustomBattleData data)` （static void）
   - `CustomBattleState` 可被 `GameStateManager.Current.CreateState<CustomBattleState>()` 创建
   - `CustomBattleCombatant(TextObject name, BasicCultureObject culture, Banner banner)`
   以上均由**编译探针确认**（`experiments/custom-battle-probe/`），不是靠文档猜的。
   API 清单：`evidence/p1-004-custombattle-api.txt`、
   `evidence/p1-004-custombattledata-members.txt`

2. **从主菜单直接创建 Mission 的三条路线全部 NullReferenceException**，且堆栈都落在游戏内部，不是我的调用代码：

   | 路线 | 异常位置 |
   |---|---|
   | `OpenCPUBenchmarkMission(scene)` | NRE inside `OpenCPUBenchmarkMission` |
   | `PushState(CustomBattleState)` | NRE at `ArmyCompositionGroupVM..ctor` ← `CustomBattleSideVM..ctor` ← `CustomBattleVM..ctor` ← `CustomBattleScreen.OnInitialize` |
   | `CustomBattleHelper.StartGame(data)` | NRE at `CustomBattleData.get_Factions.MoveNext()` |

3. **根因收敛（有直接证据）**：`cbath/probe_mission_env` 在主菜单返回

   ```json
   {"game_current":"<null>","game_state_manager":"TaleWorlds.Core.GameStateManager",
    "active_state":"TaleWorlds.MountAndBlade.InitialState","mission_current":"<null>",
    "top_screen":"TaleWorlds.MountAndBlade.GauntletUI.GauntletInitialScreen",
    "custombattle_state_create":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattleState"}
   ```

   即：**`Game.Current == null`**，兵种/文化等游戏数据对象尚未初始化。
   三条路线的 NRE 都发生在"枚举或构造依赖这些数据的对象"时。

4. **反证（说明底层 API 本身没问题）**：用户手工进 Custom Battle 后，
   `cbath/get_all_formations` 成功读出双方 Formation（P1-003 PASS）。
   所以 Mission 与 Formation 在 1.4.8 都是可用的，缺的是**从主菜单无人值守地进入**这一步。

## OPEN-P1-004

| 项 | 内容 |
|---|---|
| **Question** | 在主菜单（`Game.Current == null`）下，如何让游戏完成数据初始化，使 Custom Battle / Mission 能被结构化创建？ |
| **Blocking phase** | P1-004（进而阻塞 P1-005 三轮闭环） |
| **Evidence checked** | CustomBattle 参考程序集 API dump；三条路线的运行时异常堆栈；`probe_mission_env` 运行时状态；玩家手工路径可行性的反证 |
| **Current hypotheses** | H1：需要先 `new Game(IGameStateManagerOwner, GameStateManagerType)` 创建 Game 对象（`Game` 的 ctor 已由 dump 确认），推入后数据才可用。H2：需要先进入 Campaign（加载存档/新战役）再切 Custom Battle，代价是引入存档依赖。H3：CustomBattleState 需要由它自己的 provider 创建（dump 中见 `CustomBattleProvider.StartCustomBattle()`），而非直接 `CreateState`。 |
| **Next experiment** | 按 H1：构造 `Game`（`GameStateManagerType` 枚举值待确认）后重试 `PushState`；若不成就试 H3 的 provider 路径；H2 作为最后手段。 |

## 为什么停在这里

- 已经用掉多轮在同一现象上，继续"再试一种调用"属于靠猜推进，违反调试协议
  （同一证据最多两轮，之后必须换新验证手段；我已经换了堆栈捕获、环境探测、三条不同路线）。
- prompt 要求遇到 Phase 0 未解决的问题时记录 OPEN 并判断是否阻塞，而不是无限试错。
- 用户已明确反对在非关键问题上长时间死磕。

## 已交付的实现（可用，待根因解决后即生效）

`experiments/test-mod/CBATH/MissionControl.cs` + `CbathTools.cs`：

- `cbath/start_fixed_mission`（当前走 `CustomBattleHelper.StartGame`，可切回 CPUBenchmark 路线）
- `cbath/get_mission_state` — 真实状态判据（`mission_running` + scene + mission_time），不是 sleep
- `cbath/end_mission`
- `cbath/probe_mission_env` — 诊断用
- `cbath/push_custombattle_state` — 诊断用

测试驱动：`tools/test-p1-004.ps1`（start / state / formation / end 四步断言）。

## 当前验收对照

| 判据 | 状态 |
|---|---|
| 创建固定 Mission | ❌ 三条路线均 NRE |
| 确认 MissionRunning | ⚠️ `cbath/get_mission_state` 已实现，但无 Mission 可测 |
| 调 Formation Snapshot 得双方数据 | ✅ 已由 P1-003 人工 bootstrap 证明可行 |
| 正常结束 Mission | ⚠️ `cbath/end_mission` 已实现，未实测 |
| 整个过程无用户点击 | ❌ 当前仍需人工进战斗 |
