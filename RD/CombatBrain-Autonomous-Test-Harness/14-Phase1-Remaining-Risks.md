# 14 — Phase 1 Remaining Risks
## CBATH Phase 1 剩余风险与技术债

日期：2026-09-24
状态：Phase 1 已完成（P1-001 ~ P1-005 全部 PASS）

本文档如实列出 Phase 1 结束时**尚未解决**的问题。任何在此列出的项都**不构成 Phase 1 的验收失败**，
但会在 Phase 2 或长期使用中造成影响，需要在后续工作中处理。

---

## 一、风险等级汇总

| # | 风险 | 等级 | 影响范围 | 是否已缓解 |
|---|---|---|---|---|
| R1 | `ExecuteStart` 依赖反射私有字段 | **高** | 游戏更新即失效 | 否 |
| R2 | 依赖 Steam 主进程存活（静默失败） | **高** | 自动化流程中断 | 部分（已定位根因） |
| R3 | HTTP 编排脚本不可用（claim 冲突） | **中** | 无法全自动一键跑 N 轮 | 是（改用 Agent 直驱） |
| R4 | 战斗配置非显式指定 | **中** | "固定 Mission" 语义不严格 | 否 |
| R5 | `safely_exited` 需每轮复位 | **中** | Safe Mode 静默阻断 Mod | 是（已固化动作） |
| R6 | GABS 工具列表为 connect 时快照 | **中** | 部署新 DLL 后报 not found | 是（重新 connect） |
| R7 | 主 DLL 文件锁（僵尸进程） | **中** | 部署失败 | 部分 |
| R8 | `git_commit` 未注入 build identity | **低** | 溯源不完整 | 否 |
| R9 | GABS 二进制无版本 ldflags | **低** | 版本不可追溯 | 否 |
| R10 | 开场动画文件可能被 Steam 校验恢复 | **低** | 启动变慢 30s | 是（可重新移走） |
| R11 | 长时间稳定性未验证 | **中** | 未知 | 否 |

---

## 二、详细说明

### R1 — `ExecuteStart` 依赖反射私有字段 【高】

**现状**：进入 Mission 的第 2 步通过反射获取 `CustomBattleScreen` 的私有字段 `_dataSource`
（类型 `CustomBattleVM`），再 `Invoke("ExecuteStart")` 调用。

```json
{"invoked":"ExecuteStart","vm_field":"_dataSource",
 "top_screen_after":"TaleWorlds.MountAndBlade.View.Screens.MissionScreen"}
```

**风险**：字段名或类型一旦在游戏更新中改变，反射会抛 `NullReferenceException` 或
`MissingFieldException`，整条自动进入路线立即失效。这是 Phase 1 中**最脆弱的一环**。

**为何未解决**：P1-004 已实测多条无需反射的候选路线，全部失败（NRE）：

| 路线 | 结果 |
|---|---|
| `CPUBenchmarkMissionLogic.OpenCPUBenchmarkMission(scene)` | FAILED（NRE） |
| `GameStateManager.PushState(CreateState<CustomBattleState>())` | FAILED（NRE） |
| `Game.CreateGame(new CustomGame(), new CustomGameManager())` + PushState | FAILED（NRE，且异常更深一层） |
| `CustomBattleHelper.StartGame(CustomBattleData)` | FAILED（NRE，`CustomBattleData.get_Factions`） |

**建议**：寻找 provider 侧无需反射的启动入口，或在反射外层增加字段存在性检查与明确的失败诊断
（而非直接 NRE）。

---

### R2 — 依赖 Steam 主进程存活，且失败表现为静默 【高】

**现状**：P1-005 轮 3 的前两次尝试均因此失败。关键在于**失败是静默的**：

