# 交接提示词 — CombatBrain Autonomous Test Harness（P1-005 续做）

> 你是一名接手的 Implementation Agent。前一位 Agent 已完成 P1-001 ~ P1-004，
> 并在 P1-005（三轮连续生命周期）的**编排脚本**上遇到技术障碍后停下交接。
> 请先读完本文，再动手。不要重新做 Phase 0 研究，不要重跑已 PASS 的验收。

---

## 一、工作区与必读文档

工作区：`E:\MBmod\CombatBrain Autonomous test harness`

必读（按顺序）：

```text
RD：CombatBrain Autonomous Test Harness.md          # 原始 RD
RD\CombatBrain-Autonomous-Test-Harness\08-Phase1-MVP.md   # P1-001~P1-006 验收定义
RD\CombatBrain-Autonomous-Test-Harness\experiments\
    P1-001-experiment-log.md      # 构建身份
    P1-002-experiment-log.md      # MCP 桥接
    P1-003-red-green.md           # Formation 读取
    P1-004-result.md              # 固定 Mission 自动进入（关键，含有效路线）
    P1-004-open.md                # 已失效的 BLOCKED 记录（H1/H3 已解决，仅作过程留档）
    DSH-MCP-setup.md              # DSH MCP 配置方法
    intro-video-removal.md        # 开场动画处理
```

关键环境事实：

