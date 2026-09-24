# P1-001 — Runtime Identity 实验记录

日期：2026-09-24 Asia/Shanghai
环境：Bannerlord v1.4.8.119303（Steam buildid 24573425），游戏目录 `E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord`

---

## 实验 A — 最小 Mod 编译与部署

- **Goal**：构建只含 runtime identity 的最小 Test Mod，证明构建/部署产物可归因。
- **Hypothesis**：用构建期注入的唯一 `build_id` + DLL SHA-256，可以把"源码→构建 DLL→部署 DLL"三者绑定。
- **Change**：新建 `experiments/test-mod/CBATH/`（4 个文件）与 `build-deploy.ps1`。
- **Command**：`powershell.exe -File build-deploy.ps1`
- **Observed Result**：`build_id=b20260924-000212-9ec26d5a`，source 与 deployed SHA-256 同为 `78922e246af0cd5b8cdcd2f20fe0f036fb4dbdc0cf953823fc0b7371ff740ecf`，脚本退出码 0。
- **PASS / FAIL**：PASS（仅构建层，不构成 P1-001 验收）
- **Evidence**：`evidence/p1-001-launch-args.txt`
- **Next Decision**：部署已验证，下一步要真实游戏运行证据。

---

## 实验 B — 首次启动（失败：Safe Mode 对话框）

- **Goal**：启动游戏并取得运行时身份。
- **Hypothesis**：`Bannerlord.exe /singleplayer _MODULES_*Native*CombatBrainAutonomousTestHarness*_MODULES_ /anticheat` 能加载 Mod。
- **Change**：启动前手动把 `engine_config.txt` 的 `safely_exited` 改为 `0`（**错误方向**）。
- **Command**：`Start-Process Bannerlord.exe "/singleplayer _MODULES_..."` → PID 45456
- **Observed Result**：进程存活 75 秒，但**没有任何身份文件、没有新 mod 日志**。枚举可见窗口发现 PID 45456 的窗口标题为 **`Safe Mode`**。
- **PASS / FAIL**：**FAIL**
- **失败含义**：`safely_exited = 0` 对 Bannerlord 表示"上次异常退出"，于是弹出 Safe Mode 对话框并**阻断 mod 加载**。这与 Phase 0 风险登记第 3 项一致（GABS 脚本也专门处理这个标志），但方向被我读反：正确做法是启动时保证为 `1`。
- **Evidence**：窗口枚举输出（PID 45456 | Safe Mode）
- **Next Decision**：复位为 1 后重试。

---

## 实验 C — 修正后首次运行

