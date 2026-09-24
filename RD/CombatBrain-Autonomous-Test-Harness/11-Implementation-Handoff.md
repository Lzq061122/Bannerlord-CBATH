<!-- PROMPT META
Name: CombatBrain Autonomous Test Harness Phase 1 Implementation Handoff
Version: 1.0
Author Role: Research Lead / System Architect
Model: GPT-6
Created: 2026-09-23
Updated: 2026-09-23
Target: DeepSeek V4.1 + DeepSeek Harness
Scope: CombatBrain Autonomous Test Harness / Phase 1
-->

<!-- CHANGE LOG (newest first, keep last 3)
v1.0 2026-09-23 23:23 | role=Research Lead / System Architect | model=GPT-6 | editor=combatbrain-ath-phase0-root | note=建立基于源码审计、1.4.8 编译证据和六项实验的 Phase 1 实施交接
-->

# 给 DeepSeek V4.1 + DeepSeek Harness 的 Phase 1 交接

## 开始前先核对

1. 阅读 [总览](00-Executive-Summary.md)、[GABS 源码审计](03-GABS-Source-Audit.md)、[兼容性实测](04-Bannerlord-1.4.8-Compatibility.md) 与 [Phase 1 任务](08-Phase1-MVP.md)。所有 upstream 结论固定到 [source-revisions.txt](evidence/source-revisions.txt)；更新依赖时重新审计。
2. 本机游戏在 `E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord`；Native 为 v1.4.8，Steam build ID `24573425`。先复核当前值，版本不同不得复用本轮编译结论。
3. `[RUN]` 目前仅静态编译：原 GABS 改版本后 29 错，独立 all-team Formation API 探针 0 错。**没有任何一轮真实游戏闭环通过。**

## 执行顺序

按 [P1-001→P1-006](08-Phase1-MVP.md) 做，不并行写同一文件。先编译最小游戏端工具并证明运行时 build identity，再联调 DSH/GABS、Game Lifecycle、Mission Lifecycle、双方 Formation，最后连续 3 次完整运行。所有实验代码与 CombatBrain 主工程隔离。失败时先查构建产物/部署 hash/运行标识，再查目标路径是否执行，最后分析业务条件。

若 Console 命令不足以创建固定 Mission，就在独立 Mod 里增加最小创建工具；不要为了编译全量 GABS 去修 29 个无关接口。GABS Go 和 Lib.GAB 优先作为现成依赖；如其 API/版本确实阻碍最小闭环，记录可复现失败后再讨论小范围 fork。BannerlordCoop 源码只能参考思路，不能复制到本项目。

## 回报格式

每个 P1-00N 交付：变更文件、build/test 命令与退出码、独立日志路径、实际 game build、DLL hash/build ID/MVID、观察到的状态、通过/失败及失败含义、尚未验证项。任何“READY/GO”必须有真实游戏运行证据。不要把编译通过、README 声称、游戏进程存在、或一次成功当成完整闭环。

完整三轮成功后立即停止扩功能，提交原始日志、结构化快照、三轮汇总、风险与未知项，等待架构审核。用户仍需处理少量主观体验验收；不再让用户执行普通启动/进战斗/截图取数的日常步骤。
