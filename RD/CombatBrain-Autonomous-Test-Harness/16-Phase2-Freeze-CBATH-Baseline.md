# 16-Phase2-Freeze — CBATH Baseline 收口（P2 阶段冻结）

日期：2026-09-25
状态：**FROZEN**（本阶段验收已完成，CBATH 不再新增功能）

> 本文档是 P2（Phase 2）的收口与交接依据。**后续 CBATH 任何改动必须需求驱动**：
> 只有 CombatBrain 2.0 开发中出现现有观测能力无法验证的具体行为时，才重新打开对应能力建设。
> 下一主线切回 CombatBrain 2.0。

---

## 一、当前已 VERIFIED AT RUNTIME 的能力

以下能力均以真实游戏运行证据闭环，**不是**「编译通过 / 工具存在 / 一次成功」。

| # | 能力 | 运行证据 |
|---|---|---|
| 1 | 无 UI 交互进入自定义战斗 | P2-010（`h3_provider_start → CustomBattleScreen → ExecuteStart`） |
| 2 | 无 UI 交互结束部署 | `cbath/auto_finish_deployment`：`Mission.AllowAiTicking` 实测 **false→true**（P2-009 IL 预测的运行期确认） |
| 3 | 无 F6 按键把编队交 AI | `cbath/delegate_team_to_ai`：8/8 编队（含 4 空编队）`IsAIControlled` 实测 **false→true** |
| 4 | 引擎 1 Hz 采样 | `get_last_run`：三轮 66/57/46 采样点，样本数≈窗口秒数（1 Hz 成立） |
| 5 | 真实交战观测 | `movement_order` 出现 `Move/Charge`；`unit_count` 194→193（伤亡）；`ArrangementScatter` |
| 6 | CombatBrain telemetry 持续产生 | 三轮 RouteAEvent 150/131/109（offset 增量计数） |
| 7 | 无残留进程 | 三轮 `cleanup=clean`，结束时 Bannerlord 进程数 0 |
| 8 | 无鼠标键盘输入 | `c7` 实扫描 CBATH 源树命中 0（含 fallback 判断） |

**权威批次**：`zero-touch-20260925-024918`（PASS 3/3，三轮首次尝试、零重试）

| 轮次 | run_id | c2 aiTick | c4a 伤亡 | c5 RouteA | c6 samples | c7 hits | 窗口 |
|---|---|---|---|---|---|---|---|
| 1 | `zt-r1-a1-20260925-024918` | true | true | 150 | 66 | 0 | 65s |
| 2 | `zt-r2-a1-20260925-025057` | true | true | 131 | 57 | 0 | 55s |
| 3 | `zt-r3-a1-20260925-025224` | true | true | 109 | 46 | 0 | 45s |

---

## 二、当前权威 build 身份

| 项 | 值 |
|---|---|
| build_id | `b20260925-013209-2b52d28b` |
| MVID | `e9f98865-06a7-47d8-ab7d-585cb445904a` |
| 部署 DLL SHA256 | `93f6e154b6b92f38ce1ab642e64f15a7366cf7b93fdfc75ff0ee949c95dfe91b` |
| 部署 DLL mtime | 2026-09-25 01:32:13 |
| game version | `v1.4.8.119303` |
| 部署路径 | `Modules\CombatBrainAutonomousTestHarness\bin\Win64_Shipping_Client\` |

### 关键脚本 SHA256

| 脚本 | SHA256 |
|---|---|
| `tools\zero-touch-3x.ps1`（权威验收脚本） | `2fd3361b9bd1c12040c8acb0153cdd0f1b79795caeaca219b995da1fa034bf66` |
| `tools\mcp-http.ps1`（MCP over HTTP 编排） | `df1a86cf0719f5b3938f06b29884c327f8ce8ed30b4fc42eb22d6b6c08be33ea` |
| `tools\focus-bannerlord.ps1`（置前台） | `c0570b18a4bddb5f567d4fec51492bb7029a8928c69962a0c30e4dc62fdd018d` |

### CBATH 核心源码（`experiments\test-mod\CBATH\`，11 个 `.cs`）

| 文件 | 职责 |
|---|---|
| `AutoDeployControl.cs` | 两个新工具核心逻辑（P2-010 新增） |
| `CbathTools.cs` | GABP 工具注册入口 |
| `MissionControl.cs` | mission 进入/结束/环境探针（H1/H3/CustomBattle） |
| `SamplingMissionBehavior.cs` | 引擎侧 1 Hz 采样 |
| `FormationProbe.cs` | 编队快照 |
| `ScreenProbe.cs` | 屏幕/游戏状态 |
| `RuntimeIdentity.cs` | 运行时身份 |
| `MainThreadDispatcher.cs` | 主线程分发 |
| `RunRecord.cs` | 采样结果内存记录 |
| `ProbeSubModule.cs` | 子模块入口 + GABP server |
| `BuildIdentity.g.cs` | 构建期生成（每次 build 重写） |

---

## 三、正确模块加载顺序（P2-003 根因，勿改）

```text
/MODULES 顺序（config.json 已固化）：
Bannerlord.Harmony
Bannerlord.ButterLib
Bannerlord.UIExtenderEx
Bannerlord.MBOptionScreen
Native
SandBoxCore
Sandbox
StoryMode
CustomBattle
CombatBrain
CombatBrainAutonomousTestHarness
```

**框架模块（Harmony/ButterLib/UIExtenderEx/MCM）必须排在 Native 之前**，否则模块加载中止
（表现为"崩溃"：全线程 Suspended、零日志、崩溃框由 csrss.exe 承载）。这是 P2-003 定位的根因。

---

## 四、Zero-touch 标准执行流程

```text
1. 环境预检：
   - safely_exited = 1（先杀进程 → 再复位，顺序不可反）
   - steam 精确匹配 ProcessName -eq 'steam'（防 steamwebhelper 误报）
   - 无 Bannerlord / Bannerlord.Native 存活进程
   - 删除 Documents\CommandBrainATH（重建 CBATH 桥信息）
