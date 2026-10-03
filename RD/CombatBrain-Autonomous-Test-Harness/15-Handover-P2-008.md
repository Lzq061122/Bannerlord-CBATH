# 交接提示词 — CombatBrain Autonomous Test Harness（P2-008 续做：自动开战）

> 你是一名接手的 Implementation Agent。前一位 Agent 已完成 P1-001~P1-005（Phase 1 全部 PASS）
> 与 P2-001~P2-007（模块加载、CombatBrain 运行确认、1Hz 采样、时间关联），
> 并在 P2-008/P2-009 完成了「自动开战」的**语义审计与 IL 层参数确认**后停下交接。
> 请先读完本文，再动手。不要重新做已 PASS 的验收，不要重新做 IL 审计（结论已固化）。

---

## 一、工作区与关键环境事实

工作区：`E:\MBmod\CombatBrain Autonomous test harness`

| 项 | 值 |
|---|---|
| 游戏目录 | `E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord` |
| 游戏版本 | v1.4.8.119303（Native SubModule.xml `v1.4.8`，Steam buildid 24573425） |
| Go / GABS | `_source-cache\gabs\gabs.exe` 1.1.1（Go 1.27.0 本会话构建） |
| GABS 配置 | `gabs-config\config.json`（game id `bannerlord148`） |
| DSH MCP 配置 | `.dsh\dshmm\mcp.json`（serverName `gabs`，type=stdio） |
| CBATH 源码 | `RD\CombatBrain-Autonomous-Test-Harness\experiments\test-mod\CBATH\` |

### 当前有效模块集（P2-003 已固化，勿改）

```text
_MODULES_*Bannerlord.Harmony*Bannerlord.ButterLib*Bannerlord.UIExtenderEx*Bannerlord.MBOptionScreen*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*CombatBrain*CombatBrainAutonomousTestHarness*_MODULES_
```

**Bootstrap 框架模块（Harmony/ButterLib/UIExtenderEx/MCM）必须排在 Native 之前**，否则模块加载中止（表观为"崩溃"：全线程 Suspended、零日志、崩溃报告对话框由 csrss.exe 承载）。这是 P2-003 定位的根因，已固化。

### 当前 CBATH 部署身份

| 项 | 值 |
|---|---|
| build_id | `b20260925-002732-a6df5e05` |
| SHA256 | `c1603acc7abd32c75f984ad1c6df153ebad3721ae6adb91ba56280059053f751` |
| 部署时间 | 2026-09-25 00:27:34 |
| MVID | 部署时以运行时自读为准（`get_build_identity`） |

---

## 二、已完成并 PASS 的部分（不要重做）

### Phase 1（P1-001 ~ P1-005，全部 PASS）

| 阶段 | 结论 | 证据 |
|---|---|---|
| P1-001 Runtime Identity | PASS | `evidence\p1-001-*` |
| P1-002 Ping Bridge | PASS | `evidence\P1-002-delivery-proof.md` |
| P1-003 Formation Snapshot | PASS | `evidence\p1-003-*.json` |
| P1-004 Autonomous Mission | PASS | `evidence\p1-004-*.json` |
| P1-005 3×连续生命周期 | **PASS 3/3** | `evidence\runs\run-20260924-18*-r*.json` |

Phase 1 三份交付文档：
`12-Phase1-Implementation-Report.md` / `13-Phase1-Runtime-Evidence.md` / `14-Phase1-Remaining-Risks.md`

### P2 系列（自动开战前的一切前置）

| 阶段 | 结论 | 证据 |
|---|---|---|
| P2-001 smoke | FAILED（模块集无 CombatBrain → 依赖冲突） | `P2-001-smoke-failed.md` |
| P2-002 对照实验 | 崩溃与 CombatBrain 无关（Harmony/MCM 线） | `P2-002-control-experiment.md` |
| P2-003 加载顺序 | **根因定位：框架模块必须在 Native 前** | `P2-003-loadorder-fix.md` |
| P2-004 CombatBrain 运行 | **PASS（MissionBehavior 注册 + 执行证据）** | `P2-004-combatbrain-running.md` |
| P2-005 1Hz 采样 | **PASS（53 点，多动态量判据）** | `P2-005-final.md` |
| P2-006 时间关联审计 | 格式 + 时间基准确认 | `P2-006-correlation.md` |
| P2-007 实时交战关联 | **PASS（129 状态变化 / 1380 命令，78.3% 时间吻合）** | `P2-007-result.md` |

---

## 三、当前进度：P2-008 停在"实现前的最小验证"完成之后

### 用户已授权

新增两个 CBATH 工具：

```text
cbath/auto_finish_deployment    # 只负责结束部署，返回调用前后状态
cbath/delegate_team_to_ai       # 只负责把玩家 Team 的 Formation 交给 AI，返回每个编队调用前后 IsAIControlled
```

**要求**：
- 只依赖 Bannerlord 引擎公开 API；
- 不引用 CombatBrain；
- 不引入 Win32 输入模拟；
- 显式动作工具，**不要**合成黑盒 `start_battle`；
- 实现后先**单独验证两个工具**，再跑 Zero-touch 3/3。

### P2-009 已完成的 IL 层确认（勿重做，直接引用）

证据文档：`evidence\P2-009-param-confirm.md`

**1. `SetControlledByAI` 双参语义（从游戏程序集 IL 确认）**

```text
Formation.SetControlledByAI(bool isControlledByAI, bool enforceNotSplittableByAI)
```

**2. F6 的确切实现 = `Team.DelegateCommandToAI()`**

```il
foreach (var f in Team.FormationsIncludingEmpty)
    f.SetControlledByAI(true, false);    // ldc.i4.1, ldc.i4.0 已在 IL 逐条确认
