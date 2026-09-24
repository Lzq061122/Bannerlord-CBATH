# 13 — Phase 1 Runtime Evidence
## CBATH Phase 1 运行时证据汇编

日期：2026-09-24
工作区：`E:\MBmod\CombatBrain Autonomous test harness`
证据根目录：`RD\CombatBrain-Autonomous-Test-Harness\evidence\`

---

## 一、证据目录结构

```text
evidence\
├─ runs\
│  ├─ run-20260924-183714-r1.json              轮 1  PASS
│  ├─ run-20260924-184412-r2.json              轮 2  PASS
│  ├─ run-20260924-185053-r3.json              轮 3  PASS
│  ├─ run-20260924-184458-r3-attempt1-FAILED.json   轮 3 失败尝试 1（如实存档）
│  ├─ run-20260924-184804-r3-attempt2-FAILED.json   轮 3 失败尝试 2（如实存档）
│  ├─ probe-20260924-175642.json               端口作用域 bug（历史）
│  └─ probe-20260924-175815.json               claim 冲突期失败（历史）
├─ P1-002-delivery-proof.md
├─ p1-003-formations-both-sides.json
├─ p1-003-formations-single-side.json
├─ p1-004-formations-autonomous.json
└─ p1-004-custombattle-api.txt
```

---

## 二、运行时身份证据（三轮共同）

### 2.1 游戏内自读（`cbath/get_build_identity`）

轮 1 原始返回（轮 2、轮 3 除 `pid` 外逐字段相同）：

```json
{
  "active_modules": "Native,SandBoxCore,Sandbox,StoryMode,CustomBattle,CombatBrainAutonomousTestHarness",
  "assembly_location": "E:\\SteamLibrary\\steamapps\\common\\Mount & Blade II Bannerlord\\Modules\\CombatBrainAutonomousTestHarness\\bin\\Win64_Shipping_Client\\CombatBrainAutonomousTestHarness.dll",
  "assembly_sha256": "c6fbe74c827f0aa1a117296bd96ac0bcded07e59df5ab7dabc0575bc6e4a2ed2",
  "assembly_version": "1.0.0.0",
  "build_id": "b20260924-171754-2eeefc21",
  "build_timestamp": "2026-09-24T09:17:54Z",
  "game_version": "v1.4.8.119303",
  "marker": "CBATH_RUNTIME_IDENTITY",
  "module": "CombatBrainAutonomousTestHarness",
  "mvid": "f826cf4a-dfc8-43ff-89f8-b7d335cbd6bd",
  "pid": 46508
}
```

轮 2 `pid` = 35608，轮 3 `pid` = 37308，其余字段完全一致。

### 2.2 磁盘独立计算（PowerShell `Get-FileHash`）

```text
path       = E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord\Modules\
             CombatBrainAutonomousTestHarness\bin\Win64_Shipping_Client\
             CombatBrainAutonomousTestHarness.dll
disk_sha256= c6fbe74c827f0aa1a117296bd96ac0bcded07e59df5ab7dabc0575bc6e4a2ed2
disk_mtime = 2026-09-24T09:17:58.7663503Z
disk_size  = 33792
```

**运行时自读 SHA256 == 磁盘独立计算 SHA256（逐字符相同）。**

> 该比对在轮 1、轮 2 之后、轮 3 之前各做过一次，三轮结果均为 `c6fbe74c…a2ed2`。
> 意义：排除"游戏实际加载的是旧 DLL"这一最易发生的误判。

---

## 三、P1-005 轮 1（run-20260924-183714-r1）

PID 46508 ｜ 判定 **PASS**

### 3.1 启动与连接

```text
mcp__gabs__games_start  → "Game 'bannerlord148' started successfully and connected via GABP."
mcp__gabs__games_connect→ "Already connected to 'bannerlord148'. Re-synced 12 tools."
进程                     → Bannerlord pid=46508, StartTime=2026/9/24 18:37:14
```

### 3.2 进入 Mission

```json
// cbath/h3_provider_start
{"active_state":"TaleWorlds.MountAndBlade.GameLoadingState","game_after":"<null>","game_before":"<null>",
 "mission":"<null>","provider":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattle.CustomBattleProvider",
 "provider_name":"陆地自定义战斗","status":"ok",
 "top_screen":"TaleWorlds.MountAndBlade.View.Screens.GameLoadingScreen"}
