# P1-004 固定 Mission 自动进入 — 结果：PASS（无人值守）

日期：2026-09-24
前置：P1-001 / P1-002 / P1-003 均已 PASS

---

## 结论

**Agent 无需用户点击即可进入固定战斗 Mission，读取双方 Formation，并正常结束 Mission。**

有效路线（两步，均结构化、无 UI 点击）：

```text
new CustomBattleProvider().StartCustomBattle()   →  CustomBattleState / CustomBattleScreen
CustomBattleVM.ExecuteStart()                    →  MissionScreen（战斗开始）
```

---

## H1：创建 Game 后再 PushState — 失败

**假设**：CustomBattle 的 VM NRE 是因为 `Game.Current == null`，先创建 Game 即可。

**实验**：`Game.CreateGame(new CustomGame(), new CustomGameManager())` 后 `PushState(CreateState<CustomBattleState>())`

**运行证据**：

```json
{"game_before":"<null>","game_created":"ok","game_after":"TaleWorlds.Core.Game",
 "game_type":"TaleWorlds.MountAndBlade.CustomBattle.CustomGame",
 "error":"System.NullReferenceException",
 "stack":"   at ...ArmyCompositionItemVM.UpdatePercentageText(Int32 percentage)
           at ...ArmyCompositionGroupVM..ctor(TroopTypeSelectionPopUpVM)
           at ...CustomBattleSideVM..ctor(...)
           at ...CustomBattleVM..ctor(CustomBattleState battleState)
           at ...CustomBattleScreen.OnInitialize()"}
```

**判定：失败。** Game 确实创建成功了（`game_after=TaleWorlds.Core.Game`），
但 PushState 仍 NRE，且**异常位置比之前更深一层**
（从 `ArmyCompositionGroupVM..ctor` 进到 `ArmyCompositionItemVM.UpdatePercentageText`）。

这说明：创建 Game 解决了第一层依赖，但 `CustomBattleVM` 的构造路径仍有它自己期望的初始化上下文，
我们自己 `CreateState` 推入不满足这个上下文。**不是缺 Game 那么简单。**

---

## H3：让 CustomBattle 自己的 provider 启动 — 成功

**假设**：CustomBattleState 应由它自己的 provider 创建/启动，而非我们直接 `CreateState` + `PushState`。

**第 1 步** `new CustomBattleProvider().StartCustomBattle()`：

```json
{"status":"ok","provider":"...CustomBattle.CustomBattle.CustomBattleProvider",
 "provider_name":"陆地自定义战斗",
 "active_state":"TaleWorlds.MountAndBlade.GameLoadingState",
 "top_screen":"TaleWorlds.MountAndBlade.View.Screens.GameLoadingScreen"}
```

无异常。随后状态自然演进：

```json
{"activeGameState":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattleState",
 "topScreenType":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattleScreen",
 "transitions":"0s <null> | 3s GauntletInitialScreen | 30s GameLoadingScreen | 31s CustomBattleScreen"}
```

**第 2 步** 反射取 screen 的 `CustomBattleVM`（字段 `_dataSource`）并 `Invoke("ExecuteStart")`：

```json
{"status":"ok","invoked":"ExecuteStart","vm_field":"_dataSource",
 "top_screen_after":"TaleWorlds.MountAndBlade.View.Screens.MissionScreen"}
```

**判定：成功。** `top_screen_after = MissionScreen` —— 战斗已开始。

---

## Mission 状态与双方 Formation

```json
{"mission_name":"battle_terrain_biome_096","mission_running":true,"mission_time":"9.754"}
```

Formation（mission_time=17.329）：

| Team | Side | 阵型数 | 兵种 | 人数 |
|---|---|---|---|---|
| 0 | Defender | 4 | Infantry 24 / Ranged 25 / Cavalry 26 / HorseArcher 25 | 100 |
| 1 | Attacker | 5 | Infantry 20 / Ranged 25 / Cavalry 13 / HorseArcher 25 / Cavalry 12 | 95 |

断言器：

```text
teams reported: 2
team side=Defender team_id=0 formations=4 nonEmpty=4
team side=Attacker team_id=1 formations=5 nonEmpty=5
PASS: 2 sides with non-empty formations
      team fields + formation fields all present
EXIT=0
```

注意：这次玩家方 `is_ai_controlled=false`、敌方 `true`，且双方阵型命令不同
（Defender `StandYourGround`，Attacker 部分 `Move`）—— 数据有区分度，不是复制品。

结束 Mission：

```json
cbath/end_mission  -> {"status":"ok"}
cbath/get_mission_state -> {"mission_running":false}
```

---

## P1-004 验收对照

| 判据 | 状态 |
|---|---|
| 创建固定 Mission | ✅ provider + ExecuteStart |
| 确认 MissionRunning | ✅ `mission_running=true`，基于真实状态检查而非 sleep |
| 调 Formation Snapshot 得双方数据 | ✅ 2 队 9 个非空阵型 |
| 正常结束 Mission | ✅ `end_mission` → `mission_running=false` |
| 整个过程无用户点击 | ✅ 全程经 DSH MCP 调用 |

---

## 过程中的环境问题（已解决）

1. **模块集必须含 CustomBattle**：`Native+CBATH` 无法进战斗。
   现为 `Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*CBATH`。
2. **"Mod change detected"** 一次性对话框（改模块集后）：Enter 确认，之后不再出现。
3. **"Unable to initialize Steam API"**：Steam 进程刚起但 API 未就绪。等待 Steam 完全初始化后重试成功。
4. **主 DLL 文件锁**：杀掉游戏后 `CombatBrainAutonomousTestHarness.dll` 持续被锁（僵尸 PID 3632，
   `HasExited=true` 但句柄未释放），`taskkill` 也报"no running instance"。
   - `build-deploy.ps1` 的进程检测改为忽略 `HasExited=true`（它已不持有文件，不是弱化安全）
   - 临时用备用文件名 `CBATH.h3.dll` / `CBATH.h3b.dll` 部署完成实验
   - 锁释放后已恢复标准部署，备用文件已删除，`SubModule.xml` 指回标准名

---

## 保留的技术债

- `ExecuteStart` 是通过反射取私有字段 `_dataSource` 调用的，脆弱（UI 重构即失效）。
  若后续要长期依赖，需要寻找 provider 侧是否有不需要反射的启动入口。
- 本次战斗配置来自 CustomBattle 屏幕的**默认配置**（而非我们指定的兵力/地图）。
  若 P1-005 要求"固定"场景，需要验证默认配置是否每次一致，或找到设置配置的入口。

## 证据文件

- `evidence/p1-004-custombattle-api.txt` — CustomBattle 的 Mission 相关 API 清单
- `evidence/p1-004-custombattledata-members.txt` — CustomBattleData 成员
- `evidence/p1-004-formations-autonomous.json` — 无人值守进入后取得的双方 Formation
- `evidence/p1-004-warning-dialog.png` — Steam API 未就绪时的警告对话框