```

**3. `FinishDeployment` 就绪条件**

```text
DeploymentMissionController.TeamSetupOver   // public getter
轮询 TeamSetupOver == true → 调用 FinishDeployment()（public void）
```

`FinishDeployment()` 内部（IL 已确认）：
- `Mission.Current.OnDeploymentFinished()`
- **`Mission.AllowAiTicking = true`**（部署期 `AfterStart` 置 false，FinishDeployment 打开 AI ticking）
- `Mission.OnAfterDeploymentFinished()`，移除自身 behavior

**关键顺序**：**先 `FinishDeployment()`（开 AI ticking）→ 再 `DelegateCommandToAI`（把编队交给 AI）**。两者互补。

---

## 四、下一阶段任务：实现两个工具 + Zero-touch 3/3

### 实现建议（基于 P2-009 结论）

```text
cbath/auto_finish_deployment:
  1. 从 Mission.Current 找 DeploymentMissionController（或其子类 BattleDeploymentMissionController）
  2. 轮询 TeamSetupOver == true（public getter，不 sleep）
  3. 调用 controller.FinishDeployment()（public void）
  4. 验证：Mission.AllowAiTicking == true
  5. 返回调用前后状态（TeamSetupOver / AllowAiTicking / phase）

cbath/delegate_team_to_ai:
  1. 取 Mission.PlayerTeam
  2. 遍历 Team.FormationsIncludingEmpty（与 F6 完全一致）
  3. 每个调用 f.SetControlledByAI(true, false)
  4. 返回每个编队调用前后 IsAIControlled
```

### Zero-touch 3/3 验收（用户原始要求，逐条）

无人操作情况下连续 3 轮满足：

1. 进入 Mission
2. Deployment 确实结束（显式判定，非秒数）
3. 战斗阶段进入真实交战流程
4. Formation 至少出现一种真实动态状态变化
5. CombatBrain telemetry 持续产生
6. CBATH timeline 正常连续采样
7. **不需要触碰鼠标键盘**
8. 运行结束无残留进程

建议流程：`h3_provider_start → h3_start_from_screen → auto_finish_deployment → delegate_team_to_ai → 采样验证 → end_mission → games_stop → cleanup`，每轮存档 `evidence\runs\<run>.json`。

---

## 五、必须固化的测试规则（P2-007 教训，写入验收）

> **进入 MissionScreen ≠ 战斗已经开始。**

- `ExecuteStart` 只把玩家带到**部署界面**（`重置部署`/`准备` 按钮仍在，兵力全满）。
- 指挥官模式下**无人下令则部队完全不动**。
- 判定"真开战"**不得**用：ExecuteStart 成功、mission_time 增长、Formation 是否移动。
- 判定"真开战"必须用**显式状态**（任一）：
  - `movement_order` 出现非 `StandYourGround`（如 `Move`/`Charge`）
  - `unit_count` 开始下降（伤亡）
  - `active_behavior` / `arrangement_order` 出现真实变化
  - CombatBrain 日志 phase 进入 `Advance`/`Engage`

**多动态量联合判据（P2-005 确立）**：不得以 `Formation.CurrentPosition` 单字段判定模拟推进（它是锚点，可长时间不动）。

---

## 六、环境操作要点（踩过的坑，务必遵守）

1. **启动游戏前必须 `safely_exited = 1`**
   `Documents\Mount and Blade II Bannerlord\Configs\engine_config.txt`。为 0 会弹 Safe Mode 对话框静默阻断 Mod 加载。强杀游戏会写回 0，每次启动前都要复位（build-deploy.ps1 已内置）。

2. **Steam 必须在运行且 API 就绪**：否则游戏抛 `Unable to initialize Steam API` 并退出（表现：进程存活但 CPU/内存异常低、无日志）。
   - 陷阱：`Get-Process -Name 'steam'` 会前缀匹配命中 `steamwebhelper` 孤儿进程而误报"在运行"——**必须精确匹配 `ProcessName -eq 'steam'`**。
   - 游戏崩溃会**带走 steam.exe 主进程**，启动前需检查并重启，等 45s+。

3. **模块集一变就弹 `"Mod change detected"` 对话框**（删 shader 缓存提示），静默阻断加载，需按 Enter。定位窗口 → SetForegroundWindow → PostMessage VK_RETURN（已有经验，可用 Win32 枚举）。

4. **崩溃报告对话框由 `csrss.exe` 承载**，不在游戏 PID 下。按游戏 PID 枚举窗口找不到它，必须枚举全部可见窗口。

5. **不要在 `games_start` 之后修改 `.dsh\dshmm\mcp.json`**——会触发 DSH 重载 MCP 服务器，杀掉 gabs 及其游戏。

6. **GABS 工具列表是 connect 时快照**：部署新 DLL 后必须重新 `games_connect`（返回 `Re-synced N tools`），否则报 not found。

7. **主 DLL 文件锁**：强杀游戏后 DLL 可能被僵尸进程（`HasExited=true` 但句柄不释放）锁定。build-deploy.ps1 已忽略 `HasExited=true`。应急：备用 DLL 名 + 改 SubModule.xml 的 DLLName（事后恢复）。

8. **Go 构建 GABS**：`GOPROXY=https://goproxy.cn,direct` + `GOSUMDB=off`（本机 TLS 校验问题）。

