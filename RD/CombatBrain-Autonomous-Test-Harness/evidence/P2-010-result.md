# P2-010 Zero-touch 自动开战 — 结果：**PASS 3/3**

日期：2026-09-25
前置：P2-009（IL 层 API 确认）、P2-008（语义审计）
任务来源：`15-Handover-P2-008.md` 第四节

---

## 一、结论

两个新工具已实现并各自通过运行期断言验证；无人值守连续 **3/3 轮**全部满足 8 条硬判据。

| 项 | 结果 |
|---|---|
| `cbath/auto_finish_deployment` | **PASS**（`AllowAiTicking` false→true 实测转换） |
| `cbath/delegate_team_to_ai` | **PASS**（4 有兵编队 + 4 空编队 全 false→true） |
| Zero-touch 3/3 | **PASS 3/3**（exit code 0） |

---

## 二、变更文件

| 文件 | 变更 |
|---|---|
| `experiments\test-mod\CBATH\AutoDeployControl.cs` | **新增**：两个工具的核心逻辑，仅用引擎公开 API |
| `experiments\test-mod\CBATH\CbathTools.cs` | **追加**两个 `[Tool]` 注册（未改既有代码） |
| `experiments\test-mod\CBATH\CombatBrainAutonomousTestHarness.csproj` | **追加**一行 `<Compile Include="AutoDeployControl.cs" />` |
| `tools\zero-touch-3x.ps1` | **新增**：Zero-touch 3/3 验收脚本 |
| `tools\mcp-http.ps1` | **修正 1 行**：`[int](Get-Date).Ticks % 100000` → `[int]((Get-Date).Ticks % 100000)`（原因见 §7） |
| `evidence\P2-010-step1-tool-verification.md` | **新增**：单体验证证据 |
| `evidence\runs\zt-*.json`、`zero-touch-*.json` | **新增**：每轮存档 |

---

## 三、构建 / 部署 / 运行身份

```text
build 命令 : pwsh -File build-deploy.ps1
build 退出码: 0（0 warnings / 0 errors）
build_id    : b20260925-013209-2b52d28b
SHA256      : 93f6e154b6b92f38ce1ab642e64f15a7366cf7b93fdfc75ff0ee949c95dfe91b
部署时间     : 2026-09-25 01:32:13
MVID        : e9f98865-06a7-47d8-ab7d-585cb445904a
实际 game build: v1.4.8.119303
```

运行时自读（`cbath/get_build_identity`）与部署值**逐项一致**；GABS 工具数 13 → 15。

模块集（未改动）：

```text
Bannerlord.Harmony,Bannerlord.ButterLib,Bannerlord.UIExtenderEx,Bannerlord.MBOptionScreen,
Native,SandBoxCore,Sandbox,StoryMode,CustomBattle,CombatBrain,CombatBrainAutonomousTestHarness
```

---

## 四、工具实现（引擎公开 API，零 Win32 输入模拟）

| 需求 | 使用的 API | 来源 |
|---|---|---|
| 找 deployment controller | `Mission.MissionBehaviors` 遍历，`as DeploymentMissionController` | 1.4.8 参考程序集 |
| 就绪条件 | `DeploymentMissionController.TeamSetupOver`（public prop） | 同上 |
| 结束部署 | `DeploymentMissionController.FinishDeployment()`（public method） | 同上 |
| AI ticking 验证 | `Mission.AllowAiTicking`（public field） | 同上 |
| 取玩家队 | `Mission.PlayerTeam` | 同上 |
| 遍历编队 | `Team.FormationsIncludingEmpty` | 同上 |
| 交 AI | `Formation.SetControlledByAI(bool, bool)` | 同上 |
| 读状态 | `Formation.IsAIControlled` | 同上 |

**关键设计约束**：工具运行在游戏主线程（`MainThreadDispatcher`）。`auto_finish_deployment` **不做自旋等待**——单次检查 `TeamSetupOver`，为 false 时返回 `status=not_ready`，由调用方轮询。自旋会阻塞主线程卡死游戏。

**与人工输入的一致性**：
- `delegate_team_to_ai` 遍历 `FormationsIncludingEmpty`，与 `Team.DelegateCommandToAI`（F6）的 IL **逐字节一致**，含空编队。
- 调用参数 `(true, false)` 与 P2-009 IL 确认值一致。

---

## 五、单体验证（证据：`P2-010-step1-tool-verification.md`）

### 5.1 负路径

无 mission 时两者均返回 `{"status":"no_mission"}`，不抛异常。

### 5.2 `auto_finish_deployment`

```json
{"before":{"allow_ai_ticking":false,"team_setup_over":true,"player_team_formations":8},
 "after" :{"allow_ai_ticking":true, "team_setup_over":true,"player_team_formations":8},
 "status":"ok"}
```

`allow_ai_ticking` **false → true**，即 P2-009 IL 预测的 `FinishDeployment` 直接效果，运行期实测确认。

### 5.3 `delegate_team_to_ai`

