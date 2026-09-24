# P1-003 red/green 记录

日期：2026-09-24

## 被测行为

`cbath/get_all_formations` 必须返回当前 Mission 中**所有 Team** 的非空 Formation，且每个 Formation 携带 prompt 要求的字段：

```text
team_id / side
formation_index / formation_class
unit_count
position / facing
movement_order / arrangement_order / firing_order
is_ai_controlled
```

验收还要求：至少两个不同 Team，双方各至少一个非空 Formation。

---

## RED

**测试**：`tools/test-p1-003.ps1`

**运行**：先经 DSH 启动游戏（`mcp__gabs__games_start`），再跑测试。

**输出**：

```text
--- raw response line ---
<< {"jsonrpc":"2.0","id":3,"result":{..."text":"Tool 'cbath/get_all_formations' not found for game 'bannerlord148'. Use games_tool_names to discover available names first."...}}

FAIL(1): tool cbath/get_all_formations is not registered
EXIT=1
```

失败原因正是"工具未实现"，不是语法错误、不是环境缺失 —— 合格的 red 证据。

---

## 实现

新增 `experiments/test-mod/CBATH/FormationProbe.cs`：

- 遍历 `Mission.Current.Teams`
- 每队遍历 `FormationsIncludingEmpty`，跳过 `CountOfUnits == 0`
- 读 `FormationIndex`、`RepresentativeClass`、`CountOfUnits`、`CurrentPosition`、`Direction`、
  `IsAIControlled`，以及 `OrderController.GetActiveMovementOrderOf / ArrangementOrderOf / FiringOrderOf`
- 全部游戏 API 调用经 `MainThreadDispatcher` 派发到主线程
- `Mission.Current == null` 时返回 `status=no_mission` 并说明原因，**不伪造空数据**

`CbathTools.cs` 增加 `cbath/get_all_formations`；csproj 加入 `FormationProbe.cs`。

### 编译踩坑

`Formation.CurrentPosition` 与 `Formation.Direction` 在 1.4.8 中**都是 `Vec2`**，不是 `Vec3`。
我按 `CurrentPosition=Vec3 / Direction=Vec2` 的猜测写了两次都编译失败：

```text
error CS1503: 参数 1: 无法从"TaleWorlds.Library.Vec2"转换为"TaleWorlds.Library.Vec3"
```

最终两者都用 `Vec2ToObj`。教训：向量类型不要靠猜，看编译器报错逐个对齐更快。

---

## GREEN（部分）

**部署**：`build_id=b20260924-123350-1cc71839`，SHA-256 `8b0c2385…41f708`，源/部署一致。

**关键坑**：部署后直接调用仍报 `not found`。原因是 **GABS 在 connect 时快照工具列表**，
需要重新 `games_connect` 才会同步（返回 `Re-synced 4 tools`）。

**经 DSH 官方客户端调用 `cbath/get_all_formations`**：

```json
{"reason":"Mission.Current is null","status":"no_mission","teams":[]}
```

**运行断言器**：

```text
PARTIAL(2): tool present and correctly reports no_mission
            remaining: run inside a real battle with both sides present
EXIT=2
```

### 状态判定

| 判据 | 状态 |
|---|---|
| 工具已注册 | ✅ |
| 无战斗时不伪造数据，明确返回 no_mission | ✅ |
| 双方 Formation 字段完整 | ❌ 尚缺真实 Mission |
| 两个不同 Team 各非空 Formation | ❌ 尚缺真实 Mission |

**因此 P1-003 尚未完整 green。** exit 2 表示实现方向正确、工具行为正确，只差一个真实战斗场景。

---

## 另一个坑：独立 gabs 进程拿不到工具

测试脚本最初尝试自己起 gabs 进程调用，结果：

```text
Game 'bannerlord148' is already owned by another active GABS session (pid 25936).
Skipping games_connect here to avoid competing...
No game-specific tool names available for 'bannerlord148'.
```

GABS 有会话所有权机制。DSH 持有的会话优先，独立进程被拒绝且拿不到工具列表。

这也正好印证 spec AC9 的要求：**验收必须走 DSH 官方客户端**。
测试脚本因此改造为断言器：由 DSH 调用取得 payload，喂给脚本做字段校验。

---

## 进入真实 Mission 的前置修改

原本的最小模块集 `Native + CBATH` **没有 CustomBattle，根本进不了自定义战斗**。
把 GABS 配置的启动模块改为：

