# 12 — Phase 1 Implementation Report
## CombatBrain Autonomous Test Harness (CBATH) — Phase 1

日期：2026-09-24
工作区：`E:\MBmod\CombatBrain Autonomous test harness`
状态：**Phase 1 完成（P1-001 ~ P1-005 全部 PASS）**

---

## 一、证据分级说明

本报告对每一项结论标注其证据强度，五类含义如下：

| 级别 | 含义 |
|---|---|
| **VERIFIED AT RUNTIME** | 在真实运行的游戏进程中被观测到，有原始工具输出留存 |
| **VERIFIED BY BUILD ONLY** | 仅由编译/部署产物证明，未在运行时观测 |
| **INFERRED** | 由已观测事实推导，未直接观测 |
| **NOT TESTED** | 未做任何验证 |
| **FAILED** | 尝试过并失败 |

---

## 二、Phase 1 总体结论

| 阶段 | 目标 | 结论 | 证据级别 |
|---|---|---|---|
| **P1-001** Runtime Identity | 建立可验证的运行时身份（build_id / SHA256 / MVID / pid） | PASS | VERIFIED AT RUNTIME |
| **P1-002** Ping Bridge | DSH 官方 MCP 客户端接入 GABS，打通游戏侧工具调用 | PASS | VERIFIED AT RUNTIME |
| **P1-003** Formation Snapshot | 读取战斗双方 Formation 快照 | PASS | VERIFIED AT RUNTIME |
| **P1-004** Autonomous Mission | 完全无人值守地进入固定 Mission | PASS | VERIFIED AT RUNTIME |
| **P1-005** Continuous Lifecycle | 连续 3 轮完整生命周期无人介入 | **PASS（3/3）** | VERIFIED AT RUNTIME |

---

## 三、运行时身份（build identity）

本 Phase 全部实验使用同一个已部署的测试 Mod 构建。三轮生命周期中该身份**每一轮都被重新验证**，且磁盘字节与运行时自读哈希逐字节一致：

| 项 | 值 |
|---|---|
| build_id | `b20260924-171754-2eeefc21` |
| build_timestamp | `2026-09-24T09:17:54Z` |
| assembly_sha256（运行时自读） | `c6fbe74c827f0aa1a117296bd96ac0bcded07e59df5ab7dabc0575bc6e4a2ed2` |
| assembly_sha256（磁盘独立计算） | `c6fbe74c827f0aa1a117296bd96ac0bcded07e59df5ab7dabc0575bc6e4a2ed2` |
| MVID | `f826cf4a-dfc8-43ff-89f8-b7d335cbd6bd` |
| game_version | `v1.4.8.119303` |
| active_modules | `Native,SandBoxCore,Sandbox,StoryMode,CustomBattle,CombatBrainAutonomousTestHarness` |
| 磁盘 DLL 大小 | 33792 bytes |

**证据级别：VERIFIED AT RUNTIME。** 磁盘哈希由 PowerShell `Get-FileHash` 独立计算，与游戏内 `Assembly.GetName()` 反射读出的 SHA256 完全一致，排除了"部署了旧 DLL"这一常见误判。

---

## 四、P1-005 连续三轮生命周期

### 4.1 驱动方式（重要说明）

P1-005 **不是**由 `tools\run-lifecycle.ps1` 编排脚本驱动，而是由 DSH Agent 直接通过官方 `mcp__gabs__*` MCP 工具逐轮驱动。原因如下：

GABS 存在**运行时所有权（runtime claim）**机制：一个 gabs 实例启动游戏并持有 claim 后，另一个 gabs 实例调用 `games_connect` 会被拒绝：

```text
Game 'bannerlord148' is already owned by another active GABS session (pid NNNNN).
Skipping games_connect here to avoid competing...
```

前一位 Agent 尝试用脚本另起一个 gabs（HTTP 模式）来编排三轮，在解决端口作用域 bug 后仍失败。根因是**结构性冲突**：脚本起的第二个 gabs 与 DSH 自身持有的 gabs 会话争抢同一个 game id（`bannerlord148`），这与 CBATH 本身的正确性无关，且会引入与验收目标无关的失败源。

因此本轮改用**单实例直驱**：全程只有一个 gabs 进程（DSH MCP 客户端，pid 25640 全程存活）。这一形态同时天然满足 P1-002 的 AC9「全部经 DSH 官方 MCP 客户端」。