- 进程存活、`Responding=True`
- CPU 仅 9.28s、内存仅 61.4MB（远低于正常加载后的量级）
- 无任何新日志（`Logs\` 最新为 2026-08-31，`launch.log` 为 0 字节）
- Windows 事件日志中无 Error/Warning

**极易误判为**"编译错误"或"Mod 加载失败"。实际根因是 `steam.exe` 不在运行——
而 `Get-Process -Name 'steam'` 会因名称前缀匹配命中 `steamwebhelper.exe` 而返回非零计数，
**掩盖了真相**。

**建议**：
1. 自动化流程启动游戏前，用精确匹配核查 `steam.exe`：
   `(Get-Process -Name 'steam' -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'steam'}).Count`
2. 增加"GABP bridge 未就绪 + 进程 CPU/内存异常低"的组合判据，提前报警而非静默重试。

---

### R3 — HTTP 编排脚本不可用 【中，已缓解】

**现状**：`tools\run-lifecycle.ps1` 的编排逻辑已完成，但**从未跑通过**。
根因是 GABS 的 runtime claim 机制：

```text
Game 'bannerlord148' is already owned by another active GABS session (pid NNNNN).
Skipping games_connect here to avoid competing...
```

脚本另起一个 gabs（HTTP 模式）会与 DSH 自身持有的 gabs 会话争抢同一个 game id。

**缓解措施**：P1-005 改用 DSH Agent 通过官方 `mcp__gabs__*` 工具单实例直驱，3 轮全部成功。
该形态同时天然满足 P1-002 的 AC9。

**遗留**：无法通过一条命令自动跑 N 轮。若 Phase 2 需要大批量重复实验，需重新设计编排方案
（例如让脚本本身成为唯一 gabs 持有者，或由 GABS 侧提供多客户端支持）。

---

### R4 — 战斗配置非显式指定 【中】

**现状**：三轮生命周期使用的兵力/地图来自 **CustomBattle 屏幕的默认配置**，而非我们显式设定。

**实测数据**：本轮三轮的编制结构实际上**一致**：

| 轮次 | Defender | Attacker |
|---|---|---|
| r1 | 4 阵 24/25/26/25 = 100 | 5 阵 20/25/13/25/12 = 95 |
| r2 | 4 阵 24/25/26/25 = 100 | 5 阵 20/25/13/25/12 = 95 |
| r3 | 4 阵 24/25/26/25 = 100 | 5 阵 20/25/13/25/12 = 95 |

但交接文档记录了更早期的两次观测**互不一致**：

- 一次为 98/90 单一兵种
- 一次为 4 阵 100 人 / 5 阵 95 人

**结论**：默认配置**是否稳定尚未确定**。本轮 3 次一致不足以证明其确定性（样本太小，
且可能受此前 CustomBattle 屏幕上的遗留交互状态影响）。

**用户已明确**：战斗配置不同不影响 P1-005 验收，只要求能进入 Mission 并读取 Formation。

**建议**：若 Phase 2 需要可复现的确定性场景，必须找到显式设置 `CustomBattleData`
（兵力/地图/兵种）的入口，不能依赖默认值。

---

### R5 — `safely_exited` 需每轮复位 【中，已固化】

**现状**：`engine_config.txt` 中 `safely_exited = 0` 会触发 **Safe Mode 对话框**，
**静默阻断所有 Mod 加载**（进程活着、无任何日志）。

强杀游戏后游戏会写回 0，因此**每次启动前都必须复位为 1**。

**缓解**：`build-deploy.ps1` 已内置该动作；本轮 P1-005 每轮启动前也手工核查。
本轮三轮启动前该值均为 1。

**建议**：任何绕过 `build-deploy.ps1` 的启动路径都必须自带此复位动作。

---

### R6 — GABS 工具列表是 connect 时快照 【中，已缓解】

**现状**：部署新 DLL 后若未重新 `games_connect`，对新工具会一直报 `not found`。

**缓解**：本轮每轮都执行了 `games_connect`，返回 `Re-synced 12 tools`。

```text
mcp__gabs__games_connect → "Already connected to 'bannerlord148'. Re-synced 12 tools."
```

**建议**：把"部署后必须 reconnect"写入任何自动化流程。

---

### R7 — 主 DLL 文件锁（僵尸进程） 【中，部分缓解】

**现状**：强杀游戏后 `CombatBrainAutonomousTestHarness.dll` 可能被僵尸进程持续锁定
（`HasExited=true` 但句柄不释放，`taskkill` 报 "no running instance"）。

**缓解**：`build-deploy.ps1` 已改为忽略 `HasExited=true` 的进程。
本轮未遇到该问题（三轮 `games_stop` 均正常，cleanup 残留均为 0）。

**建议**：若再次遇到，应急方案为使用备用 DLL 名 + 修改 `SubModule.xml` 的 `DLLName`，
事后务必恢复。

---

### R8 — `git_commit` 未注入 build identity 【低】

**现状**：build identity 含 `build_id`、`build_timestamp`、`assembly_sha256`、`mvid`，
但**不含 git commit**，因为工作区不在 git 仓库中。

**影响**：无法从运行时身份直接追溯到源代码版本。当前依赖 `build_id`
（形如 `b20260924-171754-2eeefc21`，含时间戳 + 内容哈希）作为替代溯源手段。

**建议**：若后续纳入版本控制，把 commit 一并写入 identity。

---

### R9 — GABS 二进制无版本 ldflags 【低】

**现状**：GABS 二进制未走 `make build`（Makefile 依赖 GNU sed/rm，本机不可用），
因此 version/commit 的 ldflags 未注入。

**影响**：GABS 二进制自身的版本不可从程序内查询。当前以源码来源 + 构建记录替代。

**环境备注**：构建 GABS 需 `GOPROXY=https://goproxy.cn,direct` + `GOSUMDB=off`（本机 TLS 校验问题）。

