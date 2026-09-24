# CombatBrain Autonomous Test Harness — Phase 1 Implementation

你现在负责继续一个已经完成 Phase 0 研究的独立 RD：

**CombatBrain Autonomous Test Harness**

工作区：

```text
E:\MBmod\CombatBrain Autonomous test harness
```

首先阅读：

```text
E:\MBmod\CombatBrain Autonomous test harness\RD：CombatBrain Autonomous Test Harness.md
```

然后阅读该工作区内现有的 Phase 0 研究产物、实验代码与 evidence。

预计包括：

```text
00-Executive-Summary.md
01-Problem-and-Goals.md
02-Existing-Solutions.md
03-GABS-Source-Audit.md
04-Bannerlord-1.4.8-Compatibility.md
05-DeepSeek-Harness-MCP-Audit.md
06-Mission-Automation-Options.md
07-Proposed-Architecture.md
08-Phase1-MVP.md
09-Risk-Register.md
10-Open-Questions.md
11-Implementation-Handoff.md

experiments/
evidence/
```

如果实际文件名或目录略有不同，以工作区实际内容为准。

---

# 一、你当前的角色

你现在是：

**Phase 1 Implementation Agent**

Phase 0 已由高阶模型完成研究与架构收敛。

你的主要职责不是重新做一遍大规模研究，而是：

> **根据现有证据，把最小自动测试闭环真正跑起来。**

如果实现过程中遇到 Phase 0 没有解决的具体问题，可以自行：

1. 查现有文档；
2. 查源码；
3. 上网研究；
4. 写最小验证实验。

但不要因为一个局部未知项重新扩展成大规模研究项目。

---

# 二、当前已知结论

Phase 0 当前结论：

## 总体可行性

存在现实技术路径，但完整闭环尚未运行验证。

当前推荐架构：

```text
DeepSeek Harness
        │
        │ MCP
        ▼
GABS / Test Controller
        │
        │ GABP / TCP
        ▼
Bannerlord Test Mod
        │
        ▼
Mount & Blade II: Bannerlord
```

目标游戏版本：

```text
EA v1.4.8.119303
```

当前已知：

* GABS 已有 MCP、游戏进程管理、GABP/TCP 通信和部分游戏状态工具。
* 原版 Bannerlord.GABS 面向较旧版本。
* 全量 Bannerlord.GABS 切换到 1.4.8.119303 ReferenceAssemblies 后存在约 29 个编译错误。
* **不要因此尝试完整移植整个 Bannerlord.GABS。**
* 1.4.8.119303 下，`Mission.Current.Teams` → 双方 Team / Formation 基础 API 已通过独立静态编译探针。
* GABS 当前 Formation 工具主要遍历 `PlayerTeam`，这是实现缺口，不代表底层 API 做不到。
* DeepSeek Harness 官方 MCP 客户端已经具备基本接入能力。
* 固定 Mission 无人值守创建仍未实际验证。
* 游戏完整生命周期仍未实际连续跑通。

---

# 三、本阶段唯一目标

Phase 1 不开发完整测试平台。

当前唯一目标是证明：

```text
Agent
→ 启动 Bannerlord
→ 确认加载正确 Test Mod
→ 建立通信
→ 进入固定 Mission
→ 读取双方 Formation
→ 结束 Mission
→ 退出游戏
→ 再次执行
```

最终验收：

> **上述流程能够连续成功执行 3 次，不需要用户手工参与普通测试操作。**

---

# 四、严格执行顺序

不要一次实现整个闭环。

按以下顺序逐项推进。

---

# P1-001 — Runtime Identity

## Goal

建立最小 Bannerlord 1.4.8 Test Mod，并证明：

> 游戏运行时真正加载了我们刚刚构建的 DLL。

这是后续所有自动调试的基础。

## 要求

建立尽可能小的独立测试 Mod。

不要接 CombatBrain。

不要实现战术功能。

运行时至少暴露或记录：

```text
module = CombatBrainAutonomousTestHarness
build_id
build_timestamp
git_commit（如果方便）
assembly_version
game_version
```

至少使用一个每次构建可明确变化的：

```text
build_id
```

### 验收条件

必须有运行时证据，例如日志：

```text
CBATH_RUNTIME_IDENTITY
build_id=...
game_version=...
```

不能只证明：

```text
dotnet build succeeded
```

必须证明：

```text
Bannerlord 实际加载了该 DLL
```

## 如果失败

停在这里。

不要继续实现 MCP、Formation 或 Mission。

先解决加载问题。

---

# P1-002 — Ping Bridge

只有 P1-001 PASS 后开始。

## Goal

证明：

```text
DeepSeek Harness
→ MCP
→ GABS / controller
→ Lib.GAB / protocol
→ 游戏里的 Test Mod
```

通信链真正工作。

## 最小接口

只需要：

```text
ping
get_build_identity
```

预期类似：

```json
{
  "status": "ok",
  "build_id": "...",
  "game_version": "1.4.8.119303"
}
```