原编排脚本 `run-lifecycle.ps1` / `mcp-http.ps1` **未被修改**，保留原样。

### 4.2 三轮结果

| 轮次 | run_id | PID | 进入 Mission | 双方 Formation | Mission 退出 | 游戏退出 | cleanup | 判定 |
|---|---|---|---|---|---|---|---|---|
| 1 | `run-20260924-183714-r1` | 46508 | ✅ `battle_terrain_biome_096` | 4 阵 / 5 阵 | ✅ | ✅ | clean | **PASS** |
| 2 | `run-20260924-184412-r2` | 35608 | ✅ `battle_terrain_biome_096` | 4 阵 / 5 阵 | ✅ | ✅ | clean | **PASS** |
| 3 | `run-20260924-185053-r3` | 37308 | ✅ `battle_terrain_biome_096` | 4 阵 / 5 阵 | ✅ | ✅ | clean | **PASS** |

**连续 PASS 计数：3/3。** 三个 PID 互不相同（46508 / 35608 / 37308），证明每轮都是独立启动的进程，未复用上一轮状态。

### 4.3 每轮的完整状态转换链

三轮的状态演进完全一致：

```text
h3_provider_start   → GameLoadingState / GameLoadingScreen
get_game_state      → CustomBattleState / CustomBattleScreen      (10~12s)
h3_start_from_screen→ CustomBattleScreen → MissionScreen
get_mission_state   → mission_running = true, mission_name = battle_terrain_biome_096
get_all_formations  → teams = 2（Defender 4 阵 / Attacker 5 阵）
end_mission         → status ok
get_mission_state   → mission_running = false
games_stop          → "termination verified. workload pid NNNNN is gone."
```

### 4.4 Formation 数据（三轮一致）

三轮读到的编制结构相同，仅坐标/朝向因战场生成而不同：

| 轮次 | Defender（玩家方，is_ai_controlled=false） | Attacker（AI 方，is_ai_controlled=true） |
|---|---|---|
| r1 | Infantry 24 / Ranged 25 / Cavalry 26 / HorseArcher 25（4 阵，100 人） | Infantry 20 / Ranged 25 / Cavalry 13 / HorseArcher 25 / Cavalry 12（5 阵，95 人） |
| r2 | 同上（4 阵，100 人） | 同上（5 阵，95 人） |
| r3 | 同上（4 阵，100 人） | 同上（5 阵，95 人） |

双方 `is_ai_controlled` 取值相反、阵型命令不同（Defender 全部 `StandYourGround`，Attacker 部分 `Move`），说明数据具备真实区分度，不是复制品或占位符。

**关于"固定 Mission"的准确表述**：三轮进入的是**同一个场景** `battle_terrain_biome_096` 且编制结构一致；但兵力/地图来自 CustomBattle 屏幕的**默认配置**，我们并未显式指定。用户已明确确认"战斗配置不同没问题，能进入并读取 formation 即可"，故此项不作为 P1-005 判据。详见第 14 号文档技术债第 2 条。

### 4.5 失败与重试的如实记录

P1-005 的第 3 轮**经历过 2 次失败尝试**后才成功。这两次失败**已存档、未被隐藏、不计入 3 轮**（连续计数从成功的那次重新开始）：

| 尝试 | run_id | 现象 | 根因 |
|---|---|---|---|
| r3-attempt1 | `run-20260924-184458-r3-attempt1-FAILED` | GABP bridge 未就绪；进程 29444 存活但仅 61.4MB/9.28s CPU，停滞在早期启动 | **steam.exe 主进程未运行**（只剩 16:14 遗留的 steamwebhelper 孤儿进程） |
| r3-attempt2 | `run-20260924-184804-r3-attempt2-FAILED` | 游戏进程在启动中自行退出；GABS 报 `stopped (stale runtime state was removed)` | 同上（Steam 重启发生在该次尝试之后） |

**根因确认过程**：用 `Get-Process -Name 'steam'` 得到 1，一度看似正常；改用精确匹配后确认该计数命中的是 `steamwebhelper.exe` 而非 `steam.exe`，`steam.exe` 实际计数为 **0**。重新拉起 `steam.exe`（pid 28856）并等待 80 秒后，第 3 轮一次通过。

