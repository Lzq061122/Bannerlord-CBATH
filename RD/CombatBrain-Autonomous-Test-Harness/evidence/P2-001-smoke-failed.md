# P2-001 Smoke Test — FAILED (blocked at launch)

日期：2026-09-24
目标：把 CombatBrain 加入测试模块集，跑通 smoke test

结果：**FAILED — 游戏在启动阶段崩溃，未进入任何模块加载**

---

## 一、变更

`gabs-config\config.json` 模块集从：

```
_MODULES_*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*CombatBrainAutonomousTestHarness*_MODULES_
```

改为：

```
_MODULES_*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*Bannerlord.Harmony*Bannerlord.MBOptionScreen*CombatBrain*CombatBrainAutonomousTestHarness*_MODULES_
```

新增三个模块：`Bannerlord.Harmony`、`Bannerlord.MBOptionScreen`、`CombatBrain`。
九个模块的 `SubModule.xml` 均已验证存在。JSON 通过 `ConvertFrom-Json` 校验。

---

## 二、三次启动尝试的观测

| # | 时间 | PID | 模块集 | 结果 |
|---|---|---|---|---|
| 1 | 20:40 | 51164 | 仅 +CombatBrain | 弹 `Error while loading 战斗AI系统 (Combat Brain)` — 依赖冲突 |
| 2 | 20:45 | 45068 | +Harmony +MCM | 无错误对话框，但进程冻死（CPU 冻结 13.28s，全线程 Suspended） |
| 3 | 20:49 | 35920 | 同上（未改动） | 弹崩溃报告对话框 `The application faced a problem...`，随后冻死 |

### 尝试 1 的原始错误（关键证据）

从对话框子控件读出的原文：

```
"战斗AI系统 (Combat Brain).CombatBrainSubModule" submodule could not be loaded
correctly due to a dependency conflict. This may cause the game to experience
stability issues.
```

**根因**：CombatBrain.dll 引用了 `MCMv5` 与 `HarmonyLib`，但这两个模块当时不在模块集中。

元数据证据（DLL 字符串提取）：

```
MCM.Abstractions.Attributes.v2 / MCMv5 / MCM.Abstractions.Base.Global / MCM.Common
HarmonyLib / HarmonyId / 0Harmony / _harmony
```

### 尝试 2 / 3 的观测

补上 Harmony + MCMv5 后，**依赖冲突错误消失**（不再弹 CombatBrain 加载失败），但游戏改为在更早的阶段冻死：

| 指标 | 尝试 2 (45068) | 尝试 3 (35920) |
|---|---|---|
| 内存 | 1945.1 MB | 1933.7 MB（60 秒内零变化） |
| CPU | 13.28s（冻结） | 8.20s（冻结） |
| Responding | False | False |
| Suspended 线程 | — | **202 / 203** |
| 可见对话框 | 无 | 崩溃报告对话框（后消失） |
| GABP 监听端口 | 无 | 无 |

**ModLogs 零写入**：`Configs\ModLogs\` 最新文件仍为 2026-09-23，尝试 2/3 未产生任何新日志。
游戏目录下除 `steam_appid.txt` 外无任何新文件。说明进程在**模块加载之前**就已死掉。

---

## 三、结论与判定

| 判断 | 依据 |
|---|---|
| 模块集修改**本身已生效** | `bridge.json` 的 `configRevision` 从 `sha256:eb202e3454d5` 变为 `sha256:3ebe51fce845` |
| 第一次失败 = **CombatBrain 缺 MCMv5/Harmony 依赖** | 对话框明示 "dependency conflict"，且 DLL 确实引用这两个程序集 |
| 第二次失败 = **加入 Harmony/MCMv5 后游戏启动崩溃** | 全线程 Suspended、零日志、崩溃报告对话框 |
| **未验证**：CombatBrain 是否能真正加载成功 | 从未到达模块加载阶段 |
| **未验证**：CBATH 原有 Formation 读取 | 从未进入 Mission |
| **未验证**：CombatLog 输出路径与格式 | 无 Mission、无日志 |

**smoke test 失败，且失败点在"启动兼容性"，不在 CBATH 侧。**

---

## 四、尚未排除的可能性

以下都**没有证据**，不能断言是哪一条：

1. `Bannerlord.Harmony` + `MCMv5` 与游戏 v1.4.8.119303 存在版本不兼容；
2. `Bannerlord.MBOptionScreen` 目录下存在大量历史版本 DLL（`v1.0.0` ~ `v1.4.7` 共 40+ 个 `Bannerlord.MBOptionScreen.*.dll`），可能造成模块加载器选择错误版本；
3. CombatBrain.dll（2026-09-16 构建）与当前游戏版本的 API 不兼容；
4. 启动方式（`DirectPath` + `/anticheat`）与 MCM/Harmony 的组合有问题。

---

## 五、环境副作用（已处理）

三次尝试共产生 **3 个僵尸进程**（`HasExited=True` 但句柄未释放）：

```
51164 (20:40) / 45068 (20:45) / 35920 (20:49)  — 全部 HasExited=True
```

活进程残留：**0**。这是交接文档 §8 已记录的已知现象。

---

## 六、每轮需人工处理的对话框（新增发现）

模块集一变，游戏会弹 **"Mod change detected"**（删除 shader 缓存提示），
**静默阻断模块加载**。必须按 Enter 确认。

三次尝试中共弹出并处理了 2 次（尝试 1 首次、尝试 2 因模块集变化再次弹出）。

> 这意味着：任何改变模块集的启动，都需要先处理这个对话框，
> 否则会误判为"崩溃"或"编译错误"。

---

## 七、下一步（未执行，待决策）

需要先定位崩溃根因，而不是继续盲目重试。候选验证路径：

1. **检查 MCM 模块目录的版本冲突** — 40+ 个历史版本 DLL 是否导致加载器选错；
2. **最小化复现** — 只用 `Native+SandBoxCore+Sandbox+StoryMode+CustomBattle+Harmony+MCM`（不含 CombatBrain），确认 Harmony+MCM 本身能否与游戏共存；
3. **对照** — 用同一模块集但去掉 CombatBrain，若仍崩溃，则问题在 Harmony/MCM，与 CombatBrain 无关；
4. **查 QoL/ModLogs 之外的崩溃线索** — 例如游戏目录下可能的 `rgl_log`、Windows 事件日志。
