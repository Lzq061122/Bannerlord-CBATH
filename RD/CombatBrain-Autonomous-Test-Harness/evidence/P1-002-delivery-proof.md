# P1-002 交付证明 — DSH 官方 MCP 客户端接入

日期：2026-09-24
Verdict：**green**（9 条验收全部通过）

## 验收对照

| # | 验收项 | 结果 | 证据 |
|---|---|---|---|
| 1 | mcp.json 经 parseMcpJson 解析 errors 为空、transport=stdio | ✅ | `errors=[]`、`transport=stdio`、`serverName=gabs`、`command=…gabs.exe` |
| 2 | DSH 实际拉起 gabs.exe，父进程为 node.exe | ✅ | gabs pid=25936，parentPid=15924 (node.exe)，CommandLine 与配置逐字一致 |
| 3 | games_start 成功并连接 GABP | ✅ | `started successfully and connected via GABP` |
| 4 | games_tool_names 列出 cbath 工具 | ✅ | 3 个：get_build_identity / get_game_state / ping |
| 5 | cbath/ping 返回 ok/pong/版本 | ✅ | `{"status":"ok","pong":true,"game_version":"v1.4.8.119303",…}` |
| 6 | build_id 与 SHA-256 三方一致 | ✅ | 见下表 |
| 7 | 工具返回 pid == GABS workload pid | ✅ | 38716 == 38716（进程存在，Bannerlord 12:26:06） |
| 8 | games_stop 干净停止无残留 | ✅ | `workload pid 38716 is gone`；ps 无 Bannerlord/Native |
| 9 | 全部经 DSH 官方 MCP 客户端 | ✅ | 全部调用走 `mcp__gabs__*` |

## 三方身份一致性（AC6）

| 环节 | 值 |
|---|---|
| build-deploy 输出 build_id | `b20260924-011017-d5198273` |
| GABP get_build_identity 返回 build_id | `b20260924-011017-d5198273` |
| 部署路径 DLL SHA-256（本机计算） | `b0531204333b35c0f027f775641feacda4c2edf93e61ee03160eae4be954bb69` |
| 游戏内自读 assembly_sha256 | `b0531204333b35c0f027f775641feacda4c2edf93e61ee03160eae4be954bb69` |
| MVID | `f2a03821-4276-4703-a762-0be80ccb00e2` |
| PID | 38716（GABS workload == 工具自报 == 进程存在） |
| active_modules | `Native,CombatBrainAutonomousTestHarness` |

## 原始输出

`cbath/ping`：
```json
{"build_id":"b20260924-011017-d5198273","game_version":"v1.4.8.119303","pid":38716,"pong":true,"status":"ok","utc":"2026-09-24T04:26:36Z"}
```

`cbath/get_build_identity`：
```json
{"active_modules":"Native,CombatBrainAutonomousTestHarness",
 "assembly_location":"…\\Modules\\CombatBrainAutonomousTestHarness\\bin\\Win64_Shipping_Client\\CombatBrainAutonomousTestHarness.dll",
 "assembly_sha256":"b0531204333b35c0f027f775641feacda4c2edf93e61ee03160eae4be954bb69",
 "assembly_version":"1.0.0.0","build_id":"b20260924-011017-d5198273",
 "build_timestamp":"2026-09-23T17:10:17Z","game_version":"v1.4.8.119303",
 "marker":"CBATH_RUNTIME_IDENTITY","module":"CombatBrainAutonomousTestHarness",
 "mvid":"f2a03821-4276-4703-a762-0be80ccb00e2","pid":38716}
```

`cbath/get_game_state`（附带，说明状态判据可用）：
```json
{"activeGameState":"TaleWorlds.MountAndBlade.InitialState","mission":"<null>",
 "moduleUptimeSec":70,"topScreenType":"…GauntletInitialScreen",
 "transitions":"0s <null> | 3s GauntletInitialScreen"}
```

## 过程中的失败与处置

| 现象 | 根因 | 处置 |
|---|---|---|
| `games_tool_names` 返回 `stale-runtime-cleaned` | 我在 start 之后修改了 mcp.json，触发 DSH 重载，杀死 gabs 及其子进程 | 配置定稿后重跑，流程上禁止 start 后改配置 |
| `parseMcpJson` 报 `http servers require a "url"` | 字段名写成 `transport`，实际应读 `type` | 改用 `type: "stdio"`，并用 parseMcpJson 预校验 |
| `games_start` 报 `exited during start (exit code -1)` | Steam 未运行 | 拉起 Steam 后重试成功 |
| 之前出现 Safe Mode 阻断 | `safely_exited=0` | 启动前复位为 1；已固化进 build-deploy.ps1 |

## 交付物

- `.dsh\dshmm\mcp.json` — DSH MCP 配置（workspace 级，不污染全局）
- `experiments/DSH-MCP-setup.md` — 接入说明（含字段名陷阱、校验方法、生效方式）
- `experiments/P1-002-experiment-log.md` — 七次实验完整记录
- `experiments/intro-video-removal.md` — 开场动画处理记录
- `experiments/test-mod/CBATH/` — Test Mod 源码与 build-deploy.ps1
- `gabs-config/config.json` — GABS game entry
- `tools/` — 采样与 MCP driver 脚本
