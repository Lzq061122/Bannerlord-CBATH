# P2-004 CombatBrain 运行态诊断 — 结果：**结论 A（已证明在运行）**

日期：2026-09-24
类型：最小运行态诊断（临时反射探针，已移除）
判据目标：CombatBrain 的 Mission 逻辑是否真的注册并执行

---

## 一、结论（结论 A）

> **`CombatBrain MissionBehavior instance found` → `CombatBrain telemetry / observable execution found`**

CombatBrain **不仅注册了 MissionBehavior，而且其完整决策管线已在真实 Mission 中执行并产出可读记录**。

| 项 | 结果 |
|---|---|
| MissionBehavior 注册 | ✅ `CombatBrain.Ai.CombatAiMissionLogic`（68 个 behavior 中的第 68 个） |
| `OnMissionTick` 存在 | ✅ true |
| 程序集来源 | ✅ `CombatBrain.dll` |
| 执行证据 | ✅ **`%TEMP%\CombatBrain.log`（63 MB）+ `CombatBrain.telemetry.json`** |
| 决策产出 | ✅ 意图切换、Commit 判定、ControlLease、观测分支计数 |

**可以进入下一阶段的 1 Hz 时间序列采样。**

---

## 二、取证过程（按用户指定顺序）

### 2.1 第一步：MissionBehavior 枚举（已完成）

临时反射探针（`cbath/diag_behaviors`，**已移除**）枚举当前 Mission 的 68 个
MissionBehavior 实例，记录运行时类型名与所属程序集。命中：

```json
{
  "type": "CombatBrain.Ai.CombatAiMissionLogic",
  "assembly": "CombatBrain",
  "assembly_location": "E:\\...\\Modules\\CombatBrain\\bin\\Win64_Shipping_Client\\CombatBrain.dll",
  "has_OnMissionTick": true
}
```

汇总字段：

```json
"behavior_count": 68,
"combatbrain_behavior_count": 1,
"combatbrain_assembly": {
  "loaded": true,
  "full_name": "CombatBrain, Version=0.0.0.0, Culture=neutral, PublicKeyToken=null"
}
```

> 顺带确认：MCMv5 也注册了 `MCM.SettingsProviderMissionBehavior`，说明 MCM 链路正常。

### 2.2 第二步：CombatLog 运行时状态（已完成，并解答了日志位置之谜）

反射读取 `CombatBrain.CombatLog` 的 **public static** 字段：

```json
"combatlog": {
  "available": true,
  "type": "CombatBrain.CombatLog",
  "assembly": "CombatBrain",
  "Disabled": "False",
  "OverridePath": "<null>",
  "_logPath": "C:\\Users\\Administrator\\AppData\\Local\\Temp\\CombatBrain.log",
  "_buffer_len": "0"
}
```

**关键发现：CombatLog 的输出路径是 `%TEMP%\CombatBrain.log`，不是 `Documents\...\ModLogs`。**

这解释了此前"CombatBrain 零日志输出"的判断——**是我找错了目录**，不是它没输出。
`Disabled = False`，日志功能正常工作。

### 2.3 补充：CommandProvenance 运行时状态

```json
"command_provenance": {
  "available": true,
  "instance_null": false,
  "Count": "1"
}
```

`CommandProvenance.Instance` 存在且 `Count = 1`，证明命令溯源环已记录到命令。

---

## 三、执行证据（直接可读的运行时日志）

`%TEMP%\CombatBrain.log`，**63,356,175 字节**，最后写入 `2026-09-24 23:49:46`。

本次 Mission 的启动段（原文摘录）：

```text
23:49:21.186  CombatBrain 子模块已加载
23:49:31.743  CombatBrain 手活属性模型已注册（X2）
23:49:39.243  [Obs] 补丁自检：CombatBrain 零 Harmony 补丁依赖（纯 MissionBehavior 事件驱动），无回调占用竞争
23:49:39.243  [Obs] 观测分支预注册=12
23:49:39.251  CombatBrain 战斗AI已初始化, teams=2
23:49:39.251  阵营归属: PlayerTeam=Team 0
23:49:39.251    Team 0: Side=Defender 阵营=- 关系=玩家
23:49:39.251    Team 1: Side=Attacker 阵营=- 关系=敌方
23:49:39.256  [SetOrderObserver] HarmonyLib 运行时版本=2.4.2.0；0Harmony 加载=...\Bannerlord.Harmony\...\0Harmony.dll
23:49:39.258  [SetOrderObserver] 观测已挂载（Harmony patch OK, id=com.combatbrain.setorderobserver, prefixes=3）
23:49:39.258  [编队明细] Team 0 意图=Defend 保护=否 架枪=否
23:49:39.258  [编队明细] Team 1 意图=Defend 保护=否 架枪=否
23:49:39.278  [ArmyCtx] Team 0 phase=Deployment MB=(0,0) str=0 conf=0.00 | obj=无 (0,0) str=0
23:49:40.275  TerrainSampler 就绪: center=(1345,859) extent=300m cell=8.0m points=5776
23:49:40.280  [ArmyCtx] Team 0 phase=Deployment MB=(1345,859) str=100 conf=1.00 | obj=0 (1105,1071) str=95
23:49:40.281  [Mission] Team 0 f=0 mission=Reserve sep=Reserve iso=OK dist=5 mb=(1345,859)
23:49:40.286  [Commit] Team 0 f=0 mission=Reserve sep=Reserve aligned=1 support=0.23 ratio=49.00 ... permission=Granted reasons=InsufficientSupport
23:49:40.779  Team 1 意图切换 → ProtectArcher  [Power=0.74 Line=0.46 Cav=0.50 Height=1.00 Moral=1.00 Arc=0.09 PenB=0.00 Dist=1.00 EnemCav=0.68 FlankEx=0.61 Gap=0.50 Skirm=0.00]
23:49:42.773  [Obs] t=3  intent.switch=1  |活性分支总数=1
```

