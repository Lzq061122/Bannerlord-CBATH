# RD：CombatBrain Autonomous Test Harness

你现在负责启动一个独立 Research & Development 项目：

**CombatBrain Autonomous Test Harness**

该 RD 的目标不是开发 CombatBrain 2.0 的具体战术功能，而是研究并实现一套可以让 AI Agent **自主运行、观测、诊断和重复测试 Mount & Blade II: Bannerlord Mod** 的基础设施。

最终希望把当前人工流程：

> 修改代码 → 编译 → 启动游戏 → 人工进入战斗 → 人工观察 → 人工描述问题 → Agent 再修改

逐步变成：

> Agent 修改代码 → 编译 → 部署 → 启动 Bannerlord → 构造测试场景 → 运行战斗 → 获取结构化游戏状态 / 日志 / telemetry → 自动判断 → 关闭游戏 → 修改 → 重新测试

长期目标是：**用户不再承担日常测试执行工作，只保留少量主观体验验收和无法自动判断的边界案例。**

---

# 一、项目定位

这是一个独立 RD，不属于 CombatBrain 2.0 当前战术功能开发。

原则：

1. **先解决通用 Bannerlord 自动测试能力，再接 CombatBrain。**
2. 不因为 CombatBrain 当前已有实现而绑定具体架构。
3. 第一阶段不得大规模修改 CombatBrain 主工程。
4. 可以建立独立项目、实验 Mod、MCP Server、测试模块或 Bridge。
5. 优先复用已有社区方案，而不是从零重新实现。
6. 所有架构选择都必须说明：

   * 为什么需要；
   * 替代方案是什么；
   * 为什么采用当前方案。
7. 不确定的 Bannerlord API、版本兼容性、社区实现、MCP 能力等必须自行上网研究，不得凭印象猜测。
8. 如果某个问题目前没有可靠方案：

   * 先记录为 Open Question；
   * 暂时跳过；
   * 完成其他可验证部分；
   * 最后集中研究这些 unresolved questions。
9. 不允许为了完成文档而虚构已经验证过的能力。必须严格区分：

   * 已从源码验证；
   * 文档声称支持；
   * 理论可行；
   * 尚未验证。

---

# 二、已知项目背景

目标游戏：

**Mount & Blade II: Bannerlord**

CombatBrain 当前目标版本：

**EA v1.4.8.119303**

CombatBrain 2.0 是一个战斗 AI Mod，未来希望接管或干预：

Tactic
→ FormationAI
→ Behavior
→ Order

当前已经允许使用 Harmony。

CombatBrain 的最终目标包括：

* 更自然的阵型控制；
* 包抄；
* 骑兵冲击与重新组织；
* 弓兵保护；
* 战术计划一致性；
* 避免指令抢占；
* AI 个性；
* 信息公平；
* 战斗 telemetry；
* 自动回归测试。

但本 RD **暂时不要解决这些战术问题本身**。

---

# 三、首先研究现有方案

至少研究以下项目和方向。

## 1. Bannerlord.GABS

重点研究：

* GitHub 项目结构；
* GABS 与 Bannerlord.GABS 的通信方式；
* MCP 接口；
* GABP / TCP 协议；
* 游戏启动方式；
* Game API 暴露方式；
* Mission API；
* Formation API；
* Battle Tools；
* Campaign / UI / Console Tools；
* 是否能够被 Codex、Claude Code、DeepSeek Harness 等 Agent 使用；
* 是否可以扩展自定义工具；
* 当前支持的 Bannerlord 版本；
* 对 v1.4.8.119303 的兼容风险。

不要只看 README。

需要检查源码，确认哪些能力是真正存在的。

---

## 2. BannerlordTestingEssentials

研究：

* 它以前解决什么问题；
* 外部测试进程如何和游戏通信；
* 如何构造 integration / system test；
* 哪些思路仍然值得借鉴；
* 哪些实现已经过时。

---

## 3. Bannerlord-Coop 的自动测试体系

重点查看是否存在：

* MissionTests
* IntegrationTests
* E2E.Tests
* debug commands
* runtime verification
* MCP / Agent testing
* 自动构造游戏场景的方法

分析其测试体系和 GABS 有什么区别。

