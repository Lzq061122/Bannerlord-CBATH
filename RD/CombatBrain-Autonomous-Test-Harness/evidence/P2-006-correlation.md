# P2-006 CombatBrain command ↔ engine timeline 时间关联 — 结果报告

日期：2026-09-25
类型：格式审计 + 时间基准确认 + 最小 correlation 尝试

---

## 一、结论摘要

| 验收项 | 结果 |
|---|---|
| 1. 找到至少一条真实 command 记录 | ✅ **6 条 `RouteAEvent`** |
| 2. 明确 CombatBrain telemetry 的时间基准 | ✅ **`Mission.CurrentTime`**（已数值验证） |
| 3. 能对应到 CBATH Mission timeline | ✅ 最大偏差 ±0.75 秒 |
| 4. 能确定 command 对应的 Formation | ✅ Team 1 / f=0 / Movement 域 |
| 5. 时间序列中找到该 command 前后的引擎状态 | ✅ 已取到，但**状态未发生变化** |
| 6. 输出人工可读 correlation evidence | ✅ 见 §5（**含"尚不能证明"声明**） |

**关键更正**：本阶段**未**取得"命令 ↔ 状态变化"的对照，因为本轮 9 个 Formation
在 57 个采样点中**状态零变化**。时间对齐已证明，但 correlation 的"变化"一侧缺失。
原因见 §6。

---

## 二、字段修正（已完成）

`closest_enemy_formation_index` 原输出 `"0.00/Inf"`（可能被误读为有效 ID）。
**已修正为显式不可用标记**：

```json
"closest_enemy_formation_index": "unavailable:no_stable_formation_id"
```

实测确认（本轮 57 个采样点全部为该值，不再出现任何形似 ID 的替代值）。
**未**建立稳定 Formation ID 系统，**未**通过坐标猜测目标 —— 该缺口按约定保留。

---

## 三、第一步：CombatBrain telemetry 真实格式（审计结果）

采用 offset 方式，只读本轮新增的 31,927 bytes，**未扫描历史 63 MB**。

### 3.1 日志行族分布（本轮）

| 行族 | 条数 | 是否含 Mission 时间 |
|---|---|---|
| `Bench` | 130 | — |
| `ArmyCtx` | 24 | 否（仅 wall clock） |
| `Obs` | 19 | 否 |
| `ControlLease` | 14 | 否 |
| `Commit` | 13 | **否**（仅 wall clock） |
| `RouteA` | 11 | 否 |
| `Cps2Observation` | 11 | 否 |
| `Mission` | 9 | 否 |
| **`RouteAEvent`** | **6** | **✅ 是（`time=`）** |

**关键**：在旧 CombatBrain 的全部日志行中，**只有 `RouteAEvent` 携带与 Mission 时钟对齐的
`time=` 字段**。其余行（含 `Commit`）只有 wall clock，或根本没有时间。

### 3.2 `RouteAEvent` 字段结构（真实样例）

```
00:29:04.881  [RouteAEvent] run=66b3ca570fc648a38921fc82e6fd82e9 session=1 seq=4 \
  time=56.937260 identity=1 team=1 f=0 domain=Movement event=SetterBegin \
  intent=Hold revision=0 setterSeq=98 relatedSeq=0 source=ExternalUnknown \
  orderType=6 reason=None signal=0 x=0.000 y=0.000 observerSeq=164
```

| 字段 | 含义 | 实测值示例 |
|---|---|---|
| `wall_clock` | 行首时间戳（系统时钟） | `00:29:04.881` |
| **`time`** | **Mission 时间（秒）** | **`56.937260`** |
| `run` | 本轮运行标识 | `66b3ca57...` |
| `session` | 会话号 | `1` |
| `seq` | 事件序号 | `1..6` |
| `identity` | Formation 稳定标识（CombatBrain 侧） | `1` |
| **`team`** | 队伍 | **`1`（Attacker）** |
| **`f`** | Formation 槽位 | **`0`（Infantry）** |
| `domain` | 命令域 | `Movement` |
| **`event`** | 事件类型 | `Intent` / `Exit` / `Restore` / `SetterBegin` / `SetterCompleted` / `ExternalAfterExit` |
| `intent` | 意图 | `Hold` |
| `source` | 来源标记 | `ExternalUnknown` |
| `orderType` | 订单类型码 | `-1` 或 `6` |
| `reason` | 原因 | `SelectionTimeout` / `None` |

### 3.3 六条记录全貌（本轮）

| seq | time (Mission) | team | f | event | orderType | reason |
|---|---|---|---|---|---|---|
| 1 | 0.53765 | 1 | 0 | `Intent` | -1 | — |
| 2 | 10.54184 | 1 | 0 | `Exit` | -1 | `SelectionTimeout` |
| 3 | 10.54184 | 1 | 0 | `Restore` | -1 | `SelectionTimeout` |
| 4 | 56.93726 | 1 | 0 | `SetterBegin` | 6 | `None` |
| 5 | 56.93726 | 1 | 0 | `SetterCompleted` | 6 | `None` |
| 6 | 56.93726 | 1 | 0 | `ExternalAfterExit` | 6 | `None` |