最后一行 `[Obs] t=3 intent.switch=1` 是**执行计数的直接证据**：
观测台在 Mission 时间 t=3 秒时记录了 1 次意图切换。

### 3.1 前一局 Mission 的完整遥测

```json
{"BattleDuration":92.06,"FormationBreakCount":0,...,"AnomalyLongStalemate":0}
```

`BattleDuration=92.06` 秒，与 P2-003 观测到的 88.6 秒 Mission 相符。

### 3.2 其它产出

| 文件 | 大小 | 说明 |
|---|---|---|
| `%TEMP%\CombatBrain.log` | 63 MB | 主运行日志 |
| `%TEMP%\CombatBrain.telemetry.json` | 668 B | 遥测汇总（每局落盘） |
| `%TEMP%\CombatBrain-offline.log` | 146 KB | 离线日志（2026-09-17） |

日志中出现 `[遥测] 落盘: C:\Users\...\Temp\CombatBrain.telemetry.json`，确认落盘路径。

---

## 四、对本阶段阻塞的判定

| 此前担忧 | 实际结论 |
|---|---|
| CombatBrain 是否注册 MissionBehavior | ✅ 已注册 |
| 是否因 MCM 配置默认关闭 | ✅ 未关闭，`Disabled=False` 且已执行 |
| 是否有特定 Battle/Team 条件未满足 | ✅ 条件已满足（teams=2，双方均被识别） |
| 是否真的在执行 | ✅ **已执行**，有决策产出与观测计数 |
| 为何没有日志 | ✅ **是我找错目录**，日志在 `%TEMP%`，一直正常输出 |

**结论：阻塞已清除，无需修改旧 CombatBrain 任何代码。**

---

## 五、本轮的临时手段与已恢复内容

### 5.1 使用的临时手段

新增一次性反射探针 `BehaviorDiagnostic.cs` + 一个 `cbath/diag_behaviors` 工具：

- **不含任何 CombatBrain 编译期引用** —— 全部通过程序集名字符串 + 反射访问；
- 因此该文件可在 CombatBrain 缺失时正常编译；
- 用途仅为一次性诊断，**未固化进 CBATH API**。

### 5.2 已恢复

| 项 | 状态 |
|---|---|
| `BehaviorDiagnostic.cs` | ✅ 已删除 |
| `CbathTools.cs` 的 `diag_behaviors` 工具 | ✅ 已移除 |
| `.csproj` 的 Compile 项 | ✅ 已还原 |
| CBATH 源文件数 | ✅ 恢复为 8 个 |

CBATH 重新构建并部署：

| 项 | 值 |
|---|---|
| build_id | `b20260924-235010-a71b7807` |
| deployed_sha256 | `896001a2773c985f1f633ff5cbaa244a3180037b86b6fbd6a24f43c6be9e0c1b` |
| source == deployed | ✅ 一致 |

> 注意：CBATH 的 build_id 已从 `b20260924-171754-2eeefc21` 变为 `b20260924-235010-a71b7807`。
> 原因是本轮为诊断临时编译过。**逻辑内容与 P1-005 时一致**（诊断文件已删除），
> 但 build_id / SHA256 不同，后续引用身份时需用新值。

### 5.3 未修改

- ❌ 旧 CombatBrain 源码 / 二进制 — **未改动**
- ❌ CombatBrain 的 MCM 配置 — 未改动
- ❌ `gabs-config\config.json` — 未改动（保持 P2-003 确定的有效顺序）

---

## 六、关于前台问题的确认

按用户要求核查：**GABS 没有"激活/聚焦游戏窗口"的能力**。

- 检索 GABS 二进制字符串，未发现 focus / foreground / activate 相关的工具或命令；
- `games_*` 工具集仅覆盖 start / stop / kill / status / show / list / connect / call_tool 等，
  **不含窗口管理**。

→ 因此"采样窗口内保持前台"必须由 **CBATH 之外的机制**保证（人工或外部脚本），
   不能指望 GABS，也不应为此修改 CBATH。

同时确认判定"模拟正在推进"需要**动态量**而非 `mission_time`：
P2-003 已实测到 `mission_time` 前进（57s→88s）但 Formation 位置完全不变的失焦场景。

---

## 七、下一步（待用户决定，本轮不执行）

阻塞已清除，可进入：

1. **实现 1 Hz 连续采样**（`SamplingMissionBehavior` + `get_last_run`）；
2. 采样时须同时满足"动态量变化"判据才能认为模拟在推进；
3. CombatBrain 侧命令记录的读取，按既定边界应放**独立脚本层**，
   不进入 CBATH 核心（其日志格式属旧版本语义）。
