# CombatBrain Autonomous Test Harness — Phase 0 研究结论

日期：2026-09-23。范围：研究与最小实验定义；未部署 Mod，未启动游戏，未宣称 Phase 1 完成。

## 结论

**可行性：有现实技术路径，但完整闭环尚未实测。** [CODE] GABS 已有游戏进程管理、MCP↔GABP 桥接及游戏内状态工具；[RUN] 针对 1.4.8.119303 的独立编译探针确认能遍历 `Mission.Current.Teams` 并读取每支非空 Formation 的基础状态与三类当前命令；[RUN] 原版 Bannerlord.GABS 改用该版本引用程序集后有 **29 个编译错误**，因此不能直接部署。固定 Mission 的无人值守创建和连续三轮运行仍是 [UNKNOWN]。

**建议的唯一 Phase 1 主路线**：复用 GABS（Go MCP 进程控制）与 Lib.GAB（游戏端 TCP/GABP），从 Bannerlord.GABS 的少量核心工具着手做独立测试 Mod。先修最小编译面，再做固定 Mission 和双方阵型观测；暂不移植其战役、UI、英雄等工具，也不接 CombatBrain 内部状态。此为架构建议，尚未经过运行验证。

下一步最值得做：按 [08-Phase1-MVP.md](08-Phase1-MVP.md) 的 P1-001，编译并加载只含 ping、状态及双方 Formation 读取的 1.4.8 测试 Mod；使用构建标识证明游戏确实加载了新 DLL。随后验证固定 Mission 和三次连续生命周期。

## 本轮证据

| 事实 | 等级 | 证据 |
|---|---|---|
| 游戏本机 Native 模块标 `v1.4.8`，Steam build ID `24573425` | [RUN] 文件读取 | [本机环境记录](evidence/local-game-facts.txt) |
| 精确版本引用程序集存在，含 Core/Native/SandBox/CustomBattle | [DOC] NuGet；[RUN] 依赖还原 | [NuGet 总包](https://www.nuget.org/packages/Bannerlord.ReferenceAssemblies/1.4.8.119303)、[编译记录](evidence/gabs-v148-build.txt) |
| GABS 默认目标是 v1.3.15 / v1.3.13，最低 v1.2.12 | [CODE] | [版本文件](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/supported-game-versions.txt) |
| GABS 阵型工具只遍历 `PlayerTeam` | [CODE] | [BattleTools.cs](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/Tools/BattleTools.cs#L121-L175) |
| 1.4.8 的所有 Team / Formation 基础 API 能通过编译 | [RUN] 静态编译，非运行 | [探针源码](experiments/formation-api-probe/FormationApiProbe.cs)、[输出](evidence/formation-api-probe-build.txt) |
| GABS 全量源码针对 1.4.8 有 29 个编译错误 | [RUN] 静态编译，非运行 | [编译输出](evidence/gabs-v148-build.txt) |
| DeepSeek Harness 官方 MCP 客户端支持 stdio/HTTP、工具超时和重连 | [CODE]；未联调 GABS | [客户端实现](https://github.com/deepseek-ai/deepseek-harness/blob/46a7f68b0922371ce7144b668b90e377d8e799f4/packages/mcp/mcp-client/src/index.ts)、[连接逻辑](https://github.com/deepseek-ai/deepseek-harness/blob/46a7f68b0922371ce7144b668b90e377d8e799f4/packages/mcp/mcp-client/src/connection.ts) |

## Research Coverage Matrix

| Area | Status | Evidence | Blocking? |
|---|---|---|---|
| GABS architecture | 源码已查 | [03](03-GABS-Source-Audit.md) | 否 |
| GABS game API | 源码已查，缺口明确 | [03](03-GABS-Source-Audit.md) | 是：双方 Formation、固定 Mission |
| Bannerlord 1.4.8 compatibility | 实际编译失败，错误已留存 | [04](04-Bannerlord-1.4.8-Compatibility.md) | 是 |
| DSH MCP | 源码已查，未联调 | [05](05-DeepSeek-Harness-MCP-Audit.md) | 联调前是 |
| Game launch | GABS 源码/脚本已查，未实际运行 | [03](03-GABS-Source-Audit.md) | 是 |
| Mission creation | 候选已比较，未实际运行 | [06](06-Mission-Automation-Options.md) | 是 |
| Formation observation | 双方基础 API 编译通过，未实际运行 | [04](04-Bannerlord-1.4.8-Compatibility.md) | 是 |
| Process lifecycle | GABS 源码已查，未实际运行 | [03](03-GABS-Source-Audit.md) | 是 |
| Determinism | 关键变量未量化 | [10](10-Open-Questions.md) | MVP 不要求逐帧确定性 |
| Build identity | 方案已定义，未运行验证 | [08](08-Phase1-MVP.md) | 是 |

## 交付导航

[问题与边界](01-Problem-and-Goals.md) · [已有方案](02-Existing-Solutions.md) · [GABS 源码](03-GABS-Source-Audit.md) · [版本兼容](04-Bannerlord-1.4.8-Compatibility.md) · [DSH MCP](05-DeepSeek-Harness-MCP-Audit.md) · [Mission 路线](06-Mission-Automation-Options.md) · [架构选择](07-Proposed-Architecture.md) · [Phase 1 实验](08-Phase1-MVP.md) · [风险](09-Risk-Register.md) · [未知项](10-Open-Questions.md) · [DeepSeek 交接](11-Implementation-Handoff.md)。