### 3.4 关于 `CommandProvenance` / `FormationDecisionTrace` 的实际输出

**结论：在本轮日志中未观察到这两个类型对应的直接输出行。**

它们是在**程序集层面**确认存在（`combatbrain_behavior_count` 诊断时读到的 public 类型），
但运行时并未向该日志文件写出同名记录。

实际承担"命令记录"职责的是 `RouteAEvent` 行族。
`OrderTraceAgg` 只在 Mission 结束时输出一次**聚合计数**（本轮为
`FormationTactics=1/o0`，其余全 0），不含单条命令详情。

**按用户要求：未依据程序集字段设计解析器，以上全部来自真实日志文本。**

---

## 四、第二步：时间基准确认（关键）

### 4.1 结论

**`RouteAEvent.time` == `Mission.CurrentTime`（同一时钟，同一单位：秒）。**

### 4.2 验证方法（三条独立证据）

**证据 1 — 与 CombatBrain 自报的 BattleDuration 吻合**

```
RouteAEvent seq=4/5/6 : time=56.937260
CBATH get_last_run     : mission_end_time = 56.937
CombatBrain telemetry  : BattleDuration = 56.94
```

三者一致（误差 < 0.01s）。若 `time` 是另一套相对时钟，不可能与 `BattleDuration` 同时吻合。

**证据 2 — 与 CBATH 采样序列的线性关系**

CBATH 采样 t 从 `0.029` 到 `56.208`；CB event 从 `0.538` 到 `56.937`。
两者覆盖同一区间，且最大对齐偏差 **±0.75 秒**（小于 1 Hz 采样周期的 1 倍）。

**证据 3 — 排除了 wall-clock 直接映射的可能性**

若假设 `mission_time = (wall - wall0) + mt0`，则：
- 第 1 对（`wall=00:28:12.826`, `mt=0.538`）与第 4 对（`wall=00:29:04.881`, `mt=56.937`）
  预测误差为 **0.000 / 0.000**（RouteAEvent 族内部完全成立）
- 但 `RouteAExitGate` / `RouteAOwnership` 两行报 `time=10.539`（wall=`00:28:22.833`），
  按同一公式预测应为 `10.541`，误差 0.002 — 也在容差内

→ 说明 `time` 与 wall clock **同为单调推进**，但 `time` 是 Mission 时钟（可暂停/可重置），
   wall clock 是系统时钟。**必须以 `time` 为对齐基准，不能用 wall clock。**

### 4.3 不需要额外映射

因为两者同源（都是 `Mission.CurrentTime`），**无需任何转换函数**。
这是最理想的结果 —— 用户担心的情况（不同时钟需最小映射）未发生。

---

## 五、第三步：最小 correlation evidence

> 严格区分：**这是 correlation（时间关联），不是 attribution（因果归因）。**

### 5.1 选定对象

- **Formation**：Team 1（Attacker）/ `f`=0 / Infantry（20 人）
- **选定事件**：`seq=2/3`，Mission time = **10.54184s**，event = `Exit` → `Restore`
  （其余事件的 time 在 Mission 起止点附近，不适合观察"前后"状态）

### 5.2 时间对齐

| | 时间 |
|---|---|
| **CombatBrain reported command** | t = **10.542 s**（`Exit` → `Restore`, domain=Movement, team=1, f=0） |
| CBATH sample t-1 | **9.059 s**（Δ = -1.483） |
| CBATH sample t | **10.059 s**（Δ = **-0.483**） |
| CBATH sample t+1 | **11.072 s**（Δ = **+0.530**） |
| CBATH sample t+2 | **12.075 s**（Δ = +1.533） |

### 5.3 引擎侧观测状态

| CBATH sample | Team1 f0 `active_behavior` | `movement_order` | `arrangement_order` | `unit_count` |
|---|---|---|---|---|
| 9.059 s | `BehaviorCautiousAdvance` | `Move` | `ArrangementLine` | 20 |
| 10.059 s | `BehaviorCautiousAdvance` | `Move` | `ArrangementLine` | 20 |
| 11.072 s | `BehaviorCautiousAdvance` | `Move` | `ArrangementLine` | 20 |
| 12.075 s | `BehaviorCautiousAdvance` | `Move` | `ArrangementLine` | 20 |

### 5.4 对齐结果（人工可读）

```text
CombatBrain reported command
  t = 10.542 s   team=1  f=0  domain=Movement  event=Exit -> Restore
                 orderType=-1  reason=SelectionTimeout

engine-observed state (CBATH, independent)
  t =  9.059 s : behavior=BehaviorCautiousAdvance  movement=Move  arrange=ArrangementLine  units=20
  t = 10.059 s : behavior=BehaviorCautiousAdvance  movement=Move  arrange=ArrangementLine  units=20
  t = 11.072 s : behavior=BehaviorCautiousAdvance  movement=Move  arrange=ArrangementLine  units=20
  t = 12.075 s : behavior=BehaviorCautiousAdvance  movement=Move  arrange=ArrangementLine  units=20

time relationship
  CB event 10.542 s falls between CBATH samples 10.059 s and 11.072 s
  nearest sample offset = -0.483 s (within the 1 Hz sampling interval)

NOT PROVEN (explicitly out of scope)
  * 无法证明该 engine state 由该 command 导致
  * 本窗口内 engine state 未发生任何变化，故亦无法观察"命令后状态改变"
  * source=ExternalUnknown 属旧版语义，本阶段不解读
```