| formation_index | class | unit_count | before | after |
|---|---|---:|---|---|
| 0 | Infantry | 24 | false | **true** |
| 1 | Ranged | 25 | false | **true** |
| 2 | Cavalry | 25 | false | **true** |
| 3 | HorseArcher | 25 | false | **true** |
| 4-7 | Unset | 0 | false | **true** |

8/8 编队（含 4 个空编队）`all_ai_controlled = true`，无 error。

### 5.4 真开战判据（P2-007 规则：显式状态，非秒数）

- `movement_order` 出现 `Move` / `Charge`（非 `StandYourGround`）
- `unit_count` 下降（24→23、25→21，真实伤亡）
- `arrangement_order` 出现 `ArrangementScatter`

---

## 六、Zero-touch 3/3（无人值守）

**权威批次（对应当前脚本修订）**：`zero-touch-20260925-024918`，窗口 `2026-09-24T18:49:18Z → 18:53:42Z`

脚本修订：`tools\zero-touch-3x.ps1` sha256 `2fd3361b9bd1c12040c8acb0153cdd0f1b79795caeaca219b995da1fa034bf66`（mtime 2026-09-25 02:43:09）

| 轮次 | 尝试 | 结果 | c1 | c2 | c3 | c4 | c5 RouteAEvent | c6 samples | c7 hits | c8 | 窗口 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | a1 | **PASS** | ✅ | ✅ | ✅ | ✅ | 150 | 66 | 0 | ✅ | 65s |
| 2 | a1 | **PASS** | ✅ | ✅ | ✅ | ✅ | 131 | 57 | 0 | ✅ | 55s |
| 3 | a1 | **PASS** | ✅ | ✅ | ✅ | ✅ | 109 | 46 | 0 | ✅ | 45s |

**总判定：PASS (3/3)，exit code 0。三轮均首次尝试即通过，无需重试。**

三轮共同点（一致性证据）：
- `c2_allow_ai_ticking_after = true`（三轮一致）
- `c4a casualities = true`（194→193，三轮一致）
- `c7 hits = 0`（实扫描，非硬编码）
- `build_id = b20260925-013209-2b52d28b`、`mvid = e9f98865-06a7-47d8-ab7d-585cb445904a`（三轮一致）
- `cleanup = clean`、`errors = []`（三轮一致）
- 所有轮次 `c6 ≥ 40` 且 `窗口 ≥ 40s`（`minWindow` 修正生效的直接证据）

### 8 条硬判据逐条

| # | 判据 | 阈值 | 实测 |
|---|---|---|---|
| 1 | 进入 Mission | `mission_running=true` | ✅ 3/3 |
| 2 | 部署确实结束 | `status=ok` 且 `AllowAiTicking=true` | ✅ 3/3 |
| 3 | 真开战 | 出现非 `StandYourGround` | ✅ `Move`/`Charge` |
| 4 | 真实动态变化 | `unit_count` 下降 | ✅ 194→193（三轮） |
| 5 | CombatBrain telemetry | RouteAEvent ≥ 10 | ✅ 150 / 131 / 109 |
| 6 | CBATH 连续采样 | sample_count ≥ 40 | ✅ 66 / 57 / 46 |
| 7 | 未触碰鼠标键盘 | 源树实扫描 = 0 命中 | ✅ `hits=0` |
| 8 | 无残留进程 | Bannerlord 进程数 0 | ✅ `cleanup=clean` |

### 迭代过程中的失败轮（如实披露，未掩盖）

最终修订之前有两批运行，其失败均为**真实判据未达标或真实设计缺陷**，不是脚本误判：

| 批次 | 失败轮 | 原因 | 处理 |
|---|---|---|---|
| `...021551` | R1 a1 | `c6=31 < 40`，窗口仅 30s | 重试通过 |
| `...022243` | R2 a1 / R3 a1 | `c6=38` / `37`，窗口均 35s | 重试通过 |

**根因是验收设计本身的冲突**（见 §7 #9）：战斗窗口在"出现伤亡"时立即结束，而 `c6` 要求 ≥40 个 1 Hz 采样点（需 ≥40s）。当伤亡出现很快时二者直接矛盾。

按用户裁定采用「窗口不低于 `MinSamples` 秒」修正后，两个批次（`...024321`、`...024918`）三轮**全部首次通过**，证明修的是真实缺陷而非掩盖现象。

> 另有早期批次 `...013829`/`...013856`/`...014014`/`...015511`/`...020601`/`...021410` 因脚本自身缺陷（见 §7 #1–#6）整体失败，记录保留在 `evidence\runs\` 中未删除。

---

## 七、排障记录（本轮踩坑，供后续复用）