```

```json
// cbath/get_game_state
{"activeGameState":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattleState","mission":"<null>",
 "moduleUptimeSec":12,"topScreenType":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattleScreen",
 "transitions":"0s <null> | 3s GauntletInitialScreen | 11s GameLoadingScreen | 12s CustomBattleScreen"}
```

```json
// cbath/h3_start_from_screen
{"invoked":"ExecuteStart","mission":"<null>","status":"ok",
 "top_screen":"TaleWorlds.MountAndBlade.CustomBattle.CustomBattleScreen",
 "top_screen_after":"TaleWorlds.MountAndBlade.View.Screens.MissionScreen","vm_field":"_dataSource"}
```

```json
// cbath/get_mission_state
{"mission_name":"battle_terrain_biome_096","mission_running":true,"mission_time":"0.031"}
```

### 3.3 Formation 快照（mission_time=2.156）

```json
{"mission_name":"battle_terrain_biome_096","mission_time":"2.156","status":"ok","teams":[
 {"formation_count":4,"is_player_team":true,"side":"Defender","team_id":0,"formations":[
   {"formation_index":0,"formation_class":"Infantry","unit_count":24,"arrangement_order":"ArrangementLine","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":false,"position":{"x":"1341.276","y":"862.364"},"facing":{"x":"-0.751","y":"0.660"}},
   {"formation_index":1,"formation_class":"Ranged","unit_count":25,"arrangement_order":"ArrangementLine","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":false,"position":{"x":"1345.274","y":"858.854"},"facing":{"x":"-0.751","y":"0.660"}},
   {"formation_index":2,"formation_class":"Cavalry","unit_count":26,"arrangement_order":"ArrangementLine","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":false,"position":{"x":"1327.382","y":"838.592"},"facing":{"x":"-0.751","y":"0.660"}},
   {"formation_index":3,"formation_class":"HorseArcher","unit_count":25,"arrangement_order":"ArrangementLine","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":false,"position":{"x":"1362.321","y":"878.267"},"facing":{"x":"-0.751","y":"0.660"}}]},
 {"formation_count":5,"is_player_team":false,"side":"Attacker","team_id":1,"formations":[
   {"formation_index":0,"formation_class":"Infantry","unit_count":20,"arrangement_order":"ArrangementLine","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":true,"position":{"x":"1109.578","y":"1065.801"},"facing":{"x":"0.737","y":"-0.675"}},
   {"formation_index":1,"formation_class":"Ranged","unit_count":25,"arrangement_order":"ArrangementScatter","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":true,"position":{"x":"1106.750","y":"1070.141"},"facing":{"x":"0.737","y":"-0.675"}},
   {"formation_index":2,"formation_class":"Cavalry","unit_count":13,"arrangement_order":"ArrangementCloseOrder","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":true,"position":{"x":"1124.711","y":"1089.346"},"facing":{"x":"0.737","y":"-0.675"}},
   {"formation_index":3,"formation_class":"HorseArcher","unit_count":25,"arrangement_order":"ArrangementLine","firing_order":"FireAtWill","movement_order":"Move","is_ai_controlled":true,"position":{"x":"1087.891","y":"1052.318"},"facing":{"x":"0.737","y":"-0.675"}},
   {"formation_index":4,"formation_class":"Cavalry","unit_count":12,"arrangement_order":"ArrangementCloseOrder","firing_order":"FireAtWill","movement_order":"StandYourGround","is_ai_controlled":true,"position":{"x":"1121.510","y":"1092.079"},"facing":{"x":"0.737","y":"-0.675"}}]}]}
