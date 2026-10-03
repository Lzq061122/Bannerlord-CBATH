# P2-007 实时战斗 correlation — 结果：**PASS（correlation 已建立，非 attribution）**

日期：2026-09-25
前置：P2-006 时间对齐已确证；本轮补上"引擎状态确实变化"的一侧

---

## 一、结论

上一轮（P2-006）的缺口是：两条时间轴能对齐，但**引擎状态零变化**，无法观察"命令 ↔ 状态变化"。
本轮通过让战斗真正开打，**缺口已补齐**。

| 项 | P2-006（部署阶段冻结） | **P2-007（真实交战）** |
|---|---|---|
| CBATH 采样点 | 57 | **373** |
| 引擎状态变化次数 | **0** | **129**（去重时刻数，10 个 Formation） |
| CombatBrain 命令记录 | 6 | **1,380** |
| 战斗阶段 | `Deployment` → `Advance` | `Deployment` → `Advance` → **`Engage`** |
| 命令与状态变化同时刻吻合 | 无从谈起 | **101 / 129（78.3%）** |

---

## 二、关键定义（严格）

> 本报告输出的是 **correlation evidence（时间关联）**，**不是 attribution（因果归因）**。
>
> 已建立：CombatBrain 报告的命令 与 引擎侧观测到的状态变化，**能放到同一时间轴上**。
> 未建立（且本阶段不做）：**该状态变化由该命令导致**。

---

## 三、运行参数

| 项 | 值 |
|---|---|
| CBATH run_id | `run-20260924-163216-1` |
| CBATH build_id | `b20260925-002732-a6df5e05` |
| 采样点 | 373（1 Hz） |
| Mission 窗口 | 0.031 → 374.376 秒 |
| CombatBrain 记录 | 1,380 条 `RouteAEvent` |
| 日志增量 | 721,701 bytes（offset 读取，未扫描全部 64 MB） |
| 模块集 | 含 `CombatBrain`（与 P2-003 起一致，未改动） |

---

## 四、时间基准（沿用 P2-006 结论，本轮再次验证）

`RouteAEvent.time` == `Mission.CurrentTime`（同源，无需映射）。

---

## 五、引擎侧状态变化（本轮新增的核心证据）

10 个 Formation 的状态变化次数（联合判定 `active_behavior` / `movement_order` /
`arrangement_order` / `unit_count`）：

| Formation | 变化次数 | 首次变化时刻（s） |
|---|---:|---|
| 0/f0 Infantry | 2 | 109.565, 196.952 |
| 0/f1 Ranged | 13 | 109.565, 194.942, 196.952, 225.057, 235.092, 243.123 |
| 0/f2 Cavalry | 27 | 109.565, 196.952, 201.975, 217.026, 221.039, 222.046 |
| 0/f3 HorseArcher | 28 | 109.565, 196.952, 210, 219.029, 237.097, 238.1 |
| 0/f4 Cavalry | 28 | 202.982, 219.029, 226.057, 228.071, 234.087, 235.092 |
| 1/f0 Infantry | 6 | 182.895, 219.029, 241.118, 258.186, 298.321, 330.457 |
| 1/f1 Ranged | 21 | 109.565, 205.987, 218.028, 235.092, 239.106, 249.143 |
| 1/f2 Cavalry | 27 | 109.565, 210, 213.015, 219.029, 223.052, 233.085 |
| 1/f3 HorseArcher | 38 | 134.666, 137.688, 138.688, 173.848, 174.852, 181.888 |
| 1/f4 Cavalry | 21 | 109.565, 208.995, 210, 212.01, 214.016, 223.052 |

**观测到的真实战术行为**（本轮后期样本）：

```
BehaviorHoldHighGround      BehaviorScreenedSkirmish
BehaviorProtectFlank        BehaviorTacticalCharge
BehaviorCharge              ArrangementVee（楔形）  ArrangementScatter
movement_order = Charge
```

`ArrangementVee`、`Charge`、`BehaviorProtectFlank` 等是**明确的战术再部署**，
此前从未观测到。

> 同时注意：**t≈109.5s 是分界点**，此前绝大多数 Formation 静止于
> `StandYourGround`；此后 AI 接管并开始机动。

---

## 六、Correlation evidence（三轮对照）

### 6.1 案例 A：命令当刻引擎开始移动（**最强的一条**）

**CombatBrain reported command**

```
mission_time = 109.243 s   team=1  f=0  domain=Movement  event=SetterBegin/Completed
```

**engine-observed state (CBATH，独立来源) — team 1 f0**