9. **开场动画已消除**（移走 `Modules\Native\Videos\TWLogo_and_Partners.*` 到 `_intro-video-hidden\`）。Steam 校验会恢复，重新移走即可，不算失败。

10. **CombatBrain 日志在 `%TEMP%\CombatBrain.log`**（约 64 MB），**不是** ModLogs。做关联时用 **byte offset 只读新增部分**（`tools\cb-legacy-offset2mission.ps1`），不要整份扫描。

11. **游戏窗口失焦不暂停模拟**（`StopGameOnFocusLost=False`），但为稳妥，采样窗口仍建议保持前台（`tools\focus-bannerlord.ps1`）。注意：**焦点操作要放在所有工具调用之后**，因为后续任何调用会抢走前台。

---

## 七、已知技术债（需在报告中如实披露）

1. **`ExecuteStart` 靠反射取私有字段 `_dataSource`**——UI 重构即失效。长期需 provider 侧免反射入口。
2. **21.7% correlation mismatch 未解释**（P2-007：129 变化中 28 个无对应命令）。用户已决定**暂不研究**。
3. **采样频率固定 1 Hz**：用户明确要求，**5 Hz 只在未来 CombatBrain 2.0 行为测试证明 1 Hz 不够时再引入**。
4. **`closest_enemy_formation_index` 无稳定 ID**：引擎 `FormationQuerySystem` 不暴露 `FormationIndex`，当前输出 `unavailable:no_stable_formation_id`。**不要**建立稳定 ID 系统，保留为缺口。
5. **战斗配置非显式指定**：使用 CustomBattle 默认配置。P1-005 三轮兵力一致，但更早观测不一致，未定论。
6. **CombatBrain 是旧版临时测试载荷**：CBATH 不得依赖其内部类/枚举/日志格式。CBATH 核心零 CombatBrain 引用（已 grep 验证）。
7. `git_commit` 未注入 build identity（工作区不在 git 仓库）。
8. GABS 二进制未走 `make build`，无 version/commit ldflags。

---

## 八、汇报格式要求

每个交付按：

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

---

## 九、严格边界（prompt 原文，不得越界）

- 不修改 CombatBrain 2.0 主工程。
- 不移植全量 Bannerlord.GABS 到 1.4.8。
- 不引入第三方 mod。
- 不修改 CombatBrain 源码/二进制。
- CBATH 核心不引用 CombatBrain 类型。
- 不做自动命令来源归因（attribution），只做时间关联（correlation）。
- 不做骑兵包抄等具体行为测试。
- 不提高采样频率（保持 1 Hz）。
- 不建稳定 Formation ID 系统。
- 本阶段不处理 21.7% mismatch。

---

## 十、交接时环境状态（2026-09-25 01:30 实测）

| 项 | 值 |
|---|---|
| Bannerlord 活进程 | 0 |
| steam.exe | 1 |
| gabs 实例 | 1（DSH 会话，pid 请用 `Get-CimInstance Win32_Process -Filter "Name='gabs.exe'"` 确认） |
| safely_exited | 1 |
| CombatBrain.log | 64,236,613 bytes（关联时从新 offset 开始） |
| CBATH 部署 | `b20260925-002732-a6df5e05`（未含两个新工具，实现后需重新 build-deploy） |
| 当前模块集 | 见第一节（含 CombatBrain，勿改） |

### 交接时未完成的事（你的起点）

1. **实现** `cbath/auto_finish_deployment` + `cbath/delegate_team_to_ai`（依据 P2-009 已确认的 API）
2. **单独验证**两个工具（工具自返回调用前后状态，由断言确认）
3. **Zero-touch 3/3** 无人值守验收（流程见第四节）
4. 完成后写 `P2-010-result.md` 或同类证据文档
