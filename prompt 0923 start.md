# CombatBrain Autonomous Test Harness

## Phase 0：前期研究、架构设计与实验定义

你现在担任本 RD 的：

**Research Lead / System Architect**

你当前**不负责大规模编码实现**。

后续主要 Implementation Agent 将是：

**DeepSeek V4.1 + DeepSeek Harness**

你的任务是先把技术路线研究清楚、验证关键事实、找出真正的风险，并给 DeepSeek 设计一个足够明确、可以逐项执行和验证的 Phase 1 实验方案。

---

# 1. 项目目标

我们正在开发：

**CombatBrain Autonomous Test Harness**

目标是逐步让 AI Agent 可以自主完成 Mount & Blade II: Bannerlord Mod 的测试闭环：

```text
修改代码
→ build
→ deploy
→ 启动 Bannerlord
→ 进入固定测试场景
→ 运行战斗
→ 获取结构化状态 / telemetry
→ 判断测试结果
→ 退出游戏
→ 修改代码
→ 再次测试
```

最终目标不是完全排除人类评价，而是：

> 用户不再承担普通测试执行工作，只处理少量主观体验验收和自动系统无法可靠判定的案例。

---

# 2. 项目背景

目标游戏：

**Mount & Blade II: Bannerlord**

CombatBrain 当前目标游戏版本：

**EA v1.4.8.119303**

CombatBrain 2.0：

* C# / .NET
* 战斗 AI Mod
* 允许使用 Harmony
* 长期可能接管或干预：

```text
Tactic
→ FormationAI
→ Behavior
→ Order
```

长期测试对象包括：

* Formation 行为
* AI tactical plan
* Order 来源
* 包抄
* 骑兵冲击与重组
* 弓兵保护
* 阵型完整性
* 指令抖动
* 原生 AI 与 CombatBrain 抢控制权
* 性能
* 战斗结果
* telemetry

但当前 Phase 0 **不处理这些具体战术功能**。

---

# 3. 你的角色边界

当前阶段你负责：

1. 搜索和研究已有方案；
2. 阅读实际源码，而不仅仅是 README；
3. 验证关键技术事实；
4. 比较候选架构；
5. 识别未知项和高风险点；
6. 设计最小 Phase 1 实验；
7. 为 DeepSeek Implementation Agent 编写可执行规格。

当前阶段原则上不要：

* 大规模修改 CombatBrain；
* 重构 CombatBrain；
* 实现完整 Test Harness；
* 一口气完成所有自动化测试；
* 开发 GUI；
* 做具体战术修复；
* 设计复杂 evaluator；
* 为尚不存在的问题预先造大量抽象层。

如确有必要，可写：

* 极小 PoC；
* 接口草图；
* 伪代码；
* 用来验证 API 的最小实验代码。

但所有代码都必须服务于验证某个明确技术假设。

---

# 4. 第一项任务：研究现有实现

必须主动上网研究。

不能依靠已有印象。

重点研究以下项目。

---

## A. Bannerlord.GABS

这是当前最重要的候选基础设施。

需要从源码确认：

### 系统结构

分析：

```text
AI Agent
→ MCP
→ GABS
→ protocol / transport
→ Bannerlord.GABS
→ Bannerlord API
```

明确各组件职责。

### MCP 层

研究：

* MCP Server 在哪里；
* 暴露哪些 tools；
* tool schema；
* Agent 如何建立连接；
* 是否支持：

  * Codex
  * Claude Code
  * generic MCP client
  * DeepSeek Harness

### 游戏通信

确认：

* 使用什么 transport；
* TCP / socket / IPC / stdio？
* 谁是 Server；
* 谁是 Client；
* connection 生命周期；
* reconnect；
* error handling；
* timeout。

### Game API

重点检查实际源码是否可以：

* 启动游戏；
* 连接游戏；
* 获取游戏状态；
* 操作 Mission；
* 获取 Team；
* 获取 Agent；
* 获取 Formation；
* 获取 battle state；
* 获取 movement order；
* 获取 arrangement order；
* 获取 firing order；
* 使用 console command；
* 创建/进入 Mission。

不要因为 README 声称存在就视为已验证。

对每项标记：

```text
SOURCE VERIFIED
DOC ONLY
INFERRED
NOT FOUND
```

---

## B. BannerlordTestingEssentials

研究其历史实现。

重点回答：

1. 它试图解决什么；
2. 外部测试进程怎样和 Bannerlord 通信；
3. 如何做 system / integration test；
4. 为什么后来没有成为标准测试方案；
5. 哪些设计思想仍然值得使用；
6. 哪些部分已经被 GABS 或其他项目替代。

不要因为项目老就直接忽略。

---

## C. Bannerlord-Coop

重点研究仓库当前是否存在：

