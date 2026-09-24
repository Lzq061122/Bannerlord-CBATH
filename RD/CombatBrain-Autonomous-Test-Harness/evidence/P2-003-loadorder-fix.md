# P2-003 模块加载顺序诊断 — 结果：**根因已定位并解决**

日期：2026-09-24
类型：诊断实验（未修改 CombatBrain / Harmony / MCM / CBATH 任何实现文件）

---

## 一、结论（先说结果）

**根因是模块加载顺序，不是缺失依赖、不是版本不兼容、不是 CombatBrain 的问题。**

所有 Bootstrap 框架模块（Harmony / ButterLib / UIExtenderEx / MCMv5）**必须排在 Native 之前**。
把它们放在 Native 之后会导致模块加载中止（表现为"崩溃"）。

修正顺序后：

| 验证项 | 结果 |
|---|---|
| 游戏正常启动 | ✅ |
| GABP 桥接建立 | ✅ `started successfully and connected via GABP` |
| **CombatBrain 载入** | ✅ `active_modules` 含 `CombatBrain` |
| CBATH 工具可用 | ✅ 12 tools，`Re-synced 12 tools` |
| 进入 Mission | ✅ `battle_terrain_biome_096` |
| **Mission 持续运行** | ✅ **88.6 秒**（此前各次仅 2 秒） |
| CBATH Formation 读取 | ✅ 双方 4 + 5 阵型 |

---

## 二、根因证据

### 2.1 直接证据：模块顺序警告对话框

修正前，游戏弹出明确警告（从对话框子控件读出原文）：

```
Bannerlord.ButterLib is loaded after the Native!
Make sure Bannerlord.ButterLib is loaded before it!

Bannerlord.ButterLib is loaded after the SandBoxCore!
...
Bannerlord.ButterLib is loaded after the CustomBattle!
...
It's strongly recommended to terminate the game now. Do you wish to terminate it?
```

同样的警告随后来自 `Bannerlord.UIExtenderEx`，再来自 `Bannerlord.MBOptionScreen`。

**这是一个渐进暴露的过程**：每修好一个模块的位置，下一个模块才暴露出同样的抱怨。
这也说明此前把 `CombatBrain` 当作根因是**误判**——它排在最后，从未有机会执行。

### 2.2 佐证：XML 声明的加载约束

`Bannerlord.ButterLib` 与 `Bannerlord.UIExtenderEx` 的 `SubModule.xml` 均声明：

```xml
<DependedModuleMetadata id="Native" order="LoadAfterThis" version="v1.0.0.*" />
```

即这两个模块的**程序集必须先于 Native 加载**。

### 2.3 行为证据：日志从"零输出"变为"大量输出"

| | 修正前（任意崩溃配置） | **修正后** |
|---|---|---|
| `Configs\ModLogs\` 新文件 | **无**（最新停留在 2026-09-23） | **有** |
| `default20260924.log` | 不存在 | **55,356 bytes** |
| `trace20260924.txt` | 不存在 | **28,513 bytes** |
| `butterlib20260924.txt` | 不存在 | **22,175 bytes** |

崩溃时进程死在模块加载**之前**，因此零日志；修正后模块正常加载并开始写日志。

---

## 三、最终可用模块集

```
_MODULES_*Bannerlord.Harmony*Bannerlord.ButterLib*Bannerlord.UIExtenderEx*Bannerlord.MBOptionScreen*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*CombatBrain*CombatBrainAutonomousTestHarness*_MODULES_
```

顺序规则：**框架模块（Harmony → ButterLib → UIExtenderEx → MCMv5）→ 游戏原生 → CustomBattle → 被测 Mod**

实测 `active_modules` 返回：

```
Bannerlord.Harmony, Bannerlord.ButterLib, Bannerlord.UIExtenderEx, Bannerlord.MBOptionScreen,
Native, SandBoxCore, Sandbox, StoryMode, CustomBattle,
CombatBrain, CombatBrainAutonomousTestHarness
```

---

## 四、顺带确证的几点

### 4.1 MCM 的"40 个 DLL"确认是正常机制（**更正我此前的误判**）

日志给出了直接证据：

```
[INF]: Found implementation: Bannerlord.MBOptionScreen.v1.4.7.dll
[INF]: No exact match found. Selecting the latest available implementation.
[INF]: Loading implementation Bannerlord.MBOptionScreen.v1.4.7.dll for game v1.4.7
```

**MCM 的加载器主动扫描并按游戏版本挑选实现 DLL。** 40 个 DLL（FileVersion 均为 5.12.2.0，
内容哈希互不相同）是该机制的数据集，**不是目录污染**。

→ **确认"不要删/换其中任何一个"的判断是正确的。**

### 4.2 MCM 有一个非致命错误（值得记录，但未阻断）

```
[ERR]: SubModule Bannerlord.BUTR.Shared.Utils.MBSubModuleBaseSimpleWrapper's default constructor
       could not be converted to a delegate! Assembly: Bannerlord.MBOptionScreen.v1.4.7
[ERR]: AccessTools2.DeclaredMethod: Could not find method for type
       'TaleWorlds.GauntletUI.WidgetInfo' and name 'Reload' and parameters ''
[ERR]: AccessTools2.Method: Could not find method for type
       'TaleWorlds.CampaignSystem.CampaignBehaviors.CampaignBehaviorManager'
       and name 'OnGameLoaded' and parameters ''
