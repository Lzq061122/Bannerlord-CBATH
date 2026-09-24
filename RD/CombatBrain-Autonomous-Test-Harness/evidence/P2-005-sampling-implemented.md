# P2-005 1 Hz 连续采样 — 结果：实现完成，验证轮标记 INVALID（判据缺陷已定位）

日期：2026-09-24
类型：实现 + 一轮真实验证

---

## 一、结论

| 项 | 结果 |
|---|---|
| `SamplingMissionBehavior` + `get_last_run` | ✅ **已实现并运行** |
| 采样能力 | ✅ 52 点 @ 1 Hz，t=0.029 → 51.237，**无缺口** |
| 时间戳单调递增 | ✅ |
| 一次调用返回完整序列 | ✅ |
| CBATH 无 CombatBrain 编译期引用 | ✅ |
| **30 秒真实演化验证** | ⚠️ **INVALID（我采用的判据有缺陷，非 CombatBrain 失败）** |

---

## 二、已实现的交付物

### 2.1 新增源文件

| 文件 | 作用 |
|---|---|
| `SamplingMissionBehavior.cs` | 1 Hz 采样，MissionBehavior，内存缓冲，上限 900 点 |
| `RunRecord.cs` | 保存最近一轮完整时间序列，供 `get_last_run` 一次返回 |

### 2.2 修改

| 文件 | 改动 |
|---|---|
| `ProbeSubModule.cs` | 新增 `OnMissionBehaviorInitialize` → `mission.AddMissionBehavior(new SamplingMissionBehavior())` |
| `CbathTools.cs` | 新增 `cbath/get_last_run` |
| `.csproj` | 登记两个新文件 |

### 2.3 新增的 Formation 字段

在既有 9 字段之上，仅追加两个：

- `active_behavior` —— 引擎当前 AI 行为名（实测：`BehaviorCautiousAdvance` / `BehaviorSkirmish` / `BehaviorStop` / `BehaviorMountedSkirmish`）
- `closest_enemy_formation_index` —— 实测返回形如 `"0.00/Inf"`

> **需要报告的偏差（按用户约定）**：`closest_enemy_formation_index` **无法用 Formation 槽位 index 稳定表示**。
> 原因是 `Formation.QuerySystem.ClosestSignificantlyLargeEnemyFormation` 返回的是
> `FormationQuerySystem`，该类型**不暴露 `FormationIndex`**（已验证：它只有 `Team` / `IsInfantryFormation` /
> `MainFormationReliabilityFactor` 等）。同样 `Formation.CachedClosestEnemyFormation` 也返回
> `FormationQuerySystem` 而非 `Formation`。
>
> 故当前实现退化为 `可靠性因子/兵种类别`（如 `"0.00/Inf"`）。
> 按用户明确约定，**未自行扩展稳定 ID 系统**，此处如实报告。

### 2.4 构建身份

| 项 | 值 |
|---|---|
| build_id | `b20260924-235721-c297d385` |
| SHA256 | `9bc27f93b615f289bb35957e9521e7c671c42da21e324c6b08018e834c9f533e` |
| source == deployed | ✅ |

### 2.5 外部前台辅助（不在 CBATH 内）

`tools\focus-bannerlord.ps1` —— 独立 Win32 脚本，用于把 Bannerlord 窗口置前。
实测 `FOCUS_RESULT=ok`，且**保持前台 40 秒未丢失**。

---

## 三、验证轮的实际结果

### 3.1 采样数据

```json
{
  "diag_begin_count": 0,
  "diag_complete_count": 1,
  "mission_name": "battle_terrain_biome_096",
  "mission_start_time": "0.000",
  "mission_end_time": "51.879",
  "run_id": null,
  "sample_count": 52,
  "sample_interval_seconds": 1
}
```

采样点：**52 个**，`t` 从 `0.029` 到 `51.237`，间隔约 1.0 秒，**无缺口 > 2 秒**，严格单调递增。

### 3.2 发现的两个真实缺陷

#### 缺陷 1：`run_id` / `mission_name` 为空（**已定位，根因确凿**）

诊断计数器给出决定性证据：

```json
"diag_begin_count": 0,
"diag_complete_count": 1
```

**`Begin()` 从未执行，但 `Complete()` 执行了。**

说明 `OnBehaviorInitialize()` 没有被调用 —— 即
`mission.AddMissionBehavior(new SamplingMissionBehavior())` 添加实例时
**不会触发该实例的 `OnBehaviorInitialize`**。