| 项 | 值 |
|---|---|
| 游戏目录 | `E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord` |
| 游戏版本 | v1.4.8.119303（Native SubModule.xml `v1.4.8`，Steam buildid 24573425） |
| Go | `C:\Program Files\Go\bin\go.exe`（1.27.0，本会话新装） |
| GABS 源码/二进制 | `_source-cache\gabs\`（`gabs.exe` 1.1.1，本会话构建） |
| GABS 配置 | `gabs-config\config.json`（game id `bannerlord148`） |
| DSH MCP 配置 | `.dsh\dshmm\mcp.json`（serverName `gabs`） |
| Test Mod 源码 | `RD\CombatBrain-Autonomous-Test-Harness\experiments\test-mod\CBATH\` |

---

## 二、已完成并 PASS 的部分（不要重做）

| 阶段 | 结论 | 证据 |
|---|---|---|
| **P1-001** Runtime Identity | PASS | `evidence\p1-001-*`、`experiments\P1-001-experiment-log.md` |
| **P1-002** Ping Bridge | PASS | `evidence\P1-002-delivery-proof.md` |
| **P1-003** Formation Snapshot | PASS | `evidence\p1-003-formations-both-sides.json`、`experiments\P1-003-red-green.md` |
| **P1-004** Autonomous Mission | **PASS（完全无人值守）** | `evidence\p1-004-formations-autonomous.json`、`experiments\P1-004-result.md` |

### Test Mod 当前已实现的工具（经 GABP 暴露）

```text
cbath/ping                      # liveness + build_id
cbath/get_build_identity        # 完整运行时身份（build_id / SHA256 / MVID / pid / modules）
cbath/get_game_state            # topScreenType / activeGameState / mission / transitions
cbath/get_all_formations        # 双方所有非空 Formation（P1-003 核心）
cbath/start_fixed_mission       # 当前走 CustomBattleHelper.StartGame（失败路线，见下）
cbath/get_mission_state         # mission_running / mission_name / mission_time（真实状态判据）
cbath/end_mission               # EndMission()
cbath/probe_mission_env         # 诊断用
cbath/push_custombattle_state   # 诊断用（NRE）
cbath/h1_create_game_then_push  # 诊断用（NRE）
cbath/h3_provider_start         # 【P1-004 有效路线 1】
cbath/h3_start_from_screen      # 【P1-004 有效路线 2】
```

### P1-004 唯一已验证可行的自动进入 Mission 路线（两步）

```csharp
new CustomBattleProvider().StartCustomBattle();   // → GameLoadingState → CustomBattleState/CustomBattleScreen
// 等待 topScreenType == CustomBattleScreen
// 反射取 screen 私有字段 _dataSource（CustomBattleVM），调用 ExecuteStart()
// → MissionScreen，mission_running == true
```

失败路线（已实测 NRE，不要重试）：
- `CPUBenchmarkMissionLogic.OpenCPUBenchmarkMission(scene)` → NRE
- `GameStateManager.PushState(CreateState<CustomBattleState>())` → NRE
- `Game.CreateGame(new CustomGame(), new CustomGameManager())` 后再 PushState → 仍 NRE（更深一层）
- `CustomBattleHelper.StartGame(CustomBattleData)` → NRE（`CustomBattleData.get_Factions`，主菜单下 `Game.Current == null`）

---

## 三、当前进度：P1-005 卡在编排脚本

### 目标（prompt 原文）
连续 **3 次**完整流程无用户介入：启动 → 确认身份 → 建立通信 → 进固定 Mission →
读双方 Formation → 结束 Mission → 退出/cleanup。每轮记录 run_id、PID、game_version、
build_id、loaded module identity、MCP 连接结果、game 连接结果、mission 状态转换、
formation 快照、mission 退出、game 退出、cleanup 结果。

### 已写好的脚本

| 文件 | 状态 |
|---|---|
| `tools\run-lifecycle.ps1` | 单轮完整流程编排，**编排逻辑已完成**，未跑通 |
| `tools\mcp-http.ps1` | MCP over HTTP 会话helper，**已验证 HTTP 通道可用** |
| `tools\mcp-session.ps1` | MCP over stdio helper，**已废弃**（PowerShell 5.1 读重定向流会阻塞） |
| `tools\invoke-gabs-mcp.ps1` | 早期 stdio driver，仅用于一次性调用，**不能用于需要 start+call 同一进程的场景** |
| `tools\test-p1-003.ps1` | P1-003 Formation 断言器（绿） |
| `tools\test-p1-004.ps1` | P1-004 四步断言器 |

### 核心难点（已定位，需解决）

**GABS 有运行时所有权（runtime claim）机制**：一个 gabs 实例启动游戏并持有 claim 后，
**另一个** gabs 实例调用 `games_connect` 会被拒绝：

```text
Game 'bannerlord148' is already owned by another active GABS session (pid NNNNN).
Skipping games_connect here to avoid competing...
```

因此 `games_start` 和后续所有 `games_call_tool` **必须由同一个 gabs 进程完成**。

- 走 stdio（`mcp-session.ps1`）：PowerShell 5.1 下 `ReadLineAsync()` 返回 null、
  `ReadLine()` 在无数据时永久阻塞、`Peek()` 也不可靠 → 已放弃。
- 走 HTTP（`mcp-http.ps1`）：**通道本身已验证可用**（`initialize` 与 `games_list` 均正常返回），
  但 `run-lifecycle.ps1` 尚未跑通。

### 最后一次探测的实际失败点

`probe-20260924-175815.json`：

```json
{"errors":["start failed: no pid"], "game_connection_result": null}
```

进程列表里发现 gabs 以 `server --http localhost:0` 启动 —— 端口参数没传进去（`$Port` 变量作用域冲突）。
**已修复**：`mcp-http.ps1` 参数改名 `$ListenPort` / `$script:McpListenPort`；
`run-lifecycle.ps1` 改为 `$McpPort` 传给 `Open-McpHttp -ListenPort $McpPort`。
**修复后尚未重跑验证。**

### 另一条必然可用的保底路线

DSH Agent 自己就是 MCP 客户端，已有 `mcp__gabs__*` 全套工具且会话由 DSH 持有 claim。
可以直接由 Agent 按顺序调用完成 3 轮，脚本只做 preflight / cleanup / 证据归档。
缺点：不是全自动脚本；优点：**确定可行**，且天然满足
「DeepSeek Harness 官方 MCP 客户端」这一验收语义（P1-002 spec AC9）。
如果需要可重复的自动化脚本，再回头解决 HTTP 编排。

---

## 四、下一阶段任务：P1-005

### 立即要做的

1. 先重跑一次 `run-lifecycle.ps1` 单轮，确认端口修复是否生效：
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tools\run-lifecycle.ps1" -RunId probe-<ts>
   ```
   - 若 PASS → 再跑 `-Redeploy` 版验证「重建后运行时 build_id 与部署一致」，然后连续跑 3 轮。
   - 若仍失败 → 切保底路线（由 DSH Agent 直接调用 `mcp__gabs__*` 跑 3 轮），
     脚本只负责 preflight 与归档，并如实记录「3 轮由 Agent 直接驱动」。
2. **3 轮必须各自独立启动进程**，不得复用上一轮数据；
   任一轮失败则计数归零，从该轮重新开始连续计数。
3. 每轮记录存档到 `evidence\runs\<run_id>.json`（字段清单见上一节目标）。

### 严格边界（prompt 原文，不得越界）

- P1-005 全部 PASS 后**立即停止开发**，不擅自开始 Phase 2 / CombatBrain 集成 /
  Telemetry / Evaluator / Scenario 框架。
- 不修改 CombatBrain 2.0 主工程。
- 不移植全量 Bannerlord.GABS 到 1.4.8。
- 不引入第三方 mod。