| # | 现象 | 根因 | 处理 |
|---|---|---|---|
| 1 | 所有 MCP 调用抛 `Cannot convert value "639..." to Int32` | `tools\mcp-http.ps1` 的 `[int](Get-Date).Ticks % 100000`，PS 5.1 先转型后取模溢出 | 改为 `[int]((Get-Date).Ticks % 100000)`；已实测 cast-then-mod 抛异常、paren-mod-then-cast 正常 |
| 2 | `games_start` 明明成功却判"无 pid" | 成功响应文本为 `started successfully and connected via GABP`，**不含 `pid `**；且成功响应文本里没有工具名 | 改为从 `structuredContent`（`started_connected` / `processStarted`）判定；payload 也统一从 `structuredContent` 读 |
| 3 | 每轮 `cbath/*` 全部 `not found`（`availableTotal:0`） | 批处理自起的 gabs 实例与 DSH 的 gabs（pid 31972）争抢：`already owned by another active GABS session` → 工具快照为空 | `games_connect` 加 `forceTakeover=true`（实测 `Discovered 15 tools`） |
| 4 | 文本信封正则解不出 payload | 成功响应的转义方式与正则不匹配（实测 raw 中既无 `cbath/ping` 也无 `cbath_ping`） | 改从 `result.structuredContent` 直读 |
| 5 | 连续多次启动"崩溃"（只有「子模块已加载」无后续） | **并非崩溃**：脚本失败后调 `games_stop` 把游戏杀了，日志自然只剩一行。实测窗口枚举无任何对话框，`cbath/ping` 正常 | 修正判定链路后消失 |
| 6 | `safely_exited` 复位被覆盖 | Preflight 先复位再杀进程，被杀游戏又写回 0 | 调整顺序：**先杀 → 再复位**；并加优雅 `games_stop` 优先 |
| 7 | 汇总显示 `PASS (36/1)` | PS 5.1 中 `$array += $orderedDict` 会把字典**按键拆散**追加（实测 4 键字典得 4 个元素） | 改为从 `$batch.rounds` 统计（实测修复后计数正确） |
| 8 | `NowUtc()` 解析失败 | PS 5.1 函数调用需 `(NowUtc)`，不接受 `NowUtc()` | 改为 `(NowUtc)` |
| 9 | `c6` 与战斗窗口互相矛盾（R2/R3 首轮均因 `c6≈37` 失败） | 窗口在首次伤亡后立即结束（实测 35s），而 `c6` 要求 ≥40 个 1 Hz 采样点 | 用户裁定：窗口**不低于 `MinSamples` 秒**（`minWindow = max(5, MinSamples)`）；修正后三轮全部首次通过 |
| 10 | `c7_no_win32_input` 是硬编码 `$true`（审查发现的空判据） | 该条从未真正检查过，属"无证据即通过" | 改为**实扫描** CBATH 源树 + 本脚本，命中 Win32 输入 API 即 FAIL；已做红/绿验证（注入探针文件 → 命中；干净树 → 0 命中） |

> 说明：`tools\mcp-http.ps1` 是既有共享脚本（P1-005 曾用它通过）。本次为 1 行行为等价修正，不改变其语义。
>
> 审查另发现 `tools\sample-startup*.ps1` 确实含 `PostMessage` 按键注入，但本批 Zero-touch **从不调用**它们，故 `c7` 扫描范围限定为「CBATH 源树 + 本脚本」。

---

## 八、尚未验证 / 未做的事

1. **`not_ready` 分支未在运行期实测**：3 轮中调用 `auto_finish_deployment` 时 `TeamSetupOver` 均已为 true（轮询到场景加载完成才调）。该分支仅由代码路径覆盖。
2. **`no_deployment_controller` 分支未实测**：CustomBattle 必产生 controller。
3. **战斗配置仍非显式指定**：沿用 CustomBattle 默认（技术债 #5，未变）。
4. **未做 CombatBrain 逐条时间关联**：本轮仅统计增量条数，未复用 `cb-correlate.ps1`。
5. **zombie 进程残留**：多次强杀会留下 `HasExited=true` 的僵尸条目（`Win32_Process` 可见、`Get-Process` 标 HasExited）。已验证**不锁 DLL**（DLL 可独占打开）、不占 CPU，属外观残留。本轮结束后活动进程为 0。
6. **未提高采样频率**、未建稳定 Formation ID、未处理 21.7% mismatch、未做 attribution（均在边界外）。
7. **`c7` 扫描范围为「CBATH 源树 + 本脚本」**：不覆盖 `tools\` 下本批未调用的其它辅助脚本（其中 `sample-startup*.ps1` 确实含 `PostMessage` 按键注入，但未被本批调用）。

---

## 九、环境终态

| 项 | 值 |
|---|---|
| 活动 Bannerlord 进程 | **0** |
| steam.exe | 1（pid 6824） |
| gabs 实例 | 1（DSH 会话 pid 31972） |
| `safely_exited` | 1（优雅停止保持） |
| CombatBrain.log | 64,898,206 bytes |
| 部署 DLL SHA256 | `93f6e154b6b92f38ce1ab642e64f15a7366cf7b93fdfc75ff0ee949c95dfe91b` |
| 未修改 | CombatBrain 源码/二进制、`gabs-config\config.json`、模块集 |

---

## 十、边界合规

- ✅ CBATH 核心零 CombatBrain 引用（`AutoDeployControl.cs` 仅引 `TaleWorlds.MountAndBlade`）
- ✅ 无 Win32 键盘/鼠标输入模拟
- ✅ 未合成黑盒 `start_battle`，保持两个显式动作工具
- ✅ 未修改 CombatBrain 2.0 主工程 / 未移植 GABS / 未引入第三方 mod
- ✅ 未提高采样频率（保持 1 Hz）
