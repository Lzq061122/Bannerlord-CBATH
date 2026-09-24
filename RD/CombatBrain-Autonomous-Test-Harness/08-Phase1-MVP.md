<!-- PROMPT META
Name: CombatBrain Autonomous Test Harness Phase 1 MVP Experiment Specification
Version: 1.0
Author Role: Research Lead / System Architect
Model: GPT-6
Created: 2026-09-23
Updated: 2026-09-23
Target: DeepSeek V4.1 + DeepSeek Harness
Scope: CombatBrain Autonomous Test Harness / Phase 1
-->

<!-- CHANGE LOG (newest first, keep last 3)
v1.0 2026-09-23 23:23 | role=Research Lead / System Architect | model=GPT-6 | editor=combatbrain-ath-phase0-root | note=定义 P1-001 至 P1-006 的目标、验证方法、通过与失败判据
-->

# Phase 1 最小实验与验收

Phase 1 的唯一 GO：Agent 连续 3 次完成**真实** Bannerlord 进程启动→GABP Ready→固定 Mission→双方 Formation 快照→结束 Mission→退出进程，并留下可复查运行证据。编译探针或模拟测试不计入这 3 次。

## 通用运行记录

每次生成一个唯一 `run_id`，保存：开始/结束 UTC、PID、Steam game build ID、Native 版本、加载模块列表、测试 Mod 的嵌入 build ID 与 Assembly MVID、构建/部署 DLL SHA-256、GABP 连接状态、状态变更时间线、scene/Mission 时间、双方所有非空 Formation 快照、退出码或退出状态、出错时进程/连接/游戏日志位置。每个阶段设置有界超时；超时后记录现场并清理本次 PID，最多一次受控重试，不能无限循环。阈值需在运行前按本机启动基线设定并写入实验记录。

## P1-001 — 最小游戏端 Mod 编译与构建身份

- **Goal**：只提供 `ping`、游戏状态、build identity 和后续工具的空骨架；不修全量 GABS 的无关 29 处错误。
- **Files/components**：本 RD `experiments/test-mod/`（新建）；Lib.GAB NuGet；`Bannerlord.ReferenceAssemblies 1.4.8.119303`；独立 `SubModule.xml`。不得修改 CombatBrain 主工程。
- **Implementation idea**：用 Lib.GAB 注册工具，游戏主线程派发与生命周期参照 GABS 已审计的做法。构建时嵌入唯一 build ID；部署前对 DLL 求 SHA-256。游戏端响应报告嵌入 ID、`Assembly.ManifestModule.ModuleVersionId`、`Assembly.Location` 与该路径文件 hash。
- **Verification**：构建 0 error；部署后从真实进程调用 status 工具，嵌入 ID/MVID 与刚构建的产物匹配，部署路径 SHA 与构建路径 SHA 匹配。
- **Pass**：源码、构建 DLL、部署 DLL、运行时标识四者可归因同一构建。
- **Failure meaning**：编译失败=API/依赖问题；进程可连但 ID 不匹配=旧 DLL/加载路径错误，**中止后续测试**。
- **Dependencies**：无；现有 [编译探针](experiments/formation-api-probe/FormationApiProbe.cs) 仅是 API 先导证据。

## P1-002 — DeepSeek Harness ↔ GABS ↔ Test Mod 联调

- **Goal**：验证官方 DSH MCP client 能注册并调用 GABS 工具，连接游戏端 GABP。
- **Files/components**：本地 DSH MCP 配置、GABS 配置、P1-001 的 Mod。业务代码不得调用 DSH 私有插件 API。
- **Implementation idea**：本机 stdio entry 启动 GABS；用 `games.list/status/start/connect/call_tool/stop`。DSH 和 GABS 超时分别配置，慢操作拆为短调用+轮询。
- **Verification**：保留 DSH tool-call transcript 和 GABS 日志；确认 `games.tool_names` 发现自定义工具、调用 ping/status 得到真实 game-side 响应；故意断开一次测试重连与错误传播，独立于正式 3 轮记录。
- **Pass**：端到端调用可重复，超时/断线不被报告成成功。
- **Failure meaning**：若 DSH 客户端限制阻挡，先以通用 MCP client 对照测试，隔离 DSH 问题与游戏桥问题；记录后继续可验证工作。
- **Dependencies**：P1-001。

## P1-003 — 游戏生命周期 Experiment A