```text
MissionTests
IntegrationTests
E2E.Tests
debug commands
runtime testing
MCP
automation
```

尤其关注一个问题：

> Bannerlord-Coop 的开发者是怎样构造可重复的游戏内测试状态，而不是每次让人手工点进游戏测试？

找实际源码和文档证据。

---

## D. DeepSeek Harness MCP

研究 DeepSeek Harness 当前官方实现。

确认：

* MCP client 是否官方存在；
* transport 类型；
* tool registration；
* tool timeout；
* process lifecycle；
* session；
* long-running process；
* error propagation；
* MCP server crash 后行为；
* 是否适合长时间控制一个 Bannerlord instance。

最终回答：

> DeepSeek Harness 是否能够作为 Phase 1 的主控制 Agent？

注意：

DeepSeek Harness 当前如果仍属于 preview / fast-changing 项目，需要专门评估：

**如何避免 Test Harness 与 DeepSeek Harness 内部实现强耦合。**

---

## E. Windows Computer Use

研究一至两个成熟的 Windows automation / computer-use MCP 项目。

只回答：

* 能提供哪些能力；
* 哪些 Bannerlord 操作可能必须靠 GUI；
* 是否可以启动程序；
* screenshot；
* mouse / keyboard；
* OCR；
* process management；
* crash dialog handling。

当前架构原则：

```text
Structured Game API
>
Console / Debug API
>
OS Process Control
>
Computer Vision / Mouse Automation
```

不要反过来设计。

---

# 5. 最大风险：Bannerlord 版本兼容性

CombatBrain 当前目标：

**v1.4.8.119303**

必须确认：

### Bannerlord.GABS

* 当前开发针对哪个 Bannerlord 版本；
* Release 针对哪个版本；
* 使用哪些 TaleWorlds API；
* 哪些 API 在 1.4.8 发生变化。

### ReferenceAssemblies

查证是否存在精确版本：

```text
Bannerlord.ReferenceAssemblies
1.4.8.119303
```

以及至少：

* Core
* Native
* SandBox
* CustomBattle

如果存在：

分析是否可以：

```text
fork GABS
→ 更换 ReferenceAssemblies
→ build
→ 修 breaking API
```

不要只回答“理论上可以”。

尝试通过源码 diff / API usage 判断移植规模。

给出：

```text
LOW
MEDIUM
HIGH
UNKNOWN
```

风险评级。

但不要伪造具体开发工时。

---

# 6. 核心技术问题

逐项回答。

## Q1

Agent 能否不依赖用户手工操作启动 Bannerlord？

研究：

* Steam URI；
* TaleWorlds Launcher；
* 直接 Bannerlord.exe；
* Bannerlord.Native.exe；
* launch arguments；
* module arguments；
* CustomBattle；
* debug configuration。

区分：

```text
启动进程
```

与：

```text
游戏真正进入可测试状态
```

必须设计 health check。

---

## Q2

Agent 如何判断游戏当前状态？

期望至少有：

```text
NotRunning
Starting
MainMenu
Campaign
CustomBattle
MissionLoading
MissionRunning
MissionEnded
Crashed
Disconnected
```

研究现有 API 能否做到。

如果不能：

指出缺口。

---

## Q3

如何自动进入一个固定 Battle？

调查所有候选方案：

### Route A

通过游戏已有 Custom Battle API。

### Route B

通过 console / debug command。

### Route C

建立专门 Test Mod / Test Mission。

### Route D

直接调用 Mission 创建 API。

### Route E

必要时 GUI automation。

比较：

* 可重复性；
* 实现复杂度；
* 对游戏版本敏感度；
* 测试速度；
* determinism；
* 稳定性。

必须给出明确推荐路线。

---

## Q4

能否读取双方 Formation？

目标至少：

```text
team
formation index
formation class
unit count

position / centroid
facing

movement order
arrangement order
firing order

AI controlled
```

特别检查：

> GABS 当前是否只暴露 PlayerTeam？

如果是：

研究扩展到：

```text
Mission.Current.Teams
→ every Team
→ every Formation
```

的难度。

---

## Q5

是否可以读取 CombatBrain 自己的内部状态？

例如：

```text
current plan
current tactic
current behavior
plan age
target formation
order source
```

分析两种方案：

### Pull

外部 Test Harness 主动读取 CombatBrain。

### Push

CombatBrain 主动发送 telemetry/event。

比较两者。

原则上不要为了测试把 CombatBrain 内部对象完全暴露。

设计最低必要接口。

---

# 7. 特别研究：Order Provenance

CombatBrain 曾经存在一个核心问题：

> 原版 AI 与 Mod 同时向 Formation 下指令，出现控制权抢占。

因此自动测试体系如果可能，应支持回答：