```

这些是 MCMv5 与游戏 1.4.8 的**轻度 API 不匹配**（Harmony 找不到目标方法）。
**但游戏仍正常启动并进入 Mission**，MCM 最终报告 `MCM.UI - Enabled`。

→ 属于**可容忍的噪声**，不是崩溃原因。但记录在案，若后续出现 UI 相关异常可回溯。

### 4.3 ButterLib 正常初始化

```
[Bannerlord.ButterLib.ButterLibSubModule] [INF]: Created GameScope
```

---

## 五、CombatBrain 运行状态（本轮达到的验证程度）

### 5.1 已验证

| 项 | 状态 | 证据 |
|---|---|---|
| CombatBrain 模块被游戏加载 | ✅ **VERIFIED** | `active_modules` 含 `CombatBrain` |
| 游戏在 CombatBrain 存在下正常启动 | ✅ **VERIFIED** | 无对话框，正常进入主菜单 |
| 进入真实 Mission 且不崩溃 | ✅ **VERIFIED** | `mission_running: true`，持续 88.6 秒 |
| CBATH 在 CombatBrain 存在下正常读取 Formation | ✅ **VERIFIED** | 双方 4+5 阵型完整返回 |

### 5.2 尚未验证（重要）

| 项 | 状态 | 说明 |
|---|---|---|
| **CombatBrain 的 Mission 逻辑确实在执行** | ❌ **未验证** | 见下 |
| CombatBrain 的 telemetry 输出 | ❌ **未找到** | 见下 |

**为什么未验证**：`CombatBrain` 未写入 `Configs\ModLogs\default20260924.log`
（全文 grep `CombatBrain|战斗AI|CPS|Provenance|Telemetry|Shadow` 无匹配），
也**未在任何位置新建日志文件**（全盘搜索 `Documents` + 游戏目录，无 CombatBrain 命名的输出）。

因此**目前没有 CombatBrain 自身产出的运行时证据**。
"模块被加载"（已证）与"其 Mission 逻辑真的在执行"（未证）是两件事。

### 5.3 一个干扰因素：游戏窗口未获得焦点

实测战斗期间 `mission_time` 从 57s 推进到 88s，但 Formation 位置**两次采样完全相同**：

```
Infantry position (1004.979, 982.833)  ← 57s
Infantry position (1004.979, 982.833)  ← 71s
```

排查结果：前台窗口是 Edge（`CB项目整理... - Microsoft Edge`），**Bannerlord 窗口未获焦点**，
后台时游戏不推进战场模拟。尝试 `SetForegroundWindow` 未成功（Windows 前台锁定）。

→ **这不影响"能进入并保持 Mission"的结论**，但意味着本轮**没有产生真实的行为演化数据**。
若后续要做时序观测，必须保证游戏窗口在前台（这是一个需要固化到流程里的操作前提）。

---

## 六、环境陷阱清单（本阶段累积）

| # | 陷阱 | 处理 |
|---|---|---|
| 1 | `safely_exited=0` → Safe Mode 静默阻断 | 每次启动前复位为 1 |
| 2 | 模块集变化 → `"Mod change detected"` 对话框 | 定位窗口 + PostMessage VK_RETURN |
| 3 | **框架模块排在 Native 之后 → 加载中止** | **顺序：Harmony/ButterLib/UIExtenderEx/MCM 在前** |
| 4 | 崩溃报告对话框由 `csrss.exe` 承载，不在游戏 PID 下 | 必须枚举全部可见窗口 |
| 5 | 游戏崩溃会带走 `steam.exe` 主进程 | 启动前用精确匹配检查并重启 |
| 6 | 游戏窗口失焦 → 战场模拟不推进 | 时序观测前需确保窗口在前台 |
| 7 | 强杀后产生僵尸进程（`HasExited=True`，句柄不释放） | 已记录，不影响 JSON 配置修改 |

---

## 七、环境副作用

| 项 | 状态 |
|---|---|
| 活进程残留 | **0** |
| 僵尸进程累计 | 6 个（本阶段） |
| 修改的文件 | 仅 `gabs-config\config.json` |
| 未修改 | CombatBrain / Harmony / MCM / CBATH 源码、MCM 目录内容 |

---

## 八、下一步

按用户设定的 smoke test 判据，**1、2、3 项已达成，第 4 项（"CombatBrain 的 Mission 行为确实开始执行"）尚未达成**。

建议的下一步（**待用户决定，本轮不执行**）：

1. **定位 CombatBrain 的日志输出位置**。已知 `CombatLog` 有 `public static OverridePath`，
   可重定向输出路径。需要确认其默认路径与写入条件。
2. **确认 `CombatAiMissionLogic.OnMissionTick` 是否真被调用**。
   最直接的方式是让 CombatBrain 侧产生一条可读的运行证据（它已有 telemetry 与 CombatLog 设施）。
3. **保证游戏窗口在前台**，以产生真实的行为演化数据。

> 注意：以上第 1、2 项涉及"如何让 CombatBrain 产出可读证据"，
> 按用户此前确定的边界，这属于**极薄的版本无关观测契约**范畴，
> 不应围绕旧 CombatBrain 的内部类 / 枚举 / 日志文本设计。