- **Goal**：验证 Agent 可启动、确认 Ready、获取状态、正常退出。
- **Files/components**：GABS launch 配置/脚本、状态工具、进程日志。
- **Implementation idea**：按本机游戏目录配置 launcher 或直接 exe；显式模块列表。Ready 同时要求目标 PID 存活、GABP 已连、ping 成功、游戏状态非 unknown。停止后确认 PID 消失；正常退出失败才按 PID 强制清理，并记录原因为异常结束。
- **Verification**：连续 3 次 A-only 运行，每次记录 PID、加载模块、状态和退出；对 Safe Mode 对话框、crash reporter、残留进程做人工观测/日志核对。
- **Pass**：三次均在预设超时内 Ready 和正常退出，进程没有残留。
- **Failure meaning**：进程启动与游戏 Ready 分别定位；失败后保留启动器/游戏/GABS 日志，不凭“有 PID”判通过。
- **Dependencies**：P1-002；A-only 三轮不等于完整 MVP 三轮。

## P1-004 — 固定 Mission Experiment B

- **Goal**：无需用户操作进入同一个固定 Mission，读 scene/elapsed time 后结束。
- **Files/components**：优先检查游戏实际 console 命令；不足时在独立 Mod 中增加 `test/start_fixed_mission` 与 `test/end_mission`，小规模固定场景配置。
- **Implementation idea**：先记录 `core/list_commands` 的真实结果，再决定能否调用现成命令；无法固定双方/地图则用专用游戏端 Mission 创建工具。不得复制 BannerlordCoop 受限源码。
- **Verification**：状态时间线必须出现 MissionLoading→MissionRunning→MissionEnded/NoMission，记录同一 scene、双方存在、Mission 时间增长。
- **Pass**：固定配置可重复进入并退出；无手工鼠标/键盘操作。
- **Failure meaning**：命令只开菜单、没进入 Mission，或 Mission 卡 loading，均判失败；保留现场和超时分类。
- **Dependencies**：P1-003。

## P1-005 — 双方 Formation Experiment C

- **Goal**：真实战斗中读取所有 Team 的所有非空 Formation。
- **Files/components**：独立 Mod 的 `test/get_all_formations`；输出结构与固定场景。
- **Implementation idea**：以编译通过的 `Mission.Current.Teams → FormationsIncludingEmpty` 为基础，读取 side/TeamIndex、formation class/index、unit count、`CurrentPosition`、`Direction`、三个 `OrderController.GetActive*OrderOf`、`IsAIControlled`。所有游戏对象读取在主线程。输出 UTC 与 Mission time，保留 raw value 与可解释的 null。
- **Verification**：运行中连续采两帧以上，双方均至少一支非空 Formation；与游戏内可见单位/日志做一次人工对照；记录数量是否随战斗合理变化。游戏端不给 PlayerTeam 时也须覆盖所有实际 Team。
- **Pass**：双方完整字段有值且稳定关联 Team/Formation；没有仅玩家方数据。
- **Failure meaning**：任一侧漏报、index 冲突、状态字段不可读、无关联时间戳均不能 GO。
- **Dependencies**：P1-004；本轮静态编译通过不替代运行验收。

## P1-006 — Build→Deploy→Run 与完整三轮 Experiment D

- **Goal**：从一次可观察参数修改开始，证明新构建确实在运行，并连续完成 3 次完整 MVP。
- **Files/components**：独立实验 Mod、构建/部署脚本、运行记录与汇总脚本。
- **Implementation idea**：改一个返回值或嵌入 marker→build→部署→检查 DLL hash→启动→调用状态证实新 marker/MVID→固定 Mission→读取双方 Formation→退出。三轮均重新启动进程；不得用上一轮数据填空。
- **Verification**：自动检查每轮所有字段、阶段顺序、PID 区分、退出/残留、身份一致；每轮保留完整原始日志和机器可读结果。第三轮完成后立即停止扩功能。
- **Pass**：连续 3/3 次无用户参与，均满足完整链路和构建身份；没有一次异常退出、超时、缺失双方数据或身份不一致。
- **Failure meaning**：任何一次失败都保留该轮、计数归零并按原因修复；不能挑成功的三轮拼接为“连续三次”。
- **Dependencies**：P1-005。

## 之后的边界

Phase 1 GO 后提交运行日志、快照、未验证能力、技术债和下一阶段建议供用户架构审核。审核前不接入 CombatBrain 大规模战术状态或批量评价器。用户仍需审阅战斗自然度、主观观感及自动断言无法可靠判定的案例；基础启动/运行/观测执行不应继续由用户承担。