---

### R10 — 开场动画文件可能被 Steam 校验恢复 【低，已缓解】

**现状**：开场动画已通过移走视频文件消除（启动 30s → 3s）：

```text
Modules\Native\Videos\TWLogo_and_Partners.{mp4,ivf,ogg}
  → _intro-video-hidden\
原件备份 → _intro-video-backup\
```

**风险**：Steam 校验游戏完整性会恢复这些文件，动画重现。

**影响**：启动变慢约 30 秒，**不影响功能正确性**，不算失败。重新移走即可。

---

### R11 — 长时间稳定性未验证 【中】

**现状**：P1-005 只跑了 3 轮连续生命周期，总时长约 17 分钟。

**未验证**：
- 连续运行 10+ 轮是否有内存/句柄泄漏
- 长时间运行后 GABS bridge 是否稳定
- Mission 反复进出是否有累积状态污染
- 多轮后 DLL 文件锁问题是否复现

**建议**：在依赖该 harness 做大批量实验前，先做一次 N≥10 轮的稳定性测试。

---

## 三、明确不在 Phase 1 范围内的事项

以下事项**不是**遗留缺陷，而是被明确排除的范围（prompt 严格边界）：

- Phase 2 / CombatBrain 集成 / Telemetry / Evaluator / Scenario 框架
- 修改 CombatBrain 2.0 主工程
- 移植全量 Bannerlord.GABS 到 v1.4.8
- 引入第三方 mod
- 解决双 gabs 实例的 claim 协调问题

---

## 四、Phase 2 启动前建议

按优先级排序：

1. **先解决 R2（Steam 存活性检查）** —— 这是最容易造成"看起来失败但其实是环境问题"的坑，
   成本极低（一条精确匹配的进程检查）。
2. **评估 R1（反射脆弱性）** —— 若 Phase 2 需要长期依赖自动进入 Mission，
   反射方案必须加固或替换；若只是短期验证则可接受。
3. **决定 R4（战斗配置是否需要显式指定）** —— 这直接决定 Phase 2 能否做可复现的对照实验。
4. **若需要批量自动化，重新设计 R3 的编排方案** —— 单实例直驱适合小批量验证，
   不适合无人值守的大批量实验。
5. **补一次 R11 稳定性测试** —— 在做长周期实验前摸底。

---

## 五、相关文档

- `12-Phase1-Implementation-Report.md` — Phase 1 实现报告与验收对照
- `13-Phase1-Runtime-Evidence.md` — 运行时原始证据
- `evidence\runs\*-FAILED.json` — 失败尝试的如实存档
