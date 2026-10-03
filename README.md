# CombatBrain Autonomous Test Harness（CBATH）

让 AI Agent **自主运行、观测、诊断和重复测试**《骑马与砍杀 II：霸主》Mod 的测试基础设施。

它替代的是这条人工链路：

```text
修改代码 → 编译 → 启动游戏 → 人工进入战斗 → 人工观察 → 人工描述问题 → Agent 再修改
```

目标形态是**零人工介入**的闭环：启动游戏 → 无 UI 操作进入战斗 → 引擎侧采样 → 采集证据 → 按硬判据自动判定 PASS/FAIL → 退出并清理。

本仓库是独立项目，与 [`Bannerlord-CombatBrain`](https://github.com/Lzq061122/Bannerlord-CombatBrain) **无源码依赖**：108 个跟踪文件中引用该仓库路径的数量为 0。CombatBrain 在这里只是**被观测的载荷**，CBATH 核心不得依赖其内部类/枚举/日志格式。

> **状态：FROZEN（2026-09-25）**
> Phase 1 + Phase 2（P2-001~P2-010）验收完成，Zero-touch 3/3 PASS，baseline 冻结，**不再新增功能**。
> 后续改动改为**需求驱动**：仅当 CombatBrain 2.0 出现现有观测能力无法验证的具体行为时，才重新打开对应能力建设。
> 收口依据见 [`16-Phase2-Freeze-CBATH-Baseline.md`](RD/CombatBrain-Autonomous-Test-Harness/16-Phase2-Freeze-CBATH-Baseline.md)。

---

## 仓库结构

| 目录 / 文件 | 文件数 | 内容 |
|---|---|---|
| `RD/` | 39 | 研究、架构设计与交接文档。`00-Executive-Summary.md` 是 Phase 0 结论，`16-Phase2-Freeze-CBATH-Baseline.md` 是当前权威基线 |
| `RD/…/evidence/` | 14 + 10 | 运行证据。`runs/` 下是每轮的 `run-<ts>-*.json` |
| `RD/…/experiments/` | 25 | 三个 API 探针工程 + **test-mod 主体** |
| `tools/` | 18 | 编排脚本（12 个 `.ps1`）、MCP 请求样本、`dump-api` 探针 |
| `gabs-config/config.json` | 1 | GABS 游戏定义（`bannerlord148`）与启动参数 |
| `.dsh/dshmm/mcp.json` | 1 | DeepSeek Harness 的 GABS MCP 服务器配置 |

### Test Mod（`RD/CombatBrain-Autonomous-Test-Harness/experiments/test-mod/CBATH/`）

游戏内载荷，10 个手写 `.cs` + 1 个构建期生成的 `BuildIdentity.g.cs`：

| 文件 | 职责 |
|---|---|
| `ProbeSubModule.cs` | 子模块入口 + 启动 GABP server |
| `CbathTools.cs` | 15 个 GABP 工具的注册入口 |
| `MissionControl.cs` | 进入/结束 mission、环境探针（H1/H3/CustomBattle 路线） |
| `AutoDeployControl.cs` | 无 UI 结束部署、把编队交 AI |
| `SamplingMissionBehavior.cs` | 引擎侧 1 Hz 采样 |
| `RunRecord.cs` | 采样结果内存记录 |
| `FormationProbe.cs` | 编队快照 |
| `ScreenProbe.cs` | 屏幕/游戏状态 |
| `RuntimeIdentity.cs` | 运行时身份（build_id / SHA256 / MVID） |
| `MainThreadDispatcher.cs` | 主线程分发 |
| `BuildIdentity.g.cs` | **构建期生成，不跟踪**（`.gitignore:10`） |

### GABP 工具（`cbath/*`）

```text
cbath/ping                      存活探针 + build_id
cbath/get_build_identity        完整运行时身份
cbath/get_game_state            当前 GameState / 顶层屏幕 / mission 类型
cbath/get_all_formations        双方所有非空 Formation（位置/朝向/三类当前命令）
cbath/get_mission_state         mission_running 等真实状态判据
cbath/end_mission               结束当前 mission
cbath/probe_mission_env         mission 创建所依赖的全局对象（诊断用）
cbath/start_fixed_mission       打开固定战斗 mission
cbath/push_custombattle_state   推入 CustomBattle 状态（诊断用）
cbath/h1_create_game_then_push  H1 实验路线（诊断用）
cbath/h3_provider_start         H3 路线一：由 CustomBattle provider 自启战斗
cbath/h3_start_from_screen      H3 路线二：在 CustomBattle 屏上调用 ExecuteStart
cbath/get_last_run              最近一轮完整的 1 Hz Formation 时间序列
cbath/auto_finish_deployment    无 UI 结束部署（轮询到 TeamSetupOver 后 status=ok）
cbath/delegate_team_to_ai       把玩家队全部编队交引擎 AI（等价 F6，但不按键）
```

---

## 运行

### 环境要求

| 项 | 值 |
|---|---|
| 游戏 | Bannerlord **v1.4.8.119303**（Steam buildid `24573425`） |
| 游戏目录 | `E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord` |
| .NET SDK | 编译 test mod（目标框架 `net472`） |
| Go | 构建 GABS（`_source-cache/gabs`） |
| Steam | **必须在运行且 API 已就绪**，否则游戏弹 `Unable to initialize Steam API` 并退出 |

### 路径依赖（重要）

**脚本硬编码本仓库的绝对路径。** 8 个脚本共 17 处引用 `E:\MBmod\CombatBrain Autonomous test harness`：

`tools/invoke-gabs-mcp.ps1`(2) `tools/mcp-http.ps1`(2) `tools/mcp-session.ps1`(2) `tools/run-lifecycle.ps1`(3)
`tools/sample-startup-v2.ps1`(3) `tools/test-p1-003.ps1`(1) `tools/test-p1-004.ps1`(1) `tools/zero-touch-3x.ps1`(3)

**移动本目录会使这些脚本失效。** `build-deploy.ps1` 例外 —— 它用 `Split-Path -Parent $MyInvocation.MyCommand.Path` 相对定位自身，仅 `-GameDir` 有默认值且可覆盖。

### 未跟踪的大目录

| 目录 | 体积 | 说明 |
|---|---|---|
| `_source-cache/` | 195.2 MB / 18,498 文件 | GABS 源码与 `gabs.exe`(13,435,904 B)，**含 6 个嵌套 Git 仓库**。CBATH 只依赖其中的 `gabs.exe` |
| `_intro-video-backup/` | 21.5 MB / 3 文件 | 开场动画原件备份（移走后 30s → 3s） |
| `_intro-video-hidden/` | 21.5 MB / 3 文件 | 被移走的动画文件。**Steam 校验完整性会恢复，动画重现属预期，不算失败** |

### 构建与部署

```powershell
# 生成唯一 build_id → 编译 → 校验 stamp 已进 DLL → 部署 → 双向 SHA256 比对
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "RD\CombatBrain-Autonomous-Test-Harness\experiments\test-mod\CBATH\build-deploy.ps1"
```

部署到 `Modules\CombatBrainAutonomousTestHarness\`（`SubModule.xml` 由脚本生成，`Id = CombatBrainAutonomousTestHarness`，入口类 `CombatBrainAutonomousTestHarness.ProbeSubModule`）。

### Zero-touch 验收

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tools\zero-touch-3x.ps1" -Rounds 3 -CombatHoldSec 180
```

15 步标准流程（预检 → `games_start` → `games_connect` → 轮询 ping → 校验身份 → 进战斗 → 结束部署 → 交 AI → 战斗窗口 → 结束 → 计数 telemetry → 退出 → 归档），详见冻结基线文档 §四。

**每轮 8 条硬判据**，任一不满足即该轮 FAIL；3/3 全 PASS 则整体 PASS，失败重试最多 2 次：

| # | 判据 | 阈值 |
|---|---|---|
| 1 | 进入 Mission | `mission_running=true` |
| 2 | 部署确实结束 | `auto_finish_deployment status=ok` 且 `after.allow_ai_ticking=true` |
| 3 | 真开战 | `movement_order` 出现非 `StandYourGround` |
| 4 | 真实动态变化 | 至少一个 Formation `unit_count` 下降（伤亡） |
| 5 | CombatBrain telemetry | 本轮 offset 增量 `RouteAEvent ≥ 10` |
| 6 | CBATH 连续采样 | `sample_count ≥ 40` |
| 7 | 未触碰鼠标键盘 | 源码 + 脚本扫码 Win32 输入 API 命中 = 0 |
| 8 | 无残留进程 | Bannerlord / Bannerlord.Native 存活进程数 = 0 |

### 当前权威 build 身份

| 项 | 值 |
|---|---|
| build_id | `b20260925-013209-2b52d28b` |
| MVID | `e9f98865-06a7-47d8-ab7d-585cb445904a` |
| 部署 DLL SHA256 | `93f6e154b6b92f38ce1ab642e64f15a7366cf7b93fdfc75ff0ee949c95dfe91b` |
| 部署 DLL mtime | 2026-09-25 01:32:13 |
| 权威批次 | `zero-touch-20260925-024918`（PASS 3/3，三轮首次尝试、零重试） |

---

## 环境操作要点（踩过的坑，务必遵守）

1. **启动游戏前必须 `safely_exited = 1`**（`Documents\Mount and Blade II Bannerlord\Configs\engine_config.txt`）。为 0 会弹 Safe Mode 对话框**静默阻断所有 Mod 加载**（进程活着、零日志，极易误判为编译错误）。强杀游戏后会写回 0，每次启动前都要复位。
2. **框架模块必须排在 Native 之前**（P2-003 根因）。顺序错误表现为「崩溃」：全线程 Suspended、零日志、崩溃框由 `csrss.exe` 承载。
   ```text
   Bannerlord.Harmony → Bannerlord.ButterLib → Bannerlord.UIExtenderEx → Bannerlord.MBOptionScreen
   → Native → SandBoxCore → Sandbox → StoryMode → CustomBattle
   → CombatBrain → CombatBrainAutonomousTestHarness
   ```
3. **`MissionScreen entered ≠ battle started`**：`ExecuteStart` 只到部署界面，兵力全满、部队不动，必须再走结束部署 + 交 AI。
4. **不能用单一 `Formation.CurrentPosition` 判断模拟推进** —— 它是锚点，可长时间不动。用多动态量联合判据。
5. **GABS 有运行时所有权（runtime claim）机制**：`games_start` 与后续所有 `games_call_tool` 必须由**同一个** gabs 进程完成，否则被拒绝。
6. **GABS 工具列表是 connect 时快照**：部署新 DLL 后必须重新 `games_connect`，否则一直报 `not found`。
7. **不要在 `games_start` 之后改 `.dsh/dshmm/mcp.json`** —— 会触发 DSH 重载 MCP 服务器，杀掉 gabs 及其启动的游戏。
8. **强杀游戏后主 DLL 可能被僵尸进程锁定**（`HasExited=true` 但句柄不释放，`taskkill` 报 "no running instance"）。`build-deploy.ps1` 已改为忽略 `HasExited=true` 的进程。

---

## 已知限制与明确未验证项

1. `not_ready` / `no_deployment_controller` 分支未实机覆盖 —— 记为技术债，**不主动制造异常场景**。
2. 战斗配置非显式指定，沿用 CustomBattle 默认；更早观测到兵力不一致，未定论。
3. `closest_enemy_formation_index` 无稳定 ID（引擎不暴露 `FormationIndex`），输出 `unavailable:no_stable_formation_id`。**不建稳定 ID 系统**。
4. **21.7% correlation mismatch 未解释**（P2-007：129 次变化中 28 次无对应命令），已决定暂不研究。
5. 采样频率固定 1 Hz；只在证明 1 Hz 不够时才引入 5 Hz。
6. `ExecuteStart` 靠**反射取私有字段** `_dataSource`，UI 重构即失效。
7. `c7` 扫描范围仅 CBATH 源树 + 本脚本，不覆盖 `tools/` 下本批未调用的其它脚本。
8. `tools/sample-startup*.ps1` 含 `PostMessage` 按键注入，是早期遗留，**Zero-touch 从不调用**。
9. zombie 进程残留：多次强杀会留 `HasExited=true` 僵尸条目，已验证不锁 DLL、不占 CPU，属外观残留。

---

## 四条硬性边界（不可违反）

1. **`MissionScreen entered ≠ battle started`** —— 见环境要点 3。
2. **不用单一 `Formation.CurrentPosition` 判断模拟推进** —— 见环境要点 4。
3. **correlation ≠ attribution** —— 只建立「命令与状态变化能放同一时间轴」，**不证明因果**（P2-007）。
4. **CBATH 核心不得依赖 CombatBrain 内部实现** —— 核心零 CombatBrain 引用；读取 CombatBrain 日志仅通过两个独立 legacy adapter（`tools/cb-legacy-offset2mission.ps1`、`tools/cb-correlate.ps1`，文件头标注 `TEMPORARY, DELETE-ABLE, NOT PART OF CBATH`）。

---

## 文档入口

从 [`00-Executive-Summary.md`](RD/CombatBrain-Autonomous-Test-Harness/00-Executive-Summary.md)（Phase 0 研究结论与证据等级表）开始，再到 [`16-Phase2-Freeze-CBATH-Baseline.md`](RD/CombatBrain-Autonomous-Test-Harness/16-Phase2-Freeze-CBATH-Baseline.md)（当前权威基线与验收判据）。

`evidence/` 下每份文档对应一个阶段的结论，`08-Phase1-MVP.md` 定义 P1-001~P1-006 的验收标准。

**证据等级约定**（贯穿全部文档）：`VERIFIED AT RUNTIME` / `VERIFIED BY BUILD ONLY` / `[CODE]` / `[DOC]` / `[RUN]` / `[UNKNOWN]` / `NOT TESTED` / `FAILED`。

> 任何 "READY / GO" 必须有真实游戏运行证据。**不得**把「编译通过」「工具列存在」「进程存在」「一次成功」当作完整闭环证据。

---

## 分支

| 分支 | 说明 |
|---|---|
| `main` | 主开发线（2026-10-04 由 `master` 改名，内容未变） |