---

## 4. DeepSeek Harness MCP

确认：

* DeepSeek Harness 当前 MCP Client 的实际能力；
* MCP Server 如何注册；
* 工具如何暴露给 Agent；
* 生命周期管理；
* stdio / HTTP / TCP 等连接方案；
* 是否支持长时间运行工具；
* 是否适合控制 Bannerlord；
* 是否存在 timeout、context、tool-call 或进程管理限制。

目标是最终能够形成：

DeepSeek Harness
→ MCP
→ Bannerlord Test Harness
→ Bannerlord

---

## 5. Windows Computer Use / Desktop Automation

研究现有：

* Windows Computer Use MCP；
* UI Automation；
* screenshot；
* keyboard / mouse；
* process launch；
* OCR；
* macro / replay；

但这里只把它作为**辅助通道**研究。

原则上：

**结构化游戏 API > 鼠标键盘自动化。**

Computer Use 更适合：

* 启动器异常；
* 必须经过 GUI 的步骤；
* 截图；
* 视觉验证；
* 游戏崩溃窗口；
* 无 API 的特殊场景。

不要把整个系统建立在像素点击上。

---

# 四、核心研究问题

需要明确回答以下问题。

## A. Agent 能否完全自主启动 Bannerlord？

研究：

* Steam 启动；
* TaleWorlds Launcher；
* 直接启动 exe；
* module 参数；
* Harmony / Mod 加载；
* Debug 模式；
* 是否能绕过不必要的 Launcher；
* 如何确认游戏已经真正进入可测试状态。

需要设计可靠的：

`start_game()`

而不是简单执行 exe 后默认成功。

---

## B. Agent 如何知道游戏当前状态？

至少研究能否结构化获得：

* 当前是否在 Main Menu；
* Campaign；
* Custom Battle；
* Mission；
* 当前 Scene；
* Team；
* Agent；
* Formation；
* Battle result；
* Mission elapsed time。

禁止只依赖截图判断。

---

# 五、第一阶段不要追求全自动“玩游戏”

第一阶段只证明一个最小闭环：

### Experiment A — Game Lifecycle

Agent：

1. 启动 Bannerlord；
2. 等待游戏可连接；
3. 建立通信；
4. 获取当前游戏状态；
5. 正常关闭 Bannerlord。

验收：

必须能够连续执行至少 3 次。

---

### Experiment B — Mission Lifecycle

Agent：

1. 启动 Bannerlord；
2. 创建或进入固定 Mission；
3. 确认 Mission 已运行；
4. 读取 Mission 基本状态；
5. 结束 Mission；
6. 关闭 Bannerlord。

---

### Experiment C — Formation Observation

运行一个固定 Battle。

至少读取双方：

* Team；
* FormationClass；
* FormationIndex；
* Unit Count；
* Position / centroid；
* Facing；
* MovementOrder；
* ArrangementOrder；
* FiringOrder；
* AI controlled 状态。

注意：

如果现有 GABS 只能读取 PlayerTeam，不满足要求。

需要研究如何扩展为：

**读取所有 Team / Formation。**

---

### Experiment D — Build → Deploy → Run

Agent：

1. 修改实验 Mod 中一个可观察参数；
2. build；
3. deploy；
4. 启动游戏；
5. 运行测试；
6. 确认新的构建确实正在运行。

这里必须遵循严格验证原则。

不得因为 build 成功就认为游戏加载了新版本。

至少设计一种：

* build hash；
* DLL hash；
* unique build ID；
* runtime version marker；
* unique log marker；

证明：

> 当前游戏运行的就是刚刚构建的 DLL。

---

# 六、第二阶段：CombatBrain Test Bridge 设计

只有第一阶段通过之后，再设计 CombatBrain 接口。

不要立即实现全部。

先设计 API。

建议研究以下接口：

```text
cb.get_status

cb.get_team_state
cb.get_all_formations
cb.get_formation_state

cb.get_current_tactic
cb.get_current_behavior
cb.get_current_plan

cb.get_order_history
cb.get_plan_history

cb.get_formation_trajectory

cb.get_combatbrain_log
cb.get_telemetry

cb.get_last_order_source
```

