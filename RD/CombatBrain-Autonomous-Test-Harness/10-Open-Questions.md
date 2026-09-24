# 尚未解决的问题

这些问题没有被当前源码阅读或静态编译解决；先执行不依赖它们的工作，后续按优先级验证。

| ID | Question / 为什么重要 | Evidence checked / 当前判断 | How to test later |
|---|---|---|---|
| OPEN-001 | 1.4.8 的最小 Lib.GAB Mod 能否真实加载、接收 GABS 调用？阻断所有运行实验。 | [RUN] GABS 全量编译失败；Formation API 探针编译通过。运行未知。 | P1-001/002：最小 Mod、加载日志、ping、build identity。 |
| OPEN-002 | 现有 console/debug 命令能否直接创建固定、双方可控的 Mission？决定是否须写创建工具。 | [CODE] GABS 可列出并执行命令；命令清单与效果未在本机查。 | P1-004 在游戏内列命令并试真实启动，检查 scene、双方、输入可重复。 |
| OPEN-003 | 1.4.8 直接 `MissionState.OpenNew` 所需原生 behaviors/spawn 链有哪些？决定专用 Mod 的开发面。 | [CODE] Coop 源码展示复杂行为链，但许可证不许复制；本机 1.4.8 API 未做运行探针。 | 先用原版 CustomBattle/Console 路线；若不足，基于官方游戏本机程序集做最小 PoC，逐项验证。 |
| OPEN-004 | `Mission.Current.Teams` 在真实战斗是否完整覆盖双方/第三方 Team？快照值是否可稳定关联？ | [RUN] 编译探针通过；无游戏内样本。 | P1-005 采两帧以上，记录 Team side/ID/index 与场景可见双方对照。 |
| OPEN-005 | 最稳定的无人值守启动路线是 BLSE Standalone、原生 exe 还是 Steam/Launcher？ | [CODE] GABS 提供 BLSE 脚本及模块参数；三条路线未运行比较。 | P1-003 先试配置最少的命令行启动，记录 PID/Ready/弹窗/退出；失败再比其他路线。 |
| OPEN-006 | DSH 官方 MCP client 与当前 GABS 的实际互操作、长任务与重连表现怎样？ | [CODE] 双方有标准 MCP 实现、超时/重连逻辑；未联调。 | P1-002 做一次完整调用和一次受控断线，保留两层日志。 |
| OPEN-007 | 游戏是否可固定 spawn、AI RNG、物理与帧时序到足以逐帧复现？影响后续战术断言。 | [UNKNOWN] 本轮未找到可支撑逐帧确定性的源码/运行证据。 | 固定地图、配置、输入与可设置 seed 后多轮采样；先量测同场差异，再选确定性或统计断言。 |
| OPEN-008 | 最后是谁写入 MovementOrder，能否可靠区分 Native Tactic/Behavior、CombatBrain、Player、其他 Mod？ | [CODE] GABS 只读取当前命令，不记录作者；状态值本身无法证明来源。 | 在 1.4.8 确认命令写入口；分别用显式来源标记与 Harmony patch 作最小实验，无法归因返回 Unknown。 |
| OPEN-009 | BannerlordTestingEssentials 为什么未普及、其历史 fork 与原仓库最后版本是否一致？ | [CODE] 已从 [历史 fork](https://github.com/Allen-Glass/BannerlordTestingEssentials) 确认 SimpleTCP/8998、命令注册、状态事件；原 URL 2026-09-23 返回 404。缺维护者说明。 | 如需历史结论，再找维护者 issue/存档或原仓库最后提交；不阻塞 Phase 1。 |
| OPEN-010 | 游戏运行时如何可靠列出已加载模块与当前 DLL 身份？ | [INFERENCE] 嵌入 ID+MVID+文件 hash 方案已定义，尚未游戏中验证。 | P1-001 由游戏端返回并与部署产物比对；检查模块加载日志，失败则不可继续。 |

## 暂缓的设计问题

CombatBrain 内部状态宜以最小 Pull 快照和必要 Push 事件组合暴露；Plan/Order history 需要事件写入时记录，纯事后 Pull 无法复原。此为后续设计判断，**Phase 1 不实现**。视觉录像、统计评价阈值、100 场批跑与大规模 CombatBrain 集成均应等基础三轮闭环通过后再研究。