```text
_MODULES_*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*CombatBrainAutonomousTestHarness*_MODULES_
```

改模块集后首次启动弹 **"Mod change detected"** 确认对话框，阻断 Mod 加载
（表现为进程在跑但完全没有 CBATH 产物文件）。用一次 Enter 确认后消失，之后不再出现。

确认后重启，Mod 正常加载：

```text
active_modules=Native,SandBoxCore,Sandbox,StoryMode,CustomBattle,CombatBrainAutonomousTestHarness
build_id=b20260924-123350-1cc71839
```

---

## GREEN（完整）

进入真实 Custom Battle 后经 DSH 调用 `cbath/get_all_formations`：

```json
{"mission_name":"battle_terrain_biome_096","mission_time":"21.648","status":"ok","teams":[
 {"formation_count":1,"formations":[{"arrangement_order":"ArrangementLine",
  "facing":{"x":"0.604","y":"0.797"},"firing_order":"FireAtWill","formation_class":"Infantry",
  "formation_index":0,"is_ai_controlled":true,"movement_order":"Move",
  "position":{"x":"1303.975","y":"889.890"},"unit_count":98}],
  "is_player_team":true,"side":"Defender","team_id":0},
 {"formation_count":1,"formations":[{"arrangement_order":"ArrangementLine",
  "facing":{"x":"-0.604","y":"-0.797"},"firing_order":"FireAtWill","formation_class":"Infantry",
  "formation_index":0,"is_ai_controlled":true,"movement_order":"Move",
  "position":{"x":"1424.776","y":"1051.523"},"unit_count":90}],
  "is_player_team":false,"side":"Attacker","team_id":1}]}
```

运行断言器：

```text
teams reported: 2
team side=Defender team_id=0 formations=1 nonEmpty=1
team side=Attacker team_id=1 formations=1 nonEmpty=1
PASS: 2 sides with non-empty formations
      team fields + formation fields all present
EXIT=0
```

### 验收对照

| 判据 | 结果 |
|---|---|
| 至少两个不同 Team | ✅ Defender(0) / Attacker(1) |
| 双方至少一个非空 Formation | ✅ 98 / 90 |
| `team_id` / `side` | ✅ 0/Defender、1/Attacker |
| `formation_index` / `formation_class` | ✅ 0 / Infantry |
| `unit_count` | ✅ 98 / 90 |
| `position` | ✅ {1303.975, 889.890} / {1424.776, 1051.523} |
| `facing` | ✅ {0.604, 0.797} / {-0.604, -0.797}（双方相向，合理） |
| `movement_order` | ✅ Move |
| `arrangement_order` | ✅ ArrangementLine |
| `firing_order` | ✅ FireAtWill |
| `is_ai_controlled` | ✅ true |

双方 facing 恰好互为反向，位置相距约 200 单位，符合两军对峙的物理直觉 —— 数据不是编造的。

### 数据随时间真实变化（第二次采样）

mission_time 21.648 → 84.058：

| Team | 第一次 | 第二次 |
|---|---|---|
| Defender | 98 | 0（被打光） |
| Attacker | 90 | 51 |

### 断言器健全性检查

把第二次（仅剩一方）的数据喂进去，断言器正确拒绝：

```text
team side=Defender team_id=0 formations=0 nonEmpty=0
team side=Attacker team_id=1 formations=1 nonEmpty=1
FAIL(1): need non-empty formations on 2 different sides, got 1
EXIT=1
```

即测试不是无条件放行。

### 测试自身的 bug（已修）

第一版断言器把 `team_id` / `side` 放在 formation 层校验，导致
`FAIL(1): formation missing field 'team_id'`。实际这两个字段属于 team 层。
修的是测试分层，不是放宽断言：team 层校验 `team_id/side/formations`，
formation 层校验其余 9 个字段。

---

## 结论

**P1-003 PASS（EXIT=0）。**

注意：本次进入 Mission 使用了 prompt 允许的**一次人工 bootstrap**（手工进 Custom Battle）。
这不构成最终方案 —— P1-004 必须实现结构化、无人值守的固定 Mission 进入。

证据文件：
- `evidence/p1-003-formations-both-sides.json`（PASS 用）
- `evidence/p1-003-formations-single-side.json`（健全性检查用）
- `tools/test-p1-003.ps1`、`tools/run-p1-003-green.bat`