### 5.5 必须如实报告的局限

**本轮 9 个 Formation 在 57 个采样点中，引擎状态变化次数 = 0。**

逐 Formation 统计（行为/移动/阵型/兵力/坐标 五项联合）：

```
0/f0/Infantry      changes=0
0/f1/Ranged        changes=0
0/f2/Cavalry       changes=0
0/f3/HorseArcher   changes=0
1/f0/Infantry      changes=0
1/f1/Ranged        changes=0
1/f2/Cavalry       changes=0
1/f3/HorseArcher   changes=0
1/f4/Cavalry       changes=0
```

因此**无法**给出"命令前后引擎状态 A → B"的对照。
当前能证明的仅到：**两条时间轴可以对齐到亚秒精度**。

---

## 六、为什么状态零变化（诊断，非推测）

CombatBrain 日志（本轮新增部分）：

```
[BattlePhase] Team 0 Deployment → Advance (ownSurv=1.00 enemSurv=1.00 intent=Defend)
[BattlePhase] Team 1 Deployment → Advance (ownSurv=1.00 enemSurv=1.00 intent=ProtectArcher)
phase counts: Deployment ×4, Advance ×22
[遥测] BattleDuration=56.94  （全部 26 项计数为 0）
```

**判断**：战斗进入 `Advance` 阶段后，56.94 秒内兵力仍在**接近**过程中，
尚未发生任何会导致 Formation 重新部署的接触。CombatBrain 自身的遥测
也显示全部行为计数为 0（`FormationBreakCount=0`、`CavalryChargeCount=0` 等），
与 CBATH 观测到的"零变化"**完全一致** —— 两个独立来源相互印证。

→ 这是**真实战场状态**，不是工具缺陷。要观察状态变化，需要更长的战斗
或让双方实际接敌。

---

## 七、动态判据规则（已确立）

**写入规则，供后续所有测试遵循：**

> **测试有效性不得以 `Formation.CurrentPosition` 单字段判定。**
>
> 必须使用多动态量联合，任一项变化即视为模拟在推进：
> - `active_behavior`
> - `movement_order`
> - `arrangement_order`
> - `unit_count`
> - `position`（仅作参考，不可单独使用）
>
> 理由：`Formation.CurrentPosition` 是编队**锚点**，仅在编队被重新放置时更新。
> P2-005 第一轮曾因只看该字段，把一次正常推进的 Mission 误判为"冻结"。
> 实测反例：`mission_time` 前进 48 秒、`phase` 从 `Deployment` 推进到 `Advance`，
> 而 `position` 与 `active_behavior` 均可长时间保持不变。

---

## 八、实现边界遵守情况

| 约束 | 状态 |
|---|---|
| 不在 CBATH 核心引用 CombatBrain.dll | ✅ 核心零引用 |
| 不解析 `ReasonCode` / `OverrideKind` 旧版语义 | ✅ 仅记录原始文本，未解读 |
| 不把旧日志格式固化进 CBATH | ✅ 解析器独立在 `tools\` |
| 外部适配器明确标注 | ✅ 文件头与输出 JSON 均标 `legacy CombatBrain temporary adapter` |
| 不做自动 PASS/FAIL | ✅ |
| 不做骑兵包抄判断 | ✅ |
| 不做稳定 Formation ID 系统 | ✅ 并已把该字段改为 `unavailable` |
| 不开始完整 CB-014 | ✅ |
| 不扩展采样频率 | ✅ 保持 1 Hz |

### 新增外部工具（可删除）

`tools\cb-legacy-offset2mission.ps1` —— **legacy CombatBrain temporary adapter**

- 仅读 offset 之后的新增日志
- 仅提取 `RouteAEvent` 行
- 输出 JSON 到 evidence 目录
- **不进入 CBATH 核心**

---

## 九、环境状态

| 项 | 状态 |
|---|---|
| 活进程残留 | **0** |
| CBATH build_id | `b20260925-002732-a6df5e05` |
| CBATH SHA256 | `c1603acc7abd32c75f984ad1c6df153ebad3721ae6adb91ba56280059053f751` |
| 未修改 | CombatBrain 源码/二进制、`gabs-config\config.json` |
| 日志读取量 | 31,927 bytes（非全部 63 MB） |

---

## 十、本阶段停止点

按用户要求，达到验收标准后**立即停止**，不继续：
自动化归因、行为测试、骑兵包抄判断、稳定 Formation ID、完整 CB-014。

**遗留缺口**（如实记录，不自行扩展）：
1. 目标 Formation 稳定标识 —— 引擎侧不可得（`FormationQuerySystem` 无 `FormationIndex`）；
2. 尚未取得"命令 → 状态变化"对照，需一轮**能让编队实际重新部署**的战斗。