```text
这一条 MovementOrder 到底是谁写的？
```

研究是否能做到类似：

```text
timestamp

formation

old order
new order

source:
NativeTactic
NativeBehavior
CombatBrain
Player
Unknown
```

调查：

* 是否可以 Harmony patch Order setter；
* Formation.SetMovementOrder；
* Behavior Tick；
* Tactic；
* Player command；
* call stack；
* explicit context tagging。

不要现在实现复杂系统。

先判断：

**技术上能否可靠记录 order provenance。**

如果不能完全可靠：

说明限制。

---

# 8. 可重复性 / Determinism

研究 Bannerlord Mission 的：

* Random；
* MBRandom；
* seed；
* spawn order；
* physics；
* AI tick；
* timing；
* frame dependent behavior。

目标不是要求每场逐帧一致。

需要回答：

1. 哪些因素可以固定；
2. 哪些因素无法固定；
3. 哪些测试适合 deterministic test；
4. 哪些只能使用 statistical regression。

例如：

```text
20 runs

17/20 satisfy condition
```

可能比：

```text
每次结果完全相同
```

更加合理。

---

# 9. 设计最小架构

在完成研究后设计 Phase 1 MVP。

优先保持简单。

候选结构：

```text
DeepSeek Harness
        │
        │ MCP
        ▼
Test Controller
        │
        ▼
Bannerlord Bridge
        │
        ▼
Bannerlord
```

其中 Test Controller 是否直接采用 GABS，需要研究决定。

可以是：

```text
DSH
→ existing GABS MCP
→ extended Bannerlord.GABS
```

也可以：

```text
DSH
→ thin CombatBrain MCP
→ GABS
```

或者其他结构。

必须比较后选择。

原则：

### 1. Harness independence

测试系统不应该只能被 DeepSeek Harness 使用。

理想情况下：

```text
DeepSeek Harness
Codex
Claude Code
future agent
```

都可以通过相同 MCP 接口使用。

### 2. Bannerlord-specific logic 留在游戏端

不要让 MCP Controller 猜游戏内部对象状态。

### 3. 最小化 CombatBrain coupling

Phase 1 应该可以：

> 不加载 CombatBrain 也完成基本测试。

---

# 10. Phase 1 MVP 必须极小

不要设计“完整自动测试平台”。

Phase 1 只验证：

```text
Agent
↓
启动 Bannerlord
↓
确认游戏 Ready
↓
建立通信
↓
进入固定 Mission
↓
读取双方 Formation
↓
结束 Mission
↓
退出游戏
↓
重复
```

成功标准：

**连续执行 3 次。**

每次必须记录：

```text
run id
game process id
game build/version
loaded modules
connection status
mission status
formation snapshot
exit result
```

---

# 11. 必须防止“其实跑的不是新代码”

未来 Test Harness 会用于：

```text
modify
→ build
→ deploy
→ rerun
```

这是自动调试中最危险的问题之一。

必须提前设计 Build Identity。

至少考虑：

```text
Git commit
build timestamp
assembly version
DLL hash
unique build ID
runtime log marker
```

设计一种明确方式，使 Agent 能证明：

> 当前 Bannerlord 实例加载的是刚刚 build 的 DLL。

不能：

> build success
> → 默认新版本正在运行。

---

# 12. Fault Handling

只设计 Phase 1 必要能力。

至少考虑：

```text
game failed to launch
game crashed
MCP disconnected
mission failed to load
loading timeout
stale Bannerlord process
DLL locked
crash reporter
launcher dialog
```

针对每种情况给出：

```text
Detection
Recovery
Abort condition
```

避免无限 retry。

---

# 13. 未来 Test API 草案

不要全部实现。

仅设计接口。

例如：

```text
game.start
game.stop
game.status

mission.start_test
mission.status
mission.stop

battle.get_state

formation.list
formation.get_state
```

未来 CombatBrain extension：

```text
cb.get_status
cb.get_plan
cb.get_plan_history
cb.get_order_history
cb.get_telemetry
```

接口设计原则：

* machine readable；
* deterministic schema；
* 不输出大量自然语言；
* 明确 timestamps；
* 明确 IDs；
* 避免 Agent 根据名字猜实体；
* 支持单场测试和批量测试。

---

# 14. 不要现在定义具体战术 PASS/FAIL

现在不要给：

* 长蛇；
* 包抄；
* 骑兵；
* 弓兵；
* 阵线；
* 胜率；

随便制定阈值。

Phase 0 只研究：

> 我们未来怎样获取足够的数据来定义这些断言？

---

# 15. 研究方法要求

对关键结论标注证据类型：

```text
[CODE]
源码确认

[DOC]
官方文档

[RUN]
实际实验结果

[ISSUE]
维护者 Issue / Discussion

[INFERENCE]
基于代码推断

[UNKNOWN]
尚未验证
```

