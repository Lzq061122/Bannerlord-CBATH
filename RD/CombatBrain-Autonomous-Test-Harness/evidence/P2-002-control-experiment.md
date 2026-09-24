# P2-002 对照实验 — 结果：崩溃在无 CombatBrain 时**仍然存在**

日期：2026-09-24
类型：诊断实验（只读排查，未修改任何实现文件）

---

## 一、实验设计

| 项 | 内容 |
|---|---|
| 目的 | 回答唯一问题：**当前启动崩溃是否在没有 CombatBrain 的情况下仍然存在？** |
| 实验组 | `Native+SandBoxCore+Sandbox+StoryMode+CustomBattle+Harmony+MCM+CombatBrain+CBATH` |
| **对照组** | `Native+SandBoxCore+Sandbox+StoryMode+CustomBattle+Harmony+MCM+CBATH`（**去掉 CombatBrain**） |
| 保持不变 | 启动参数、`/anticheat`、GABS 配置、游戏版本 v1.4.8.119303 |

对照组的 `config.json` 模块集（已校验 `CombatBrain in set? False`）：

```
_MODULES_*Native*SandBoxCore*Sandbox*StoryMode*CustomBattle*Bannerlord.Harmony*Bannerlord.MBOptionScreen*CombatBrainAutonomousTestHarness*_MODULES_
```

---

## 二、结果

**对照组崩溃，且失败形态与实验组一致。**

| 指标 | 实验组（含 CombatBrain） | **对照组（无 CombatBrain）** |
|---|---|---|
| 崩溃报告对话框 | ✅ `The application faced a problem...` | ✅ **同样出现** |
| Responding | False | False |
| Suspended 线程 | 202 / 203 | **211 / 212** |
| CPU 冻结 | 8.20s | 16.03s |
| GABP 监听端口 | 无 | **无** |
| ModLogs 新日志 | 无 | **无**（最新仍为 2026-09-23） |
| 到达模块加载阶段 | ❌ 否 | ❌ **否** |

对照组进程 12832 实测：

```
CPU=16.03125  Mem=1972.2MB  Responding=False  HasExited=False  Threads=212
Suspended threads: 211 / 212
```

崩溃报告对话框由 **`csrss.exe`（pid 1420，Windows 崩溃报告基础设施）** 承载，
原文：`The application faced a problem. We need to collect necessary files to fix this problem.`
——与实验组完全相同。

---

## 三、结论

### 3.1 主结论

> **CombatBrain 可以在当前阶段被排除出启动崩溃的根因范围。**

证据：去掉 CombatBrain 后，崩溃**一模一样地复现**（同样对话框、同样量化形态、同样零 ModLogs）。
崩溃发生在模块加载**之前**，因此 CombatBrain 的代码根本没有机会被执行。

### 3.2 问题范围收敛到

**Harmony / MCM 的引入本身**，或它们与当前游戏版本的兼容性。

具体地说：`Native+SandBoxCore+Sandbox+StoryMode+CustomBattle+CBATH` 在 P1-005 三轮中
**可稳定启动**（3/3 PASS）；一旦加入 `Bannerlord.Harmony + Bannerlord.MBOptionScreen` 就崩溃。

### 3.3 顺带排除

- ❌ 不是 CombatBrain.dll 的 API 不兼容（它没被加载）
- ❌ 不是"CombatBrain 与 MCM/Harmony 的组合问题"（无 CombatBrain 也崩）
- ✅ 是 Harmony/MCM 这条线

---

## 四、本轮新收集的证据（按你的要求，只记录不处置）

### 4.1 MCM 的 `SubModule.xml` 声明

`Bannerlord.MBOptionScreen` 版本 `v5.12.2`，**声明了三个硬依赖**：

```xml
<DependedModules>
  <DependedModule Id="Bannerlord.Harmony"            DependentVersion="v2.2.2"  />
  <DependedModule Id="Bannerlord.ButterLib"          DependentVersion="v2.11.1" />
  <DependedModule Id="Bannerlord.UIExtenderEx"       DependentVersion="v2.13.3" />
</DependedModules>
```

**重要发现**：MCM 声明的依赖里有 **ButterLib** 和 **UIExtenderEx**，
而当前模块集**只提供了 Harmony**，缺 ButterLib 与 UIExtenderEx。

这是**有证据支持的崩溃候选原因**（不是猜测）：
MCM 的硬依赖未满足 → 模块加载失败 → 崩溃。

### 4.2 MCM 实际加载哪些 DLL

`SubModule.xml` 的 `<SubModules>` 声明 3 个入口：

| Name | DLLName | SubModuleClassType |
|---|---|---|
| `MCMv5` | `MCMv5.dll` | `MCM.MCMSubModule` |
| `MCMv5 Basic Implementation` | `MCMv5.dll` | `MCM.Internal.MCMImplementationSubModule` |
| `Bannerlord Module Loader` | `Bannerlord.ModuleLoader.Bannerlord.MBOptionScreen.dll` | `Bannerlord.ModuleLoader.Bannerlord_MBOptionScreen` |