不要在这里加入：

* Formation；
* CombatBrain；
* Battle telemetry；
* UI；
* Hero；
* Campaign。

### 验收条件

DeepSeek Harness 能主动调用工具，并收到来自**当前 Bannerlord 进程内 Test Mod** 的响应。

必须确认返回的：

```text
build_id
```

与当前刚 build/deploy 的 DLL 一致。

## 如果失败

停在 P1-002。

区分：

```text
MCP 问题
GABS/controller 问题
TCP/GABP 问题
游戏端 Mod 问题
```

不要靠猜。

---

# P1-003 — Runtime Formation Snapshot

只有 P1-002 PASS 后进行。

## Goal

验证 Phase 0 的静态编译结果在真实游戏运行时成立。

在一个真实 Mission 中遍历：

```text
Mission.Current.Teams
```

读取所有有效 Team 的非空 Formation。

至少返回：

```text
team_id / side

formation_index
formation_class

unit_count

position / centroid
facing

movement_order
arrangement_order
firing_order

is_ai_controlled
```

如果某字段在 1.4.8 API 中无法可靠获取：

不要伪造。

标记缺口并提供实际证据。

---

## 这一阶段允许一次人工 bootstrap

如果“自动进入 Mission”尚未实现：

允许用户手工进入一次 Custom Battle，用于验证 Formation Runtime API。

这是开发自动化工具时的 bootstrap，不代表最终方案允许人工参与。

但：

> 只能用于验证 P1-003。

不要因此把人工操作写进最终 Test Harness 架构。

### 验收条件

实际运行中成功读取：

* 至少两个不同 Team；
* 双方至少一个非空 Formation；
* 上述核心 Formation 状态。

保留原始返回结果和日志。

---

# P1-004 — Autonomous Mission

这是 Phase 1 当前最大的技术风险。

## Goal

无需用户手工点击：

> Agent 能进入一个固定、真实、可观测的 Battle Mission。

首先阅读 Phase 0：

```text
06-Mission-Automation-Options.md
```

使用其中已经比较过的候选路线。

优先级原则：

```text
Game API / Test Mission
>
Console / Debug API
>
Process automation
>
Computer Use / 鼠标点击
```

暂时不要引入 Computer Use，除非结构化路线已经被实际证据证明不可行。

---

## 测试场景

第一版不追求复杂。

只需要一个固定战斗：

```text
Team A
vs
Team B
```

能够产生双方 Formation 即可。

人数、兵种、地图先选择最简单稳定方案。

不要现在设计 CombatBrain 正式 benchmark。

---

## 需要确认

Agent 必须能够判断：

```text
MissionLoading
MissionRunning
MissionEnded
```

不要：

```text
调用创建函数
→ sleep 10 秒
→ 假设已经进入
```

必须存在实际状态检查。

### 验收条件

Agent：

```text
启动/连接游戏
→ 创建固定 Mission
→ 确认 MissionRunning
→ 调 Formation Snapshot
→ 得到双方数据
→ 正常结束 Mission
```

整个过程不需要用户点击。

---

# P1-005 — Three-Run Lifecycle

只有前四项全部 PASS 后进行。

## Goal

验证整个体系不是“偶然成功一次”。

执行完整流程：

```text
START
↓
确认 Runtime Identity
↓
建立通信
↓
进入固定 Mission
↓
读取双方 Formation
↓
结束 Mission
↓
退出 / cleanup
```

连续：

```text
3 次
```

---

## 每次必须记录

```text
run_id

game_process_id

game_version

test_mod_build_id

loaded module identity

MCP connection result

game connection result

mission state transitions

formation snapshot

mission exit result

game exit result

cleanup result
```

---

## PASS 条件

连续三次均：

* 使用正确 build；
* 成功启动；
* 成功通信；
* 成功进入 Mission；
* 成功读取双方 Formation；
* 成功退出；
* 无需用户介入。

达到后：

> **Phase 1 MVP PASS。**

立即停止扩大实现范围。

---

# 五、严格禁止提前做的内容

Phase 1 MVP 成功之前，不要实现：

```text
CombatBrain telemetry
CombatBrain plan state

Order provenance

Vision evaluator

录像分析

自动战术 PASS / FAIL

弓兵保护指标

骑兵包抄指标

阵型长蛇指标

胜率测试

100 场 batch

复杂 Scenario DSL

GUI

Dashboard
```

也不要：

> 为了修原版 Bannerlord.GABS 的 29 个错误，把整个 GABS 全量移植到 1.4.8。

只修当前 MVP 实际依赖的最小代码面。

---

# 六、不要修改 CombatBrain 主工程

本阶段必须保持：

```text
CombatBrain Autonomous Test Harness
```

与：

```text
CombatBrain 2.0
```

逻辑隔离。

除非真正出现没有其他方法验证的阻塞问题，否则不要修改 CombatBrain。

如果认为必须修改：

先记录：