这同时解释了 `mission_name` 为空（`_sceneName` 字段只在 `OnBehaviorInitialize` 里赋值）
和 `run_id` 为 null（`RunRecord.Begin` 从未调用）。

> 修复方向（本轮未做，需用户确认）：把初始化逻辑从 `OnBehaviorInitialize` 移到
> `OnAfterMissionCreated`，或在 `OnMissionTick` 首次执行时惰性初始化。
> 注意 `OnMissionTick` 确实被调用了（有 52 个采样点），所以惰性初始化可行。

#### 缺陷 2：我采用的"动态量冻结"判据过于严格（**这是判定问题，不是代码缺陷**）

我此前判定"模拟冻结"，依据是 Formation `position` 全程不变。
**这个结论是错的。** 从 CombatBrain 日志（只读 offset 之后的新增部分，未扫描全部 63 MB）查到：

```
[ArmyCtx] Team 0 phase=Deployment ...   (4 次)
[ArmyCtx] Team 0 phase=Advance ...      (20 次)
[Obs] t=51  (无决策活动)  |活性分支总数=0
[遥测] BattleDuration=51.88
```

**战斗阶段从 `Deployment` 正常推进到 `Advance`**，CombatBrain 一直在正常工作到 t=51。
且 `BannerlordConfig.txt` 中 `StopGameOnFocusLost=False`，失焦本就不暂停。

**真正原因**：`Formation.CurrentPosition` 是编队的**锚点**，只在编队被重新放置时才变化；
在 `Advance` 阶段兵力尚未接敌，锚点可以长时间不动。
所以我用错了"动态量"。

> 这正是用户预警过的情况，只是我把判据选错了。用户要求的是
> "Formation position / movement order / active behavior / unit count / 其他能证明
> simulation tick 正常推进的引擎状态" 中的**任一**。
> 本轮的 `active_behavior` 字段确实出现了多个不同值
> （`BehaviorCautiousAdvance` / `BehaviorSkirmish` / `BehaviorStop` / `BehaviorMountedSkirmish`），
> **按用户给定的判据，本轮其实应当判 PASS**。
> 我先前只看 position 就宣布冻结，判据使用错误。

---

## 四、验证轮判定

| 用户验收项 | 结果 |
|---|---|
| 1. `active_modules` 含 CombatBrain | ✅ 通过 |
| 2. CombatBrain MissionBehavior 运行证据 | ✅ 通过（日志 t=51、phase=Advance、BattleDuration=51.88） |
| 3. Bannerlord 前台 | ✅ `FOCUS_RESULT=ok`，且前台保持 40s |
| 4. Mission 真实演化约 30 秒 | ✅ 通过（52s，`Deployment`→`Advance`） |
| 5. ~30 个 1 Hz 采样点 | ✅ 52 点 |
| 6. 时间戳严格单调递增 | ✅ |
| 7. 至少一个动态状态发生变化 | ✅ `active_behavior` 出现 4 种不同值 |
| 8. `get_last_run` 一次返回完整序列 | ✅ |
| 9. CBATH 无 CombatBrain 编译期引用 | ✅ grep 全部命中仅为自身命名空间 |
| **附加：run identity 正确** | ❌ **`run_id: null`（缺陷 1）** |

**综合判定**：9 项核心能力已具备，但 `run_id` 为空属实质缺陷，**本轮不宣布 PASS**，先修复缺陷 1。

---

## 五、环境状态

| 项 | 状态 |
|---|---|
| 活进程残留 | **0** |
| 未修改 | CombatBrain 源码/二进制、`gabs-config\config.json` |
| CombatBrain 日志处理 | 只读 offset 之后新增部分（30,516 bytes / 366 行），**未扫描全部 63 MB** |

---

## 六、下一步（待用户确认）

1. **修复缺陷 1**：把 `RunRecord.Begin` 与场景名捕获改为在 `OnMissionTick` 首次执行时惰性初始化，或在 `OnAfterMissionCreated` 中执行。
2. **重跑一轮验证**，确认 `run_id` 非空、`mission_name` 正确。
3. 判据改用多动态量联合（`active_behavior` + `movement_order` + `unit_count`），position 作为参考而非唯一依据。
4. 修复后移除诊断计数器 `diag_begin_count` / `diag_complete_count`。
