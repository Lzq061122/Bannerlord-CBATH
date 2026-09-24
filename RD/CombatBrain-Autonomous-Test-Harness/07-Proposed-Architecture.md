# 建议架构与取舍

```text
DeepSeek Harness（或任意 MCP client）
    → GABS（现有 Go MCP server：进程、连接、工具代理）
    → Lib.GAB / GABP（现有 C# 协议库，loopback TCP）
    → 独立 Bannerlord 测试 Mod（少量游戏端工具）
    → Bannerlord v1.4.8.119303
```

**独立 Bannerlord 测试 Mod** 在此是本轮提出的 Phase 1 实施建议，尚未建立：它只解决固定 Mission、双方 Formation、状态与构建身份的游戏内读取/控制问题；需要它是因为 GABS 当前阵型工具只读玩家方且全量 1.4.8 编译失败。它不改变 CombatBrain 架构或既有需求，只把实验代码隔离在本 RD。

## 为什么选这条路线

1. [CODE] GABS 已有 MCP→游戏进程→GABP 链路，Lib.GAB 有工具注册、会话和 loopback TCP；重写协议/进程管理无直接收益。相关证据见 [03](03-GABS-Source-Audit.md)。
2. [RUN] 全量 Bannerlord.GABS 1.4.8 编译有 29 个错误，大部分在 MVP 无关工具；全量 fork 修完再开测扩大了验证面。最小 Mod 的关键双方阵型读取签名已在 [独立编译探针](experiments/formation-api-probe/FormationApiProbe.cs) 中通过。
3. [CODE] DSH 官方有可配置的 MCP 客户端；坚持标准 MCP 接口可使其只承担编排，不让测试系统依赖其预览期内部插件实现。

## 与替代方案比较

| 方案 | 优点 | 当前问题 | 决定 |
|---|---|---|---|
| 全量 fork Bannerlord.GABS | 保留已有大量工具 | 1.4.8 有 29 个编译错误；不需要的 campaign/UI/hero API 占主要修复量 | Phase 1 暂缓；后续是否 upstream 视最小实验而定 |
| 直接依赖已发布 Bannerlord.GABS 二进制 | 不用维护源码 | 现有目标 v1.3.x，未证明可在 v1.4.8 加载；也缺双方阵型和固定 Mission 工具 | 不采用 |
| **GABS + Lib.GAB + 独立最小 Mod** | 复用控制/协议，同时把版本敏感代码缩到必要范围 | 需要自己编写游戏端最小工具并实测 | **Phase 1 主路线** |
| 自写 MCP、协议与 launcher | 最自由 | 重复 GABS 现有工作，更多故障面 | 不采用 |
| 全程像素点击 | 容易演示 UI 流程 | 阵型状态和加载身份无法可靠由像素给出 | 不作为主路线 |

## 最小接口草案

机器可读响应须含 run ID、UTC 时间、游戏 build、Mod build ID、PID 或进程关联 ID、明确状态与错误代码。名称不可替代稳定 ID。具体 schema 在实现前由 P1-001 固定。

- 复用 GABS：`games.start/status/connect/stop/call_tool`。
- 游戏端最小工具：`test/get_status`（含 Mod build identity）；`test/start_fixed_mission`；`test/get_all_formations`；`test/end_mission`。可先把 `core/ping`/状态工具等价实现纳入最小 Mod。
- `test/get_all_formations` 返回所有非空 Team 的 side/TeamIndex，并对每支 Formation 返回 index/class/unit_count、位置、朝向、movement/arrangement/firing order、AI controlled；值缺失时用 `null` 和原因，不能编造成 0。
- CombatBrain 后续接口如计划、行为、命令来源暂为设计草案，Phase 1 不接入。

`Order Provenance`（用户已定义的问题：判断谁写入命令）不能从当前 `OrderController.GetActive*OrderOf` 的**状态快照**反推出作者。若未来需要准确来源，须在写命令时记录显式来源或经版本验证的 Harmony patch，并保留 `Unknown`；调用栈推测只可作诊断线索，不作确定真值。
