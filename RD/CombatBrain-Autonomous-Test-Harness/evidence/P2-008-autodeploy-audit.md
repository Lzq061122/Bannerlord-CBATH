# P2-008 自动开战语义审计 + 最小无人值守方案

日期：2026-09-25
类型：语义审计（只读程序集元数据，未改任何代码、未模拟按键）
目标：从「进入 Deployment」到「自动进入真实交战」，全程无人操作

---

## 一、先固化错误前提（写入测试规则）

> **进入 MissionScreen ≠ 战斗已经开始。**

- `ExecuteStart` 只把玩家带到部署界面（`MissionScreen` of Deployment），
  界面仍有 `重置部署`/`准备` 按钮，兵力全满。
- 指挥官模式下**无人下令则部队完全不动**。
- 判定"真开战"不得用：`ExecuteStart` 成功、`mission_time` 增长、
  或 Formation 是否移动来间接猜测。
- 判定"真开战"必须用**显式状态**（见 §5）。

---

## 二、「准备」按钮的内部语义

### 2.1 引擎侧公开 API（已从参考程序集元数据确认）

| 成员 | 签名 | 语义 |
|---|---|---|
| `DeploymentHandler.FinishDeployment()` | `void()`（无参） | **「准备」按钮的引擎侧效果**：结束当前 deployment |
| `DeploymentMissionController.FinishDeployment()` | `void()`（无参） | 同上（deployment mission controller 上的结束入口） |
| `DeploymentHandler.AutoDeployTeamUsingDeploymentPlan(Formation f)` | 1 参 | 用已生成的部署计划自动部署一个编队 |
| `BattleDeploymentHandler.SetDefaultFormationOrders()` | — | 部署完成后的默认编队命令 |

`FinishDeployment()` 两个重载均为 **public、无参、void**。
这是**游戏「准备」按钮最终调用的公开方法**。

### 2.2 「准备」点击后的状态转换链（推断，结合 API 与已观测行为）

```
点击「准备」(UI)
  → 玩家侧 deployment 标记完成
  → DeploymentHandler.FinishDeployment()  (engine)
  → Formation 从"部署位置""standby"态切换为"可交战"
  → 各 Formation 进入 AI 控制 / 玩家默认命令
  → phase 推进：Deployment → Advance → (接敌后) Engage
```

### 2.3 可观测的"部署已结束"引擎状态

- `Mission.Current` 中 **deployment handler 的部署完成标志**（FinishDeployment 被调用）
- **Formation `movement_order` 从 `StandYourGround` 变为非 standby 命令**（如 `Move`/`Charge`）
- **CombatBrain 日志 phase 从 `Deployment` 推入 `Advance`**

> 最可靠、同时被两个独立来源共享的判据是 **phase=Advance**（CombatBrain 侧）
> + **movement_order ≠ StandYourGround**（CBATH 引擎侧）。

---

## 三、F6（把指挥权交给 AI）的真实语义

### 3.1 引擎侧公开 API（已确认）

| 成员 | 签名 | 语义 |
|---|---|---|
| `Formation.SetControlledByAI(bool, bool)` | **双参 bool** | 把该编队的 AI 控制权交给引擎 / 收回 |
| `Formation.IsAIControlled` | `get` | 当前是否 AI 控制 |

`SetControlledByAI` 签名 `[20 02 01 02 02]` = 2 参数。
两参含义（据 Charter §374 实证）：`(enforceNotSplittableByAI, ...)`。
已在 P2-007 实际观测到：按 F6 后，
**玩家方（Defender）全部 Formation 的 `is_ai_controlled` 由 `false` → `true`**，验证了这一判断。

### 3.2 F6 实际改变的运行状态

```
F6 (玩家按下)
  → 玩家队每个 Formation: SetControlledByAI(true, ...)
  → Formation.IsAIControlled: false → true
  → 引擎 TeamAI 接管该 Form 的命令决策
  → 此后玩家不干预，AI 自主移动/冲锋（可观测 ArrangementVee/Charge 等）
```

**结论：F6 的引擎侧本质就是 `Formation.SetControlledByAI(true, ...)` 对玩家队所有编队调用。**
不需要模拟键盘 F6 —— 这是公开方法，可直接调用。

---

## 四、是否存在稳定 API / 达到目标（用户问题 3）

### 「准备」：

| 优先级 | 方案 | 是否公开稳定 |
|---|---|---|
| **1（推荐）** | `DeploymentHandler.FinishDeployment()` / `DeploymentMissionController.FinishDeployment()` | ✅ **引擎公开方法**，无参 void |
| 2 | UI ViewModel command（若 `FinishDeployment` 受限） | 需要反射取 VM，涉及 UI 层 |
| 3 | 模拟 `Enter` | 兜底，不优先 |