此失败**不属于 CBATH 缺陷**，属于环境前置条件缺失，与交接文档 §5.4「Steam 必须运行且 API 已就绪」一致。

---

## 五、P1-005 验收对照

| 判据（用户确认稿） | 结果 |
|---|---|
| 3 轮各自独立启动，PID 互不相同 | ✅ 46508 / 35608 / 37308 |
| 运行时 build_id 与部署一致 | ✅ 三轮均为 `b20260924-171754-2eeefc21` |
| 运行时 SHA256 与磁盘逐字节一致 | ✅ 三轮均比对通过 |
| game_version = v1.4.8.119303 | ✅ |
| loaded modules 含 CustomBattle 与 CBATH | ✅ |
| games_connect 成功 | ✅ |
| mission_running = true 且 mission_name 非空 | ✅ |
| 双方各至少 1 个非空 Formation（teams ≥ 2） | ✅ 2 队，9 个非空阵型 |
| end_mission 后 mission_running = false | ✅ |
| games_stop 返回 termination verified | ✅ |
| cleanup 后 Bannerlord 进程数为 0 | ✅ |
| 每轮记录存档至 `evidence\runs\<run_id>.json` | ✅ |

---

## 六、已验证能力的完整清单

| 能力 | 工具 | 证据级别 |
|---|---|---|
| 存活探测 + 版本 | `cbath/ping` | VERIFIED AT RUNTIME |
| 运行时身份（build_id/SHA256/MVID/pid/modules） | `cbath/get_build_identity` | VERIFIED AT RUNTIME |
| 游戏状态与状态转换历史 | `cbath/get_game_state` | VERIFIED AT RUNTIME |
| Mission 运行状态 | `cbath/get_mission_state` | VERIFIED AT RUNTIME |
| 双方 Formation 快照 | `cbath/get_all_formations` | VERIFIED AT RUNTIME |
| 无人值守进入固定 Mission | `cbath/h3_provider_start` + `cbath/h3_start_from_screen` | VERIFIED AT RUNTIME |
| 结束 Mission | `cbath/end_mission` | VERIFIED AT RUNTIME |
| 游戏进程启动/连接/停止 | GABS `games_start` / `games_connect` / `games_stop` | VERIFIED AT RUNTIME |

---

## 七、明确未验证 / 失败项

| 项 | 状态 | 说明 |
|---|---|---|
| HTTP 编排脚本 `run-lifecycle.ps1` 跑通 | **FAILED** | 受双 gabs 实例 claim 冲突阻塞，本轮改用单实例直驱绕过 |
| 双 gabs 实例并发 ownership 协调 | **NOT TESTED** | 超出本 Phase 范围 |
| `-Redeploy` 重编译后身份比对 | **NOT TESTED**（本轮未执行） | 因磁盘哈希已独立证明与运行时一致，该路径非必需 |
| 全量 Bannerlord.GABS 移植到 1.4.8 | **NOT TESTED** | 明确非目标 |
| 战斗配置的显式指定（兵力/地图） | **NOT TESTED** | 当前使用 CustomBattle 默认配置 |
| `git_commit` 注入 build identity | **NOT TESTED** | 工作区不在 git 仓库 |
| 长时间稳定性（>3 轮 / >1 小时） | **NOT TESTED** | 超出 P1-005 范围 |

---

## 八、Phase 1 边界遵守声明

按 prompt 严格边界，本 Phase 未越界：

- ✅ P1-005 全部 PASS 后**立即停止开发**，未开始 Phase 2
- ✅ 未修改 CombatBrain 2.0 主工程
- ✅ 未移植全量 Bannerlord.GABS 到 1.4.8
- ✅ 未引入第三方 mod
- ✅ 未修改任何现有编排脚本与 CBATH 源码（本轮仅新增 evidence JSON 与交付文档）

---

## 九、相关文档

- `13-Phase1-Runtime-Evidence.md` — 运行时原始证据
- `14-Phase1-Remaining-Risks.md` — 剩余风险与技术债
- `evidence\runs\` — 每轮 JSON 记录（含 2 次失败尝试）
- `evidence\P1-002-delivery-proof.md` — P1-002 交付证明
- `experiments\P1-001~P1-004-*.md` — 各阶段实验记录