重大架构决策不得只依赖 `[INFERENCE]`。

---

# 16. 防止过度研究

这是强制要求。

不要因为某个细节有趣，就连续深入它而忽略整个研究范围。

维护：

```text
Research Coverage Matrix
```

至少包含：

| Area                           | Status | Evidence | Blocking? |
| ------------------------------ | ------ | -------- | --------- |
| GABS architecture              |        |          |           |
| GABS game API                  |        |          |           |
| Bannerlord 1.4.8 compatibility |        |          |           |
| DSH MCP                        |        |          |           |
| Game launch                    |        |          |           |
| Mission creation               |        |          |           |
| Formation observation          |        |          |           |
| Process lifecycle              |        |          |           |
| Determinism                    |        |          |           |
| Build identity                 |        |          |           |

如果一个问题已经拥有足够信息支撑 Phase 1：

**停止继续深入。**

不要为了“完全搞懂”而无限研究。

---

# 17. 遇到不会的问题

如果遇到：

* 不熟悉 API；
* 不确定的 Bannerlord 行为；
* 找不到文档；
* MCP 机制不明确；
* Harmony 是否可行不确定；

优先：

```text
搜索
→ 查源码
→ 查官方/维护者资料
→ 写最小实验
```

不要自己脑补。

如果仍无法解决：

记录：

```text
OPEN-XXX
Question
Why it matters
Evidence checked
Current hypotheses
How to test later
```

然后继续研究其他项目。

所有 unresolved question 最后集中处理。

---

# 18. 新概念披露

如果你自己创建：

* 新名词；
* 新模块；
* 新缩写；
* 新协议；
* 新 testing layer；

第一次出现时立即说明：

1. 名称；
2. 是现有术语还是本项目新定义；
3. 解决的问题；
4. 为什么需要。

不得在后续文档中突然出现一批用户没见过的概念。

---

# 19. 输出目录

建立独立 RD：

```text
RD/
└─ CombatBrain-Autonomous-Test-Harness/
```

Phase 0 至少输出：

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
```

如进行了 PoC：

```text
experiments/
```

必须与 CombatBrain 主工程隔离。

---

# 20. 最终需要给出的明确判断

不要只总结资料。

Phase 0 完成后必须回答：

## Feasibility

以下闭环：

```text
Agent
→ build
→ deploy
→ start Bannerlord
→ enter battle
→ observe battle
→ collect telemetry
→ stop
→ modify
→ rerun
```

分别哪些部分：

```text
READY
NEEDS EXTENSION
NEEDS NEW DEVELOPMENT
HIGH RISK
UNKNOWN
```

---

## Architecture

给出你推荐的唯一主路线。

可以保留备选方案，但必须明确：

> Phase 1 应采用哪一种。

---

## GABS

明确回答：

1. 是否应该基于 GABS；
2. fork 还是 dependency；
3. 哪些组件直接复用；
4. 哪些需要修改；
5. 是否要 upstream；
6. 1.4.8 的主要兼容风险。

---

## DeepSeek Harness

明确回答：

> 是否适合作为后续 Implementation / Testing Agent？

如果适合：

明确其职责边界。

---

## Computer Use

明确回答：

> Phase 1 是否需要？

如果不需要：

不要为了“以后可能用到”而加入。

---

## Phase 1

给出一个非常具体的 Implementation Plan。

最好拆成：

```text
P1-001
P1-002
P1-003
...
```

每项包含：

```text
Goal
Files / components involved
Implementation idea
Verification method
Pass condition
Failure meaning
Dependencies
```

DeepSeek 应该可以直接依据这些任务开始工作。

---

# 21. 最重要的停止条件

你的工作不是把整个 Test Harness 开发完成。

当你已经能够回答：

> “DeepSeek 下一步到底应该写什么、为什么这样写，以及怎样证明它成功。”

Phase 0 就应该停止。

此时不要继续扩大范围。

提交：

```text
Research Findings
Architecture Decision
Phase 1 Experiment Plan
Known Risks
Open Questions
DeepSeek Handoff
```

等待下一次架构审核。

---

# 最终原则

这个 RD 的优先级不是：

> 做出最多功能。

而是：

> 尽快用实际证据证明或者推翻关键技术假设。

尤其优先验证：

```text
1. GABS 是否真的适合成为基础。
2. 1.4.8.119303 是否可以支持。
3. DSH 是否能稳定通过 MCP 控制它。
4. 是否可以无需人工进入固定 Mission。
5. 是否可以读取双方 Formation。
```

只要其中任何一个基础假设失败，都应尽早发现，而不是等整个系统已经建立在它上面之后再发现。