| CBATH t | delta | active_behavior | movement | arrange | units | position |
|---|---:|---|---|---|---:|---|
| 105.550 | -3.950 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 106.556 | -2.944 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 107.563 | -1.937 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| 108.565 | -0.935 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.798,924.668 |
| **109.565** | **+0.065** | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | **890.728,924.418 ← 开始移动** |
| 110.572 | +1.072 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 890.134,922.041 |
| 111.576 | +2.076 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 889.439,919.242 |
| 112.581 | +3.081 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 888.703,916.277 |
| 113.587 | +4.087 | BehaviorCautiousAdvance | Move | ArrangementLine | 20 | 887.976,913.346 |

**时间关系**：命令记录于 **109.243s**；引擎位置在 **109.565s** 的采样点首次变化。
两者相距 **0.322 秒**，小于一个采样周期（1 s）。

### 6.2 案例 B：命令时刻**无**引擎变化（反例，同样重要）

```
CombatBrain command : mission_time = 196.535 s  (team=1, f=0, SetterBegin)
engine-observed     : t=192.933 .. 205.987 全程 position=830.987,684.402 未变
```

→ 命令存在，但对应 Formation 的引擎状态**没有**变化。

### 6.3 案例 C：引擎变化时刻**无**命令记录

```
engine-observed change : t = 219.029 s  (Team 1 f0 Infantry 等)
CombatBrain record     : 该时刻 ±0.6s 内无任何 RouteAEvent
```

→ 引擎状态变了，但**没有**对应的 CombatBrain 命令记录。

### 6.4 综合统计（诚实计数）

| 指标 | 值 |
|---|---|
| 去重后的引擎变化时刻 | **129** |
| 去重后的 CB 命令时刻 | 458 |
| **引擎变化时刻中，±0.6s 内存在 CB 命令记录的** | **101（78.3%）** |
| 不匹配（引擎变了但无对应命令） | 28（21.7%） |

---

## 七、必须明确声明不能证明的事

1. **不能证明因果**。78% 的时间吻合不能排除：
   - 原生 AI 同时也在写同一字段；
   - CombatBrain 的命令与引擎变化**恰好同频**（战斗节奏天然同步）；
   - 二者都被第三个因素（如接敌距离）驱动。
2. **不能证明命令被采纳**。日志中的 `source=ExternalUnknown` 属旧版语义，本阶段按约定**不解读**。
3. **21.7% 的不匹配尚未解释**。可能源于采样粒度、命令未改变状态、或状态变化由非 CombatBrain
   来源引起 —— **本阶段不做判定**。
4. **`closest_enemy_formation_index` 仍为 `unavailable`**，目标 Formation 无法稳定标识，
   因此无法回答"这个命令是发给谁的"。

---

## 八、本阶段未做（按边界）

- ❌ 自动归因 / 命令来源判定
- ❌ 解析 `ReasonCode` / `OverrideKind` 等旧版业务语义
- ❌ 骑兵包抄等具体行为测试
- ❌ 稳定 Formation ID 系统
- ❌ 完整 CB-014
- ❌ 扩展采样频率（保持 1 Hz）
- ❌ CBATH 核心引用 CombatBrain

**CBATH 核心 CombatBrain 引用数 = 0**（已 grep 验证）。

外部工具（可删除，均标注 `legacy CombatBrain temporary adapter`）：

| 文件 | 职责 |
|---|---|
| `tools\cb-legacy-offset2mission.ps1` | 读 offset 之后的新增日志，提取 `RouteAEvent` |
| `tools\cb-correlate.ps1` | 将 CB 事件与 CBATH 时间序列对齐，输出 markdown 证据 |

---

## 九、环境状态

| 项 | 状态 |
|---|---|
| 活进程残留 | **0** |
| 未修改 | CombatBrain 源码/二进制、`gabs-config\config.json` |
| 日志读取 | offset 增量 721,701 bytes，**未扫描全部 64 MB** |

---

## 十、关键教训（本轮暴露，重要）

**`ExecuteStart` 只到部署界面，不等于开战。**

- 截图证据显示 `重置部署` / `准备` 按钮仍在，兵力全满（24/24、25/25…）
- 在指挥官模式下，若无人下令，**部队不会移动**
- 这解释了 P2-005 / P2-006 中"mission_time 前进但状态冻结"的真正原因
- 前两轮我把它归因于"失焦"或"锚点特性"，**均不完整**：根因是**战斗从未开始**

> 后续自动化必须显式处理：进入 Mission 后需完成部署确认（或以士兵身份参战），
> 并在采样前验证**至少一个动态量发生变化**，否则本轮标记 INVALID。