### Phase 1 完成后的交付物（prompt 要求）

```text
12-Phase1-Implementation-Report.md
13-Phase1-Runtime-Evidence.md
14-Phase1-Remaining-Risks.md
```

Implementation Report 必须明确区分：
`VERIFIED AT RUNTIME` / `VERIFIED BY BUILD ONLY` / `INFERRED` / `NOT TESTED` / `FAILED`。

---

## 五、环境操作要点（踩过的坑，务必遵守）

1. **启动游戏前必须 `safely_exited = 1`**
   路径：`Documents\Mount and Blade II Bannerlord\Configs\engine_config.txt`
   `safely_exited = 0` → 弹 **Safe Mode** 对话框，**静默阻断所有 Mod 加载**
   （进程活着、无任何日志，极易误判为"编译错误"）。
   强杀游戏后游戏会写回 0，所以**每次启动前都要复位**。`build-deploy.ps1` 已内置此动作。

2. **模块集必须包含 CustomBattle**，否则无法进自定义战斗：
   ```text
   _MODULES_*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*CombatBrainAutonomousTestHarness*_MODULES_
   ```

3. **首次改模块集会弹 "Mod change detected"**（阻断 Mod 加载），Enter 确认一次即可，之后不再出现。

4. **Steam 必须在运行且 API 已就绪**；否则游戏抛 `Unable to initialize Steam API` 对话框并退出。
   拉起 Steam 后要等 45 秒以上再启动游戏。

5. **不要在 `games_start` 之后修改 `.dsh\dshmm\mcp.json`** —— 会触发 DSH 重载 MCP 服务器，
   杀掉 gabs 及其启动的游戏（表现为 `stale-runtime-cleaned`）。

6. **`mcp.json` 的字段名是 `type` 不是 `transport`**；缺失会被当 HTTP 简写并报
   `http servers require a "url"`。改完可用 `dsh-mcp-mgr` 的 `parseMcpJson` 预校验。

7. **GABS 工具列表是 connect 时快照**：部署新 DLL 后必须重新 `games_connect`
   （会返回 `Re-synced N tools`），否则一直报 `not found`。

8. **主 DLL 文件锁**：强杀游戏后 `CombatBrainAutonomousTestHarness.dll` 可能被僵尸进程
   （`HasExited=true` 但句柄不释放，`taskkill` 报 "no running instance"）持续锁定。
   `build-deploy.ps1` 已改为忽略 `HasExited=true` 的进程；锁未释放时可用备用 DLL 名 +
   改 `SubModule.xml` 的 `DLLName` 应急（记得事后恢复）。

9. **Go 模块下载 TLS 校验失败**（本机环境）：复用
   `GOPROXY=https://goproxy.cn,direct` + `GOSUMDB=off` 构建 GABS。

10. **开场动画已通过移走视频文件消除**（30s → 3s）：
    `Modules\Native\Videos\TWLogo_and_Partners.{mp4,ivf,ogg}` 移到了
    `_intro-video-hidden\`，原件备份在 `_intro-video-backup\`。
    **Steam 校验游戏完整性会恢复这些文件**，届时动画重现（重新移走即可，不算失败）。

11. **构建/部署**：
    ```powershell
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "experiments\test-mod\CBATH\build-deploy.ps1"
    ```
    会生成唯一 build_id → 编译 → 校验 stamp → 部署 → 双向 SHA-256 比对 → 复位 safely_exited。

---

## 六、已知技术债（需在报告中如实披露）

1. **`ExecuteStart` 靠反射取私有字段 `_dataSource`** —— UI 重构即失效。
   长期方案需找 provider 侧无需反射的启动入口。
2. **当前战斗使用 CustomBattle 屏幕的默认配置**，不是我们显式指定的兵力/地图。
   P1-005 要证明「固定 Mission」的话，需要先验证默认配置每次是否一致
   （已观测两次：一次 98/90 单一兵种；一次 4 阵 100 人 / 5 阵 95 人 —— **两次不同，需处理**）。
3. `git_commit` 未注入 build identity（工作区不在 git 仓库）。
4. GABS 二进制未走 `make build`（Makefile 依赖 GNU sed/rm），因此没有注入 version/commit ldflags。

---

## 七、汇报格式要求

每个 P1-00N 交付：

```text
变更文件
build/test 命令与退出码
独立日志路径
实际 game build
DLL hash / build ID / MVID
观察到的状态
通过/失败及失败含义
尚未验证项
```

任何 "READY / GO" 必须有真实游戏运行证据。
**不得**把「编译通过」「工具列存在」「进程存在」「一次成功」当作完整闭环证据。