### F6（交给 AI）：

| 优先级 | 方案 | 是否公开稳定 |
|---|---|---|
| **1（推荐）** | 遍历玩家队 Formation，调用 `formation.SetControlledByAI(true, ...)` | ✅ **引擎公开方法** |

**两者都有引擎公开 API，无需 Win32 键盘鼠标模拟，也无需按键。**

> 注意：F6 用 `SetControlledByAI(true, ...)`，但**部署阶段**可能需要先
> `FinishDeployment()` 让编队进入可 AI 控制状态。顺序上应先「准备」再「交 AI」。

---

## 五、「现在真正开战了」的运行时判定（用户问题 4）

**用显式状态，不用 UI 消失或固定秒数。**

| 判据 | 来源 | 说明 |
|---|---|---|
| **Formation `movement_order` 出现非 `StandYourGround`** | CBATH 引擎侧 | `Move` / `Charge` 明确表示已脱离 standby |
| **`unit_count` 开始下降** | CBATH 引擎侧 | 出现伤亡 = 真的在交战 |
| **phase == `Advance` 且出现 `Engage`** | CombatBrain log | CombatBrain 自报的阶段推进 |
| **至少一个 Formation 的 `active_behavior` / `arrangement_order` / `unit_count` 发生真实变化** | CBATH 引擎侧 | 多动态量联合判据（P2-005 确立） |

**必须满足其一，且同时满足「连续 N 秒内状态确实在变化」**，否则标记 INVALID。

---

## 六、最小无人值守方案

### 6.1 目标

从「进入 Deployment」到「交战进行中」，全程无需鼠标键盘。

### 6.2 流程（供 CBATH 核心或脚本实现）

```
1. 执行 h3_provider_start → 等待 CustomBattleScreen
2. 执行 h3_start_from_screen → 进入 Deployment
3. 显式等待 Deployment 结束：
   - 轮询 engine，直到 部署完成标志 / movement_order 脱离 StandYourGround
4. 自动结束部署：调 FinishDeployment()（推荐公开 API）
5. 交给 AI：遍历玩家队各 Formation 调 SetControlledByAI(true, ...)
   （等价于 F6，但不按键）
6. 验证真开战：多动态量变化（见 §5）
7. CBATH 1Hz 连续采样 + CombatBrain telemetry 持续产生
8. Mission 结束后 end_mission + games_stop + cleanup
```

### 6.3 验收（用户要求，无人值守连续 3 轮）

- 进入 Mission ✅
- Deployment 确实结束 ✅（显式判定，非秒数）
- 战斗进入真实交战流程 ✅
- Formation 至少一种真实动态状态变化 ✅
- CombatBrain telemetry 持续产生 ✅
- CBATH 时间线正常连续采样 ✅
- **不需要触碰鼠标键盘** ✅
- 运行结束无残留进程 ✅

### 6.4 实现位置的边界（延续既有原则）

- **引擎公开 API 调用**应放 CBATH 核心（engine state 相关），
  因为这些是 **Bannerlord 稳定接口**，不是旧 CombatBrain 类型。
- **不引用 CombatBrain.dll**。
- 若需临时反射/VM 调用，放独立工具层，标注 temporary。

---

## 七、风险与未决问题

1. **`SetControlledByAI` 的确切双参语义**：签名确认是 2 参 bool，但第二参确切含义
   （`enforceNotSplittableByAI` 与另一个标志）在参考程序集里无法确定具体布尔值。
   → 需要一次最小实验确认传参。
2. **`FinishDeployment()` 调用时机**：必须在进入 Deployment 后、编队计划生成后调用，
   过早可能无效。需要轮询就绪条件再调。
3. **自定义战斗的指挥官身份**：当前玩家是 as-commander。若想更接近"以士兵身份参战"，
   那是另一套入口，本轮不在范围内（用户并未要求改身份）。

---

## 八、关键证据

- **`DeploymentHandler.FinishDeployment` 存在且 public**：`[20 00 01]` = `void()`，元数据确认
- **`DeploymentMissionController.FinishDeployment` 存在且 public**：`[20 00 01]`
- **`Formation.SetControlledByAI` 存在且 public**：`[20 02 01 02 02]` = 2 bool 参
- **P2-007 实测**：按 F6 后 Defender 全队 `is_ai_controlled: false→true`，验证 SetControlledByAI 语义
- 参考程序集：`bannerlord.referenceassemblies.core\1.4.8.119303\ref\net472\TaleWorlds.MountAndBlade.dll`