```

### 3.4 退出

```text
cbath/end_mission      → {"status":"ok"}
cbath/get_mission_state→ {"mission_name":"","mission_running":false,"mission_time":""}
mcp__gabs__games_stop  → "Game 'bannerlord148' was stopped and its termination verified. workload pid 46508 is gone."
cleanup 复查            → Bannerlord 进程数 = 0
```

---

## 四、P1-005 轮 2（run-20260924-184412-r2）

PID 35608 ｜ 判定 **PASS**

状态转换链与轮 1 完全相同，时间略有差异：

```text
cbath/get_game_state transitions:
"0s <null> | 3s GauntletInitialScreen | 10s GameLoadingScreen | 11s CustomBattleScreen"
```

```json
// cbath/get_mission_state
{"mission_name":"battle_terrain_biome_096","mission_running":true,"mission_time":"0.265"}
```

Formation（mission_time=2.248）：双方编成与轮 1 相同（Defender 4 阵 24/25/26/25；Attacker 5 阵 20/25/13/25/12），
坐标与朝向因战场生成不同：

```text
Defender position: (1209.316, 816.296) / (1214.635, 816.270) / (1214.449, 789.232) / (1214.759, 842.105)
Defender facing  : (-1.000, 0.005)
Attacker position: (871.774, 815.394) / (867.038, 816.869) / (867.473, 843.117) / (865.074, 790.947) / (863.297, 842.997)
Attacker facing  : (1.000, -0.005)
Attacker movement: Infantry=Move, Ranged=StandYourGround, Cavalry=StandYourGround, HorseArcher=Move, Cavalry=StandYourGround
```

```text
cbath/end_mission      → {"status":"ok"}
cbath/get_mission_state→ {"mission_name":"","mission_running":false,"mission_time":""}
mcp__gabs__games_stop  → "termination verified. workload pid 35608 is gone."
cleanup 复查            → Bannerlord 进程数 = 0
```

---

## 五、P1-005 轮 3（run-20260924-185053-r3）

PID 37308 ｜ 判定 **PASS**（此前 2 次失败尝试见第七节）

```text
cbath/get_game_state transitions:
"0s <null> | 3s GauntletInitialScreen | 9s GameLoadingScreen | 10s CustomBattleScreen"
```

```json
// cbath/get_mission_state
{"mission_name":"battle_terrain_biome_096","mission_running":true,"mission_time":"0.696"}
```

Formation（mission_time=2.566）：双方编成再次一致

```text
Defender position: (1192.347, 814.241) / (1197.665, 814.130) / (1196.994, 787.084) / (1198.206, 839.959)
Defender facing  : (-1.000, 0.021)
Attacker position: (854.914, 818.803) / (850.237, 820.268) / (851.071, 846.577) / (847.822, 794.444) / (846.876, 846.538)
Attacker facing  : (1.000, -0.021)
```

```text
cbath/end_mission      → {"status":"ok"}
cbath/get_mission_state→ {"mission_name":"","mission_running":false,"mission_time":""}
mcp__gabs__games_stop  → "termination verified. workload pid 37308 is gone."
cleanup 复查            → Bannerlord 进程数 = 0
```

---

## 六、三轮横向一致性

| 观测项 | 轮 1 | 轮 2 | 轮 3 | 一致 |
|---|---|---|---|---|
| PID | 46508 | 35608 | 37308 | ❌ 各不相同（**要求如此**） |
| build_id | `b20260924-171754-2eeefc21` | 同 | 同 | ✅ |
| SHA256 运行时 | `c6fbe74c…a2ed2` | 同 | 同 | ✅ |
| SHA256 磁盘 | `c6fbe74c…a2ed2` | 同 | 同 | ✅ |
| game_version | `v1.4.8.119303` | 同 | 同 | ✅ |
| mission_name | `battle_terrain_biome_096` | 同 | 同 | ✅ |
| 到达 CustomBattleScreen | 12s | 11s | 10s | 近似 |
| teams 数 | 2 | 2 | 2 | ✅ |
| Defender 阵型数/总兵力 | 4 / 100 | 4 / 100 | 4 / 100 | ✅ |
| Attacker 阵型数/总兵力 | 5 / 95 | 5 / 95 | 5 / 95 | ✅ |
| Defender 坐标 | (1341,862)… | (1209,816)… | (1192,814)… | ❌ 战场生成不同（允许） |
| end_mission → running | false | false | false | ✅ |
| games_stop | verified | verified | verified | ✅ |
| cleanup 残留 | 0 | 0 | 0 | ✅ |

**说明**：坐标/朝向的不同证明每轮是**真实的新战斗**，而非读取了缓存或上一轮残留数据——这反而增强了证据可信度。

---

## 七、失败尝试的原始证据（未隐藏）

### 7.1 轮 3 尝试 1 — `run-20260924-184458-r3-attempt1-FAILED`

```text
games_start 返回:
"Game 'bannerlord148' started, but GABP was not ready after 20s:
 connect cancelled during backoff: context deadline exceeded.
 GABS will keep trying in the background for up to 2m40s."

games_status 返回:
"running, but the GABP bridge disconnected"

进程实测:
  pid 29444  ALIVE  Responding=True  CPU=9.28s  RSS=61.4MB  threads=36
  Test-NetConnection localhost:19537 → TcpTestSucceeded = False
  监听端口扫描 19500-19600        → 无任何监听

日志实测:
  Documents\...\Logs 最新文件 = 2026-08-31（无新日志）
  Modules\...\*.log 最新 = 2026-09-23（无新日志）
  gabs-config\bannerlord148\launch.log = 0 字节（空）
  Windows 应用程序日志（近 15 分钟）→ 无 Error/Warning 事件