第三个入口带 **`LoaderFilter`** 标签：

```xml
<Tag key="LoaderFilter" value="Bannerlord.MBOptionScreen.*.dll" />
```

### 4.3 关于"40+ 历史 DLL"的更正

**我上一轮的表述是错的，需要更正。**

实测（`bin\Win64_Shipping_Client`，共 **40** 个 `Bannerlord.MBOptionScreen.v*.dll`，合计 12.1 MB）：

| 检查 | 结果 |
|---|---|
| FileVersion | **全部为 `5.12.2.0`** |
| ProductVersion | **全部为 `5.12.2+1182f436...`** |
| 内容哈希 | 40 个**互不相同**（40 个唯一 SHA256） |

**这不是"目录脏了"或"混入了历史版本"**，而是 MCM 的**版本适配机制**：
为不同游戏版本各提供一个适配 DLL，由 `LoaderFilter` 在运行时挑选。
40 个 DLL 版本号相同但内容不同，符合该机制特征。

→ **"40+ DLL" 应降级为"正常机制"，不再是异常线索。**
→ 也因此，**没有依据去删除或替换其中任何一个**（与你的判断一致）。

### 4.4 CombatBrain.dll 对 MCM / Harmony 的程序集引用

从 DLL 元数据提取（`MCM.Abstractions.*`、`HarmonyLib*`）：

```
MCM.Abstractions.Attributes.v2 / MCM.Abstractions.Attributes
MCM.Abstractions.Base.Global / MCM.Common / MCMv5
HarmonyLib / HarmonyId / HarmonyMethod / 0Harmony / _harmony
```

`MCMv5.dll`（5.12.2）自身引用 `HarmonyLib` 与 `MCM.Abstractions.*` 系列。

### 4.5 Harmony 模块

`Bannerlord.Harmony` 目录含两个版本的 `0Harmony.dll` / `Bannerlord.Harmony.dll`
（两套文件大小不同：`0Harmony.dll` 均为 292352，但 `Bannerlord.Harmony.dll`
分别为 199168 与 198144）——**同样疑似版本适配机制**，与 MCM 情况类似。

---

## 五、环境陷阱（本轮新增/确认）

### 5.1 `"Mod change detected"` 对话框

**触发条件**：只要模块集发生变化，启动时必定弹出：

```
DIALOG: Mod change detected
   确定
   A change in your active mods was detected.
   Deleting the runtime shader cache to avoid rendering issues.
```

**危害**：静默阻断模块加载。不处理会被误判为"崩溃"或"编译错误"。

**本轮处理方式**（保持一致，避免成为额外变量）：定位窗口 → `SetForegroundWindow` →
`PostMessage` 两次（`WM_KEYDOWN`/`WM_KEYUP`，VK_RETURN=0x0D）。

本轮对照组同样弹出并已同样处理，处理后才继续观察。

### 5.2 崩溃报告对话框由 `csrss.exe` 承载

`The application faced a problem...` 对话框的宿主进程是 **`csrss.exe`**，
不是游戏进程。因此按游戏 PID 枚举窗口**找不到它**——
必须枚举全部可见窗口。这是一个容易漏判的点。

### 5.3 `steam.exe` 会随崩溃一起消失

对照实验开始前实测 `steam.exe = 0`（只剩 `steamwebhelper` 孤儿进程）。
这是继 P1-005 之后**第二次**遇到同一现象：
**游戏崩溃会带走 Steam 主进程**，下次启动前必须先重启 Steam 并等待就绪，
否则会叠加出"GABP 未就绪"的第二层故障，掩盖真实原因。

---

## 六、环境副作用

| 项 | 状态 |
|---|---|
| 活进程残留 | **0** |
| 僵尸进程 | 累积 4 个（51164 / 45068 / 35920 / 12832，均 `HasExited=True`） |
| 本机时间 | 实测 23:00（注意：早前命令中我写的 `-gt 21:00` 过滤边界有误，已用 22:50 复核，结论不变） |

---

## 七、下一步（按你的指令，本轮到此停止）

**不继续试第三种模块组合。** 可区分 Harmony 与 MCM 的证据线索，按证据强度排序：

| # | 线索 | 证据强度 | 说明 |
|---|---|---|---|
| 1 | **MCM 缺 ButterLib + UIExtenderEx** | **强（有 XML 声明）** | MCM 硬依赖两个未提供的模块；这是最可能的直接原因 |
| 2 | Harmony 是否能单独与游戏共存 | 待测 | 需一次只加 Harmony 的最小实验 |
| 3 | 两个 `Bannerlord.Harmony.dll` 是否为版本适配 | 弱 | 与 MCM 同型机制，倾向正常 |

**我倾向先验证线索 1**：补齐 MCM 声明的 `ButterLib` + `UIExtenderEx` 依赖。
理由是它是**唯一有明文声明支持**的假设，且成本极低（两个模块本机已存在，只需加入模块集）。

但按你的指令，**本轮不执行**，等你决定。