2. games_start（bannerlord148，DirectPath）
3. games_connect（forceTakeover=true —— 本批自起 gabs 需接管，否则工具快照为空）
4. 轮询 cbath/ping 直到 pong=true（等 CBATH GABP 桥就绪）
5. cbath/get_build_identity（校验 build_id / MVID / assembly_sha256）
6. 轮询 cbath/get_game_state 直到 activeGameState=InitialState（主菜单）
7. cbath/h3_provider_start → 轮询到 CustomBattleScreen
8. cbath/h3_start_from_screen（ExecuteStart）→ 轮询到 mission_running=true
9. 轮询 cbath/auto_finish_deployment 直到 status=ok（部署结束，AllowAiTicking=true）
10. cbath/delegate_team_to_ai（把玩家队编队交 AI，等价 F6）
11. 战斗窗口：轮询直到 unit_count 下降（伤亡），窗口下限 = MinSamples（≥40s），上限 = CombatHoldSec
12. cbath/end_mission → 轮询 cbath/get_last_run（采样已终态）
13. 计数 CombatBrain.log offset 增量 RouteAEvent
14. games_stop → 确认无残留进程
15. 每轮存档 evidence\runs\<run_id>.json，8 条判据全过才 PASS
```

执行入口：`powershell -File tools\zero-touch-3x.ps1 -Rounds 3 -CombatHoldSec 180`

---

## 五、当前有效验收判据（每轮 8 条硬判据，任一不满足即该轮 FAIL）

| # | 判据 | 阈值 |
|---|---|---|
| 1 | 进入 Mission | `mission_running=true` |
| 2 | 部署确实结束 | `auto_finish_deployment status=ok` 且 `after.allow_ai_ticking=true` |
| 3 | 真开战 | `movement_order` 出现非 `StandYourGround`（`Move`/`Charge`） |
| 4 | 真实动态变化 | **至少一个 Formation `unit_count` 下降（伤亡）**。`orders_changed` 仅作辅助证据（c4b），不单独构成通过 |
| 5 | CombatBrain telemetry | 本轮 offset 增量 `RouteAEvent ≥ 10` |
| 6 | CBATH 连续采样 | `sample_count ≥ 40`（与战斗窗口 ≥40s 配套，见 P2-010 §7#9） |
| 7 | 未触碰鼠标键盘 | CBATH 源树 + 脚本扫码 Win32 输入 API 命中 = 0 |
| 8 | 无残留进程 | Bannerlord/Bannerlord.Native 存活进程数 = 0 |

判定单位：轮次；3/3 全 PASS 则整体 PASS。失败重试最多 2 次。

---

## 六、已知限制与明确未验证项

1. **`not_ready` / `no_deployment_controller` 分支未实机覆盖**：运行中 `TeamSetupOver` 均已在轮询后为 true，`no_deployment_controller` 未触发。仅代码路径覆盖，**记为 CBATH 技术债，不主动制造异常场景**。
2. **战斗配置非显式指定**：沿用 CustomBattle 默认。P1-005 三轮兵力一致，但更早观测不一致，未定论。
3. **`closest_enemy_formation_index` 无稳定 ID**：引擎不暴露 `FormationIndex`，输出 `unavailable:no_stable_formation_id`。**不建稳定 ID 系统**。
4. **21.7% correlation mismatch 未解释**（P2-007：129 变化中 28 无对应命令）。用户已决定暂不研究。
5. **采样频率固定 1 Hz**：5 Hz 只在未来证明 1 Hz 不够时才引入。
6. **CombatBrain 是旧版临时测试载荷**：CBATH 不得依赖其内部类/枚举/日志格式。
7. **zombie 进程残留**：多次强杀会留 `HasExited=true` 僵尸条目。已验证**不锁 DLL**、不占 CPU，属外观残留。
8. **`c7` 扫描范围**：仅 CBATH 源树 + 本脚本，不覆盖 `tools\` 下本批未调用的其它脚本。
9. **`tools\sample-startup*.ps1` 含 `PostMessage` 按键注入**：是早期遗留，**本批 Zero-touch 从不调用**，故不违反 c7。

---

## 七、legacy CombatBrain 临时 adapter（可删除，非 CBATH 核心）

只有这两个工具直接读取/关联 CombatBrain 日志，文件头明确标注 `legacy CombatBrain temporary adapter` + `TEMPORARY, DELETE-ABLE, NOT PART OF CBATH`：

| 文件 | 职责 | SHA256 |
|---|---|---|
| `tools\cb-legacy-offset2mission.ps1` | 按 byte offset 读日志**新增部分**，提取 `RouteAEvent` | `96cfe1e6a5a82d8e3eb5648f6630bd11b4f9988f4bfd1e81caabcaf30479e4b3` |
| `tools\cb-correlate.ps1` | 将 CB 事件与 CBATH 时间序列对齐，输出 markdown | `7b9d84ba3a2a5aa926631a64fc56bbc55301961612a86d2728bf45b3fbed2f84` |

> 注意：P2-010 的 telemetry 统计（c5）只读增量条数，**不调用** `cb-legacy-offset2mission.ps1`（它做逐条提取）。c5 由 `zero-touch-3x.ps1` 内置的 `Count-RouteAEvents` 完成。

---

## 八、仅当 CombatBrain 2.0 需求出现后才可扩展的能力

以下能力当前**明确不做**，只有一个触发条件：CombatBrain 2.0 开发中出现现有观测能力无法验证的具体行为。

| 能力 | 现状 | 未来触发点 |
|---|---|---|
| 命令来源归因（attribution） | 只做时间关联（correlation） | CB 2.0 需证明"该状态变化由该命令导致"时 |
| 骑兵包抄 / 具体战术行为测试 | 不做 | CB 2.0 出现需要特定战术观测的行为实现 |
| 提高采样频率 | 固定 1 Hz | 1 Hz 被证明不足以观测 CB 2.0 某行为时（P2-005 约定） |
| 稳定 Formation ID 系统 | 保留 `unavailable` 缺口 | CB 2.0 需要"该命令发给哪个编队"时 |
| 自动开战黑盒入口（`start_battle`） | 保持两个显式动作工具 | 仅在显式动作工具被证明不足时考虑 |
| 完整 CB-014 | 未做 | — |

---

## 九、四条硬性边界（本阶段不可违反）

1. **`MissionScreen entered ≠ battle started`**：`ExecuteStart` 只到部署界面（`重置部署/准备` 仍在、兵力全满）。指挥官模式下无人下令则部队不动。
2. **不能用单一 `Formation.CurrentPosition` 判断模拟推进**：它是锚点，可长时间不动（P2-005 教训）。用多动态量联合判据（`movement_order`/`unit_count`/`active_behavior`/`arrangement_order`）。
3. **correlation ≠ attribution**：只建立"命令与状态变化能放同一时间轴"，不证明因果（P2-007）。
4. **CBATH 核心不得依赖 CombatBrain 内部实现**：CBATH 核心零 CombatBrain 引用（`AutoDeployControl.cs` 仅引 `TaleWorlds.MountAndBlade`；已 grep 验证）。读取 CombatBrain 日志仅通过 §七 的两个独立 legacy adapter。

---

## 十、Phase 2 证据文档索引

`RD\CombatBrain-Autonomous-Test-Harness\evidence\`：

| 文档 | 内容 |
|---|---|
| `P2-001-smoke-failed.md` | smoke 失败（模块集无 CombatBrain → 依赖冲突） |
| `P2-002-control-experiment.md` | 崩溃与 CombatBrain 无关 |
| `P2-003-loadorder-fix.md` | **根因：框架模块必须 Native 前** |
| `P2-004-combatbrain-running.md` | CombatBrain 运行确认 |
| `P2-005-final.md` | 1 Hz 采样（53 点） |
| `P2-006-correlation.md` | 时间基准确认 |
| `P2-007-result.md` | 实时交战关联（129 状态变化 / 1380 命令，78.3%） |
| `P2-008-autodeploy-audit.md` | 自动开战语义审计 |
| `P2-009-param-confirm.md` | `SetControlledByAI` 双参 + `FinishDeployment` 就绪 IL 确认 |
| `P2-010-result.md` | **Zero-touch 3/3 结果（本文档的验收依据）** |
| `P2-010-step1-tool-verification.md` | 两个工具单体验证 |

---

## 十一、冻结声明

- 本阶段（P1 + P2-001~P2-010）**验收完成**，Zero-touch 3/3 PASS，CBATH baseline 冻结。
- **不再新增 CBATH 功能**。
- 后续 CBATH 改动改为**需求驱动**：仅当 CombatBrain 2.0 出现现有能力无法验证的具体行为时，重新打开对应能力建设（§八 表）。
- 下一主线：CombatBrain 2.0。