# GABS 源码审计

固定源码版本见 [source-revisions.txt](evidence/source-revisions.txt)。以下 `[CODE]` 只表示该版本源码确有实现，**不表示**已在 Bannerlord 1.4.8 中运行。

## 组件与通信

`AI Agent ↔ MCP ↔ GABS (Go) ↔ TCP/GABP ↔ Bannerlord.GABS (C# Mod) ↔ Bannerlord API`。

- [GABS MCP 注册](https://github.com/pardeike/gabs/blob/b5f441a04fa908852fdece18a08a8876ac970a4d/internal/mcp/stdio_server.go#L1170) 包含 `games.start`、`games.status`、`games.stop`、`games.connect`、`games.tool_names`、`games.tool_detail`、`games.call_tool`。MCP 有 stdio 实现，也有 [HTTP 端点](https://github.com/pardeike/gabs/blob/b5f441a04fa908852fdece18a08a8876ac970a4d/internal/mcp/http_server.go)；Phase 1 用本机 stdio 即可。
- [GABS GABP client](https://github.com/pardeike/gabs/blob/b5f441a04fa908852fdece18a08a8876ac970a4d/internal/gabp/client.go#L22-L48) 以 TCP 连接游戏端，LSP 式 Content-Length 帧封装 JSON 请求；连接有退避重试和握手。`games.call_tool` 源码默认请求超时 **30 秒**，可传 `timeout`。
- [Lib.GAB TcpTransport](https://github.com/BUTR/Lib.GAB/blob/4e7f90dd71e45274bf904d36d0415f26e6e6a008/Lib.GAB/Transport/TcpTransport.cs#L91-L129) 只监听 loopback TCP；[GabpServer](https://github.com/BUTR/Lib.GAB/blob/4e7f90dd71e45274bf904d36d0415f26e6e6a008/Lib.GAB/Server/GabpServer.cs#L26-L94) 持有 token、session 和工具注册表。游戏端是 GABP server，Go GABS 是 GABP client。
- [SubModule](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/SubModule.cs#L119-L213) 在初始屏幕前启动 server，注册工具；`OnApplicationTick` 处理游戏主线程任务队列。业务 API 运行时需要主线程调度。

MCP tool 列表可供通用 client 使用；Codex、Claude Code、DeepSeek Harness 作为客户端的**协议可接入性**与各自的**端到端实际成功**是两件事。本轮没有建立任一客户端与真实游戏的连接。

## 与 MVP 直接有关的游戏工具

| 需要的能力 | 此源码实际情况 | 证据等级 |
|---|---|---|
| 连接探针 | `core/ping` 返回 pong 与 UTC 时间 | [CODE] [CoreTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/CoreTools.cs#L30-L40) |
| 游戏状态 | `core/get_game_state` 返回 campaign_map、mission、game_menu、GameState 类名或 unknown；不直接给出本项目完整的十状态机 | [CODE] [CoreTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/CoreTools.cs#L71-L124) |
| 等待状态 | `core/wait_for_state` 轮询最多 120 秒；调用方超时仍须覆盖它 | [CODE] [CoreTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/CoreTools.cs#L188) |
| 战斗状态 | `battle/get_state` 读 Mission 状态、时间、地图、玩家/敌方人数与结果，重点基于 `PlayerTeam` / `PlayerEnemyTeam` | [CODE] [BattleTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/BattleTools.cs#L18-L118) |
| 双方阵型 | `battle/get_formations` **仅**遍历 `mission.PlayerTeam.FormationsIncludingEmpty`，没有位置/朝向 | [CODE] [BattleTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/BattleTools.cs#L121-L175) |
| 结束 Mission | `mission/leave` 对 `Mission.Current` 调用 `EndMission()` | [CODE] [MissionTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/MissionTools.cs#L17-L36) |
| Console | `core/run_command` 与 `core/list_commands` 存在；某个命令能创建固定战斗仍未验证 | [CODE] [CoreTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/CoreTools.cs#L395) |
| 固定 Mission 创建 | 已注册的 Battle/Mission/Core 工具中未发现专门的 `start_test_mission`；是否能通过现有菜单/Console 间接完成仍未知 | [CODE] 工具注册与上述源码；[UNKNOWN] 运行效果 |

## 启动与健康检查

[launch-bannerlord.ps1](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/launch-bannerlord.ps1) 通过 BLSE Standalone 和 `_MODULES_` 参数启动，并在启动前复位 `safely_exited`，避免安全模式对话框阻断自动化。这个脚本写死了游戏目录，必须按本机路径配置；BLSE 是脚本默认选项，不是已验证的 1.4.8 必需条件。直接 `Bannerlord.exe`、Steam URI、Launcher 的稳定性本轮未实测。

`games.start` 启动进程后只等待一个有界初始 GABP 时段，余下连接在后台继续；因此“进程已启动”不能算 Ready。Phase 1 的 Ready 判据应同时包含：启动返回 PID/进程存活、GABP 连接成功、`core/ping` 成功、`core/get_game_state` 返回可识别状态，并记录加载模块和 build identity。`games.stop` 正常退出失败时才使用强制清理；任何终止方式都要确认目标 PID 已消失。

## 复用结论

Go GABS 的进程/MCP 控制和 Lib.GAB 的协议/工具注册值得复用。游戏端建议从 GABS 的主线程调度与少量状态工具提取思路，以独立测试 Mod 实现最小能力；原仓库全量 1.4.8 移植有 [已实测编译缺口](04-Bannerlord-1.4.8-Compatibility.md)。是否 fork 并 upstream：先做独立分支/实验，形成可运行的 1.4.8 最小补丁后再决定提交 upstream；现在没有足够证据承诺 upstream 合并。