```text
WHY
WHAT
MINIMUM CHANGE
ALTERNATIVES
```

再决定。

---

# 七、调试协议

任何出现：

> “代码改了但游戏行为没变化”

> “理论上应该执行但没有日志”

> “新接口看起来应该工作但没有响应”

必须严格按以下顺序排查。

---

## Stage 1 — 确认运行的是正确构建

检查：

```text
build_id
DLL timestamp
DLL hash
runtime identity
loaded module
```

不得直接分析业务逻辑。

---

## Stage 2 — 确认目标路径实际执行

加入唯一：

```text
log marker
assert
counter
runtime response
```

证明代码真的执行。

不得因为：

```text
理论上会经过
```

就认定经过。

---

## Stage 3 — 分析代码逻辑

只有前两项确认后，再分析：

* condition；
* lifecycle；
* object state；
* API；
* timing；
* concurrency。

---

# 八、禁止在同一证据上原地打转

同一个错误、日志、源码现象最多重复分析两轮。

如果两轮仍不能区分多个假设：

必须引入新的验证证据。

例如：

```text
unique marker
hash
additional logging
minimal reproduction
runtime counter
direct API probe
```

不要继续重复推测。

---

# 九、遇到未知问题时

如果遇到 Phase 0 没解决的问题：

例如：

* TaleWorlds API 不明确；
* GABS 行为不确定；
* MCP 接口行为不明确；
* Mission creation API 不知道怎么使用；

处理顺序：

```text
阅读现有 RD
↓
查相关源码
↓
查官方/维护者资料
↓
网上搜索
↓
最小实验
```

如果仍无法解决：

记录：

```text
OPEN-P1-XXX
Question
Blocking phase
Evidence checked
Current hypotheses
Next experiment
```

然后判断是否阻塞当前 Phase。

---

# 十、不要过度验证

这个 Phase 的目标非常窄。

如果某个问题已经有足够证据支持当前 MVP：

停止继续深挖。

例如：

如果已经证明：

```text
Formation.Position
```

在当前场景运行正确，

就没有必要立刻研究：

```text
所有 Formation 位置计算在所有游戏模式下的语义差异
```

除非它阻塞当前实验。

---

# 十一、新概念披露

如果你创建任何：

* 新模块；
* 新缩写；
* 新协议包装；
* 新工具；
* 新状态名；
* 新测试层；

第一次出现时立即说明：

1. 名称；
2. 是现有概念还是本项目新定义；
3. 解决什么问题；
4. 为什么现在必须引入。

禁止突然创造一堆内部术语后直接使用。

---

# 十二、保持工作记录

为每个实验保留：

```text
Goal
Hypothesis
Change
Command
Observed Result
PASS / FAIL
Evidence
Next Decision
```

不要只记录最终成功结果。

失败实验同样保留，因为它们可以防止之后重复走同一条错误路线。

---

# 十三、每完成一个 P1 阶段就更新状态

维护类似：

```text
P1-001 Runtime Identity      PASS / FAIL / BLOCKED
P1-002 Ping Bridge           PASS / FAIL / BLOCKED
P1-003 Formation Runtime     PASS / FAIL / BLOCKED
P1-004 Autonomous Mission    PASS / FAIL / BLOCKED
P1-005 Lifecycle ×3          PASS / FAIL / BLOCKED
```

不要同时把五项都写成“in progress”。

当前只允许一个主要 Implementation Step 处于 active 状态。

---

# 十四、Phase 1 完成后的交付物

至少输出：

```text
12-Phase1-Implementation-Report.md
13-Phase1-Runtime-Evidence.md
14-Phase1-Remaining-Risks.md
```

以及实际源码、日志、运行结果。

Implementation Report 必须明确区分：

```text
VERIFIED AT RUNTIME
VERIFIED BY BUILD ONLY
INFERRED
NOT TESTED
FAILED
```

---

# 十五、最终停止条件

一旦：

```text
P1-001 PASS
P1-002 PASS
P1-003 PASS
P1-004 PASS
P1-005 PASS
```

立即停止继续开发。

不要擅自开始：

```text
Phase 2
CombatBrain integration
Telemetry
Evaluator
Scenario framework
```

提交 Phase 1 结果供下一轮架构审核。

---

# 现在开始

第一步：

1. 阅读：

```text
E:\MBmod\CombatBrain Autonomous test harness\RD：CombatBrain Autonomous Test Harness.md
```

2. 阅读现有 Phase 0 交付物，尤其：

```text
00-Executive-Summary.md
08-Phase1-MVP.md
11-Implementation-Handoff.md
```

3. 检查：

```text
experiments/
evidence/
```

4. 确认当前工作区状态。

5. 从：

```text
P1-001 — Runtime Identity
```

开始。

不要重新开展一轮泛化研究。

不要先实现 P1-002～P1-005。

先证明 Test Mod 能够在 Bannerlord **v1.4.8.119303** 中真正加载，并留下不可混淆的 runtime build identity。