```

**根因定位**：`Get-Process -Name 'steam'` 返回计数 1，一度看似正常；改用精确名称核查后确认命中的是
`steamwebhelper.exe`（16:14 遗留的孤儿进程，两条），而 **`steam.exe` 实际计数为 0**。

处置：运行 `D:\Program Files (x86)\Steam\steam.exe`（新 pid 28856），等待 50s + 30s 确认
`steam.exe`=1 且 `steamwebhelper`=8，复位 `safely_exited=1`，杀掉停滞的 pid 29444。

### 7.2 轮 3 尝试 2 — `run-20260924-184804-r3-attempt2-FAILED`

```text
games_start 返回:
"Game 'bannerlord148' started, but GABP was not ready after 20.001s: ..."

45 秒后进程检查:
  Bannerlord 进程 → 不存在（启动过程中自行退出）
  监听端口 19500-19600 → 无

games_status 返回:
"stopped (stale runtime state was removed)"

bridge.json 实测:
  {"port":19537,"gameId":"bannerlord148","startedAt":"2026-09-24T10:48:04Z", ...}
launch.log → 0 字节
```

**根因**：与尝试 1 相同（steam.exe 尚未拉起，Steam 重启发生在此次之后）。

### 7.3 这两次失败的性质判定

| 判断 | 依据 |
|---|---|
| **不是 CBATH 缺陷** | CBATH DLL 未参与早期启动；进程停滞在模块加载之前，无任何 CBATH 日志 |
| **不是 GABS 缺陷** | GABS 正确报告了 "GABP not ready" 与 "stale runtime state was removed" |
| **是环境前置条件缺失** | 交接文档 §5.4 明确要求 "Steam 必须在运行且 API 已就绪" |
| **未污染最终证据** | 两次均已存档，且不计入 3 轮连续 PASS 计数 |

---

## 八、历史失败证据（前一位 Agent 遗留，保留备查）

### 8.1 端口作用域 bug — `probe-20260924-175642.json`

```json
{"run_id":"probe-20260924-175642","errors":["gabs http failed: gabs HTTP endpoint never became ready on port 0"],
 "verdict":"FAIL"}
```

现象：gabs 以 `server --http localhost:0` 启动，端口参数未传入（`$Port` 变量作用域冲突）。
修复：`mcp-http.ps1` 参数改名 `$ListenPort` / `$script:McpListenPort`。

### 8.2 claim 冲突期失败 — `probe-20260924-175815.json`

```json
{"run_id":"probe-20260924-175815","errors":["start failed: no pid"],
 "game_connection_result":null,"verdict":"FAIL"}
```

现象：端口修复后 4 秒内即失败（超时上限为 200 秒），属立即被拒，非超时。
根因：第二个 gabs 实例与 DSH 持有的 gabs 会话争抢 `bannerlord148` 的 runtime claim。

**结论**：这两条历史失败共同证明了"HTTP 编排路线不可行"，也是 P1-005 改用单实例直驱的依据。

---

## 九、环境前置状态快照（每轮启动前）

| 检查项 | 轮 1 | 轮 2 | 轮 3（成功那次） |
|---|---|---|---|
| `safely_exited` | 1 | 1 | 1（已复位） |
| Bannerlord 残留进程 | 0 | 0 | 0 |
| steam.exe | 1 | 1 | 1（重启后） |
| gabs 实例数 | 1（pid 25640） | 1 | 1 |

> **gabs 全程只有 1 个实例**（pid 25640，DSH MCP 客户端会话），三轮生命周期期间未重启、未替换。

---

## 十、证据可信度自评

| 维度 | 评估 |
|---|---|
| 身份可验证性 | **强** — 磁盘哈希与运行时哈希双向比对，排除旧 DLL |
| 进程独立性 | **强** — 三个不同 PID，且坐标每轮不同 |
| 状态真实性 | **强** — 基于 `mission_running` 真实状态判据，非 sleep 推测 |
| 数据非伪造性 | **强** — 双方 `is_ai_controlled` 相反、阵型命令不同，具备区分度 |
| 失败诚实性 | **强** — 2 次失败尝试与 2 条历史失败均如实存档 |
| 可重复性 | **中** — 3 轮成功，但依赖 Steam 存活这一外部前置条件 |
| 覆盖完整性 | **中** — 仅验证生命周期主干，未覆盖异常路径与长时间稳定性 |