FormationSnapshot 至少考虑：

```text
team
formation_index
formation_class

unit_count

centroid_position
facing_direction

width
depth
spacing

speed

movement_order
movement_target

arrangement_order
firing_order

current_behavior
current_tactic

combatbrain_plan

enemy_target

nearest_enemy_distance

last_order_source

timestamp
```

这里尤其研究：

**如何知道最后是谁下达了 Order。**

例如：

* Native Tactic；
* Native Behavior；
* CombatBrain；
* Player；
* 其他 Mod。

因为这个信息对于解决 Formation 指令抢占非常重要。

---

# 七、第三阶段：Scenario Runner

研究如何建立：

```text
cb.run_scenario("CB-XXX")
```

Scenario 应该能够定义：

```text
map
culture

army A
army B

troop composition
formation setup

spawn position

initial facing

AI settings

CombatBrain configuration

maximum duration

random seed
```

最终希望能够建立类似：

```text
CB-REG-001
300 Imperial
vs
300 Vlandia

固定地图
固定 Seed
固定初始位置
```

Agent 可以：

```text
run 20 times
```

自动收集结果。

---

# 八、第四阶段：自动验收

研究哪些 CombatBrain 行为可以转化为自动断言。

例如：

## Formation Integrity

```text
assert_no_extreme_long_snake
```

---

## Archer Protection

```text
assert_archers_not_far_ahead_of_infantry
```

---

## Cavalry

```text
assert_cavalry_not_stuck
assert_cavalry_reorganizes_after_charge
```

---

## Plan Stability

```text
assert_no_order_oscillation
assert_plan_minimum_duration
```

---

## Performance

```text
assert_avg_ai_tick < threshold
```

不要现在随便制定阈值。

这里只研究：

**如何定义指标和如何采集数据。**

具体阈值以后由 CombatBrain 项目决定。

---

# 九、视觉测试

单独研究是否可以增加：

* 定时截图；
* 战斗录像；
* Vision Model；
* 异常战斗自动截取；
* telemetry 时间点与录像时间同步。

长期理想结构：

```text
100 场测试
    ↓
Hard Assertions
    ↓
Telemetry Evaluator
    ↓
Vision Evaluator
    ↓
只把无法确定的 Case
交给用户
```

用户不应该再承担普通测试执行工作。

---

# 十、Version Compatibility

这是当前 RD 的重点风险之一。

CombatBrain 目标版本：

**Bannerlord v1.4.8.119303**

需要研究：

1. Bannerlord.GABS 当前开发版本针对哪个 Bannerlord；
2. 是否可以直接编译到 1.4.8；
3. BUTR Bannerlord.ReferenceAssemblies 是否存在：
   `1.4.8.119303`
4. GABS 使用了哪些发生 breaking change 的 API；
5. 移植成本；
6. 是否值得：

   * fork GABS；
   * 给 GABS 提交 upstream；
   * 独立写兼容层；
   * 只复用协议与架构。

禁止直接假设兼容。

必须实际验证。

---

# 十一、可靠性问题

自动化测试系统必须专门考虑：

* 游戏启动失败；
* Launcher 卡住；
* 游戏崩溃；
* Mod 加载失败；
* MCP 断线；
* Mission 卡死；
* 无限 loading；
* Agent 死亡；
* 战斗永不结束；
* Dialog 弹窗；
* Windows 焦点丢失；
* DLL 被占用；
* Steam 更新；
* Bannerlord crash reporter；
* 游戏残留进程。

设计：

```text
timeout
retry
health check
cleanup
force kill
restart
```

但不要为了未来需求过度设计。

第一版只做实现闭环所必须的机制。

---

# 十二、可重复性

CombatBrain 自动测试必须考虑 determinism。

研究：

* Bannerlord RNG；
* Mission seed；
* troop spawn randomness；
* AI randomness；
* physics；
* frame timing；
* Battle simulation randomness。

需要明确：

哪些变量能够固定；

哪些不能固定；

哪些测试只能采用统计测试，而不能要求逐帧一致。

---

# 十三、测试架构目标

最终理想结构可以是：

