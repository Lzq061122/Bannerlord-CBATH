# 问题与目标

当前人工链路是“改代码→编译→启动游戏→人工进入战斗→观察→反馈”。目标链路让 Agent 自主完成构建、部署、启动、进入固定战斗、结构化观测、退出和重试，用户只承担少量主观体验验收。

Phase 1 的判据严格取自两份输入说明：连续 **3 次**完成“启动→确认 Ready→连接→进入固定 Mission→读取双方 Formation→结束 Mission→退出”。每次保留 run ID、PID、游戏版本、加载模块、连接状态、Mission 状态、Formation snapshot、退出结果。`build 成功`不能替代运行中 DLL 身份证明。

本阶段允许独立实验 Mod、接口草图和极小探针；不修改 CombatBrain 战术逻辑，不建立完整 GUI 或评价器，不制定包抄/骑兵/弓兵的 PASS 阈值。Phase 1 应在不加载 CombatBrain 的条件下完成。

## 判定层次

- `[CODE]`：对指定提交的源码检查；证明代码路径存在，不证明游戏里跑通。
- `[DOC]`：官方或维护者文档声称；不替代源码或运行证据。
- `[RUN]`：本机命令及日志；需写明是编译、单元测试还是游戏内运行。
- `[INFERENCE]`：从上述证据推断，不能独立支撑重大架构决定。
- `[UNKNOWN]`：尚无可靠证据，列入 [Open Questions](10-Open-Questions.md)。

本轮的 `[RUN]` 只有静态编译和本机文件读取，没有游戏内运行。无 Game Lifecycle、Mission Lifecycle 或 Formation runtime 的 GO 结论。