- **Goal**：同实验 B，但 `safely_exited = 1`。
- **Hypothesis**：Safe Mode 对话框消失后 Mod 会被正常加载。
- **Change**：`engine_config.txt` 设回 `safely_exited = 1`；杀掉 PID 45456；清空 `Documents\CommandBrainATH\`。
- **Command**：同上启动 → PID 48340
- **Observed Result**：40 秒后出现 `cbath-runtime-identity-48340.txt`：

```text
CBATH_RUNTIME_IDENTITY
module=CombatBrainAutonomousTestHarness
build_id=b20260924-000212-9ec26d5a
build_timestamp=2026-09-23T16:02:12Z
assembly_version=1.0.0.0
mvid=cedafa65-7f4e-4a97-b791-2cb7655730c7
assembly_location=...\Modules\CombatBrainAutonomousTestHarness\bin\Win64_Shipping_Client\CombatBrainAutonomousTestHarness.dll
assembly_sha256=78922e246af0cd5b8cdcd2f20fe0f036fb4dbdc0cf953823fc0b7371ff740ecf
game_version=v1.4.8.119303
pid=48340
active_modules=TaleWorlds.ModuleManager.ModuleInfo,TaleWorlds.ModuleManager.ModuleInfo
```

- **PASS / FAIL**：**PASS（核心验收达成）**；但 `active_modules` 只输出了类型名，是可读性缺陷。
- **Evidence**：`cbath-runtime-identity-48340.txt`
- **Next Decision**：修 `active_modules` 序列化，并用**新 build_id 再跑一次**，同时证明"改代码→新构建→游戏加载新 DLL"。

---

## 实验 D — 修改后重建并复验

- **Goal**：证明构建身份链路不是偶然，且新构建真的被加载。
- **Hypothesis**：重新构建产生新 `build_id`/新 SHA，运行时应报告新值而非旧值。
- **Change**：
  1. `RuntimeIdentity.cs`：`active_modules` 改为取 `ModuleInfo.Id` 后 `string.Join`。
  2. `build-deploy.ps1`：新增启动前强制把 `safely_exited` 复位为 `1`（因为杀进程后游戏会写回 0）。
- **Command**：`powershell.exe -File build-deploy.ps1` → 启动 → PID 45760
- **Observed Result**：

```text
CBATH_RUNTIME_IDENTITY
module=CombatBrainAutonomousTestHarness
build_id=b20260924-000806-e10595f1
build_timestamp=2026-09-23T16:08:06Z
assembly_version=1.0.0.0
mvid=4d59f39c-88c4-4e96-9b1c-064701f5331a
assembly_location=...\Modules\CombatBrainAutonomousTestHarness\bin\Win64_Shipping_Client\CombatBrainAutonomousTestHarness.dll
assembly_sha256=705d08c476daa4981b63dccd87c7b58a2500423f4e3c6e532d609c51479be00e
game_version=v1.4.8.119303
pid=45760
active_modules=Native,CombatBrainAutonomousTestHarness
```

- **PASS / FAIL**：**PASS**
- **Evidence**：`cbath-runtime-identity-45760.txt`
- **Next Decision**：P1-001 判定通过，进入 P1-002。

---

## P1-001 验收对照

| 要求 | 状态 |
|---|---|
| `module = CombatBrainAutonomousTestHarness` | ✅ 运行时报告 |
| `build_id` 每次构建可变 | ✅ 两次构建分别为 `b20260924-000212-9ec26d5a` / `b20260924-000806-e10595f1` |
| `build_timestamp` | ✅ |
| `assembly_version` | ✅ `1.0.0.0` |
| `game_version` | ✅ `v1.4.8.119303` |
| `git_commit` | ⚠️ 未注入（本实验目录不在 git 仓库中；P1-006 若需要再补） |
| 日志 `CBATH_RUNTIME_IDENTITY` | ✅ 同时写入独立文件与游戏日志 |
| 证明"Bannerlord 实际加载了该 DLL" | ✅ 运行时 `assembly_sha256` == 部署路径文件 SHA == 构建路径文件 SHA |

## 四者归因链（实验 D）

| 环节 | 值 |
|---|---|
| 构建 build_id | `b20260924-000806-e10595f1` |
| 运行时 build_id | `b20260924-000806-e10595f1` |
| 构建路径 DLL SHA-256 | `705d08c476daa4981b63dccd87c7b58a2500423f4e3c6e532d609c51479be00e` |
| 部署路径 DLL SHA-256 | `705d08c476daa4981b63dccd87c7b58a2500423f4e3c6e532d609c51479be00e` |
| 运行时自报 SHA-256 | `705d08c476daa4981b63dccd87c7b58a2500423f4e3c6e532d609c51479be00e` |
| MVID | `4d59f39c-88c4-4e96-9b1c-064701f5331a` |

## 本阶段发现的可复用约束

1. **启动前必须 `safely_exited = 1`**，否则弹出 Safe Mode 对话框并静默阻断所有 Mod 加载（进程活着、无日志，极易误判为"Mod 没编译对"）。已固化进 `build-deploy.ps1`。
2. 杀掉游戏进程后，游戏会把 `safely_exited` 写回 `0`；因此每次启动前都要复位。
3. 最小可用启动参数：`Bannerlord.exe /singleplayer _MODULES_*Native*CombatBrainAutonomousTestHarness*_MODULES_ /anticheat`，可用最小模块集排除其他 Mod 干扰。
4. 运行时身份除写入游戏日志外，**另写独立文件** `Documents\CommandBrainATH\cbath-runtime-identity-<pid>.txt`，避免依赖 mod 日志系统是否启用。

## P1-002 前置阻塞（新发现，需决策）

Phase 0 架构依赖 GABS 作为 MCP server，但本机**未安装 Go 工具链**（`Get-Command go` 无结果），`_source-cache\gabs` 只有源码无法构建。

可选处置：

1. 安装 Go 后 `make build`（最贴近原架构）；
2. 绕过 GABS：Test Mod 直接以 Lib.GAB 起 GABP server，写一个极小的 MCP stdio 客户端（C# 或 Node）桥到 DSH —— 增加自研面；
3. 先做无 MCP 的最小通信验证（直接 TCP 调 GABP），把 MCP 层留到之后。

**本阶段未擅自选择**，等确认后再动 P1-002。

## 尚未验证 / 已知缺口

- `git_commit` 未注入。
- 未验证 `Debug.Print` 是否进入 `ModLogs`（实验 C/D 中 ModLogs 未产生新文件，身份证据来自独立文件）。P1-002 需要日志通道时再查。
- 未接入 GABS / MCP（P1-002 范围）。