```text
DeepSeek Harness
        │
        │ MCP
        ▼
CombatBrain Test Harness
        │
        ├── Game Lifecycle
        ├── Scenario Runner
        ├── Telemetry
        ├── Assertions
        ├── Screenshot / Video
        └── Result Reporter
        │
        ▼
Bannerlord Test Bridge
        │
        ▼
Bannerlord
        │
        ├── GABS
        ├── CombatBrain
        └── Test Module
```

但这只是候选架构。

研究后可以推翻。

不要为了符合这张图而硬套。

---

# 十四、明确不做的事情

本 RD 第一阶段：

不要：

* 优化 CombatBrain 战术；
* 修包抄；
* 修弓兵；
* 修骑兵；
* 设计文化模板；
* 大规模重构 CombatBrain；
* 把所有测试一次性自动化；
* 开发复杂 GUI；
* 自建完整 Computer Use 框架；
* 发明一个新的 Agent Harness。

本阶段目标只有一个：

> **证明 AI Agent 可以可靠地自己启动、运行、观测、关闭并重复测试 Bannerlord。**

---

# 十五、交付物

先交研究结果，不要立即进入大规模开发。

创建：

```text
RD/
CombatBrain-Autonomous-Test-Harness/
```

至少包含：

```text
00-README.md
01-Problem-Definition.md
02-Existing-Solutions-Research.md
03-GABS-Architecture.md
04-Bannerlord-Version-Compatibility.md
05-DeepSeek-Harness-MCP.md
06-Proposed-Architecture.md
07-Experiment-Plan.md
08-Risks-and-Unknowns.md
09-Implementation-Plan.md
```

如果开始实验代码：

```text
experiments/
```

所有实验代码与 CombatBrain 主工程隔离。

---

# 十六、研究报告必须回答

最终第一轮报告必须明确回答：

1. **这个方案到底可不可行？**

2. 能不能做到：

```text
Agent
→ build
→ deploy
→ start Bannerlord
→ create battle
→ observe battle
→ collect telemetry
→ stop
→ modify
→ rerun
```

3. 哪些步骤已经有人实现？

4. 哪些步骤需要我们开发？

5. GABS 能复用多少？

6. GABS 对 1.4.8.119303 的移植成本预计是什么？

7. DeepSeek Harness 是否可以直接作为控制 Agent？

8. 是否需要 Computer Use？

9. 是否需要单独的 Bannerlord Test Mod？

10. 是否需要扩展 CombatBrain 暴露内部状态？

11. 最小 MVP 是什么？

12. 完成 MVP 后，用户还需要亲自做哪些测试？

13. 哪些测试理论上无法完全自动化？

14. 最值得优先做的第一项实验是什么？

---

# 十七、工作方式

执行顺序：

```text
Research
↓
Source Verification
↓
Architecture
↓
Minimal Experiments
↓
Evidence
↓
Decision
↓
Implementation
```

不要：

```text
看到一个 GitHub
↓
直接 clone
↓
开始乱改
```

每一个关键判断都需要留下证据。

如果资料之间存在冲突：

优先级：

```text
实际源码
>
实际运行结果
>
官方文档
>
维护者 issue / discussion
>
社区经验
>
模型推测
```

---

# 十八、新概念披露要求

如果你在研究或设计过程中创造：

* 新模块；
* 新协议；
* 新缩写；
* 新架构层；
* 新术语；
* 新测试分类；

第一次使用时必须立即解释：

1. 它叫什么；
2. 它解决什么问题；
3. 为什么需要；
4. 是否是现有行业术语还是你自己定义的。

不得先在内部文档中大量使用，再等用户追问其含义。

---

# 十九、停止条件

第一阶段不要无限研究。

当能够用实际证据证明以下闭环时：

```text
AI Agent
→ 启动 Bannerlord
→ 连接
→ 进入一个固定测试 Mission
→ 读取双方 Formation 状态
→ 正常结束
→ 再次重复
```

即认为 **Phase 1 MVP 成功**。

此时立即停止继续扩功能。

整理：

* 实验结果；
* Logs；
* 已验证能力；
* 尚未验证能力；
* 技术债；
* 下一阶段方案；

然后提交给用户进行一次架构审核。

在审核前不要擅自进入 CombatBrain 大规模集成。
