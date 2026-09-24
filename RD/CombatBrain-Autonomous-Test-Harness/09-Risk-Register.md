# Phase 1 风险登记

优先级按“会否阻断三轮完整闭环”排序。以下不是已发生的游戏运行故障；实际故障以运行日志重新归类。

| 风险 | 已有证据 / 当前判断 | Detection | Recovery | Abort condition |
|---|---|---|---|---|
| 1.4.8 游戏端无法加载或运行 | [RUN] 全量 GABS 有 29 编译错误；最小 API 探针编译成功，运行仍 [UNKNOWN] | 构建结果、模块加载日志、GABP ping、运行 build ID | 缩小到最小 Mod，逐工具加入 | Mod 未加载、build ID 不匹配或多次崩溃 |
| 新 DLL 未被使用 | [INFERENCE] 自动构建常见误判，输入说明特别要求排除 | 构建/部署 hash、嵌入 ID、MVID、运行时响应 | 关闭所有游戏进程，查模块目录与加载路径，重新部署 | 任一标识不一致立即停止测试 |
| 启动器/Safe Mode 卡住 | [CODE] GABS 脚本专门复位 `safely_exited`；本机尚未运行 | 启动超时、进程树、GABP 不可达、截图辅助 | 一次受控清理并重试，保留对话框现场 | 重试仍未 Ready |
| 进程已起但游戏尚不可测 | [CODE] `games.start` 与 GABP Ready 分离 | PID、GABP、ping、状态四条件分别记录 | 有界等待和状态轮询 | 到期仍未满足 Ready |
| MCP/GABP 断线或 DSH 超时 | [CODE] DSH 默认 60s、GABS 工具默认 30s；均可配置 | 分层调用时间与连接状态、明确错误 | 重新连接一次；长动作分拆为短调用 | 重连失败、超时后无法确认游戏状态 |
| 固定 Mission 无法无人值守进入 | [UNKNOWN] 尚无现成已验证命令/工具 | scene、Mission time、双方 Team | console 探测；不满足则实现最小 Test Mod Mission 工具 | 两路线均不能重复进入相同场景 |
| Mission 卡 loading / 永不结束 | [UNKNOWN] | 阶段超时、时间不增长、无双方 Team | 结束 Mission；必要时按本轮 PID 清理 | 清理失败或连续重试仍卡住 |
| 阵型遗漏或读到假状态 | [CODE] GABS 现有工具仅玩家方；[RUN] all-team API 编译通过 | Team 数、side、Formation IDs、跨帧变化与一次可视对照 | 修 game-side 枚举与序列化 | 任一侧缺失、字段虚构或冲突 |
| 随机性/帧时序影响判定 | [UNKNOWN] 没有确定性实测 | 同场多轮输入、种子、结果分布 | Phase 1 只判生命周期/结构，后续采用统计断言 | 不把逐帧不一致当成 Phase 1 失败，除非破坏固定场景 |
| 退出残留 / DLL 锁 | [UNKNOWN] | PID 及子进程、文件锁/部署 hash | 先正常 stop，失败再定向 force kill，确认消失后部署 | 清理不完整时禁止下一轮 |
| Coop 源码许可误用 | [CODE] 仓库 LICENSE 限制跨项目复用 | 代码来源审查 | 只看设计思路，自己实现 | 发现复制受限代码时停止并移除 |

视觉测试与 Windows computer-use 当前仅用于截图、异常弹窗和启动器诊断；不作为 Mission/Formation 真值。Steam 自动更新需通过游戏 build ID 门禁阻断测试，避免不同版本结果混合。
