# P2-010 步骤 1：两个新工具的单体验证（运行期证据）

日期：2026-09-25
CBATH build_id：`b20260925-013209-2b52d28b`
game version：`v1.4.8.119303`

## 0. 红/绿（缺失行为 → 存在行为）

对**已部署** DLL 做工具名字符串断言（ASCII 编码）：

| 阶段 | cbath/auto_finish_deployment | cbath/delegate_team_to_ai |
|---|---|---|
| 红（部署前 `b20260925-002732-a6df5e05`，sha256 `c1603acc...`） | absent | absent |
| 绿（部署后 `b20260925-013209-2b52d28b`，sha256 `93f6e154...`） | present | present |

> 注：首轮我用 UTF-16 对齐查找，两个既有工具（`cbath/ping`）也返回 absent，
> 证明是**检查方法**错误而非代码问题；改用 ASCII 后既有工具与新工具全部 present。

## 1. 运行时身份（`cbath/get_build_identity`）

```json
{"build_id":"b20260925-013209-2b52d28b",
 "assembly_sha256":"93f6e154b6b92f38ce1ab642e64f15a7366cf7b93fdfc75ff0ee949c95dfe91b",
 "mvid":"e9f98865-06a7-47d8-ab7d-585cb445904a",
 "game_version":"v1.4.8.119303",
 "pid":39144,
 "active_modules":"Bannerlord.Harmony,Bannerlord.ButterLib,Bannerlord.UIExtenderEx,Bannerlord.MBOptionScreen,Native,SandBoxCore,Sandbox,StoryMode,CustomBattle,CombatBrain,CombatBrainAutonomousTestHarness"}
```

- 部署 sha256 与运行时自读 sha256 **一致**（`93f6e154...`）
- GABS 工具数：13 → **15**（`Re-synced 15 tools`）
- `games_tool_names` 可查到 `bannerlord148_cbath_auto_finish_deployment`

## 2. 负路径（无 mission）

| 工具 | 返回 |
|---|---|
| `cbath/auto_finish_deployment` | `{"status":"no_mission"}` |
| `cbath/delegate_team_to_ai` | `{"status":"no_mission"}` |

两者均**未抛异常**，符合契约。

## 3. `cbath/auto_finish_deployment` — PASS

调用时 mission_time ≈ 17.3s（`ExecuteStart` 后进入 MissionScreen）：

```json
{"before":{"allow_ai_ticking":false,"mission_time":"17.324","player_team_formations":8,"team_setup_over":true},
 "after":{"allow_ai_ticking":true,"mission_time":"17.324","player_team_formations":8,"team_setup_over":true},
 "status":"ok"}
```

断言结果：

| 断言 | 结果 |
|---|---|
| status == "ok"（找到 controller 且就绪） | ✅ |
| `before.team_setup_over == true`（就绪条件成立） | ✅ |
| `before.allow_ai_ticking == false`（部署期被 AfterStart 置 false，符合 P2-009 IL） | ✅ |
| **`after.allow_ai_ticking == true`（P2-009 IL 预测的 FinishDeployment 直接效果）** | ✅ |

这是**真实的 false→true 状态转换**，不是"工具返回 ok"的同义反复。

未观测到 `not_ready`：本次轮询到调用时场景已加载完成（17.3s），`TeamSetupOver` 已为 true。
`not_ready` 分支由代码路径覆盖，未在运行期触发。

## 4. `cbath/delegate_team_to_ai` — PASS

```json
{"all_ai_controlled":true,"formation_count":8,"team_index":0,
 "formations":[
  {"formation_index":0,"formation_class":"Infantry","unit_count":24,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":1,"formation_class":"Ranged","unit_count":25,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":2,"formation_class":"Cavalry","unit_count":25,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":3,"formation_class":"HorseArcher","unit_count":25,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":4,"formation_class":"Unset","unit_count":0,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":5,"formation_class":"Unset","unit_count":0,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":6,"formation_class":"Unset","unit_count":0,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""},
  {"formation_index":7,"formation_class":"Unset","unit_count":0,"is_ai_controlled_before":false,"is_ai_controlled_after":true,"error":""}]}
```

断言结果：

| 断言 | 结果 |
|---|---|
| 返回每编队 `before`/`after` 的 is_ai_controlled | ✅ |
| 至少一个 `after == true` | ✅（8/8 true） |
| 4 个有兵编队 false→true（与 P2-007 观测的人工 F6 效果一致） | ✅ |
| 含空编队（index 4-7，unit_count 0）——与 F6 `FormationsIncludingEmpty` 逐字节一致 | ✅ |
| error 全空 | ✅ |

## 5. 真开战判据（P2-007 规则：必须用显式状态）

上述两工具调用后约 68 秒（mission_time 85.4s），`cbath/get_all_formations`：

玩家方（Defender, team 0）：

| Formation | movement_order | arrangement_order | unit_count |
|---|---|---|---|
| f0 Infantry | **Move** | ArrangementLine | 24 |
| f1 Ranged | **Move** | **ArrangementScatter** | 23（**24→23，出现伤亡**） |
| f2 Cavalry | **Charge** | ArrangementLine | 25 |
| f3 HorseArcher | **Charge** | ArrangementLine | 21（**25→21，出现伤亡**） |

- ✅ `movement_order` 出现非 `StandYourGround`（`Move` / `Charge`）
- ✅ `unit_count` 下降（真实伤亡）
- ✅ `arrangement_order` 出现 `ArrangementScatter`
- ✅ 敌军亦在机动，且敌方 Cavalry 25 拆分为 13+12

**结论：真开战已达成**（不是靠 mission_time 增长或 Formation 移动间接猜测）。

## 6. 单体验证阶段：PASS

两个工具均可（a）在无 mission 时安全返回，（b）在真实 mission 中产生可断言的引擎状态转换，
（c）不需要鼠标键盘。
