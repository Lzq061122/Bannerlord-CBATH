# 固定 Mission 的自动进入路线

本轮没有运行游戏内 Mission。表中“可行性”是基于源码的建议，不能当作已通过实验。

| 路线 | 已有证据 | 重复性 / 复杂度 / 版本敏感度 | Phase 1 取舍 |
|---|---|---|---|
| A. Custom Battle 现成 UI/API | [DOC] 游戏有 CustomBattle 模块；[UNKNOWN] 尚未找到本版本可从外部直接传完整固定场景的已验证入口。 | UI 若需多步交互，速度与稳定性受影响；数据可固定程度待实测。 | 候选，不先承诺。 |
| B. Console / debug command | [CODE] GABS 有 `core/run_command` 与 `core/list_commands`；具体创建固定战斗的命令及参数未实测。 | 如果命令在 1.4.8 存在，开发量低；命令可用性与场景控制待验证。 | **先做只读命令发现**。找到可重复命令就优先使用。 |
| C. 独立 Test Mod 进入固定 Mission | [CODE] BannerlordCoop 的 [CoopFieldBattleLauncher](https://github.com/Bannerlord-Coop-Team/BannerlordCoop/blob/b99b788649917975508a9a92881319cf91f5c7a9/source/Missions/Battles/CoopFieldBattleLauncher.cs#L100) 展示 `MissionState.OpenNew`、spawn 及原生 behaviors 组合；该仓库许可证限制复用代码。 | 可控性较强，但实现复杂、对版本敏感；需完整验证加载与结束。 | **主路线的后备实现**：若 B 无法满足固定场景，写最小 Test Mod 工具。只借鉴概念，不复制 Coop 代码。 |
| D. 直接由 GABS 工具调用 `MissionState.OpenNew` | 实质仍需编写 C# 游戏端工具和初始化链，不是零开发。 | 与 C 同一类风险，直接混入全量 GABS 增加移植面。 | 在独立 Test Mod 内实现，不扩张全量 GABS。 |
| E. GUI 键鼠 | [DOC] Windows computer-use 项目提供截图/输入；[UNKNOWN] Bannerlord 启动器与战斗 UI 运行可靠性未测。 | 焦点、分辨率、弹窗使重复性低；可作恢复通道。 | 仅在 B/C 均受阻时辅助，不作为结构化状态来源。 |

**推荐顺序**：先在已经加载的最小桥中列出 1.4.8 实际 console 命令，尝试找到能进入固定 Mission 的命令；若不能完整固定双方、地图和初始配置，按 C 开发专用测试工具。评价 Route B 成功须提供真实 Mission 运行、双方 Formation 快照和三次重复记录；“命令列表里有类似名字”不足以通过。

## 具体实验约束

固定最小场景先取少量双方士兵、一张固定地图与固定配置；不必先做 300 vs 300。进入后由游戏端返回 scene、mission 时间、team ID/side、双方 Formation。退出后确认 `Mission.Current` 已消失，再退出进程。复现输入要保存在机器可读配置中，并记录游戏 build、Mod build、随机种子（若可设置）和运行时间。

关于确定性：目前没有源码/运行证据证明 Bannerlord AI、物理或 spawn 可逐帧复现。Phase 1 判定结构与生命周期是否稳定，不比较每帧坐标；后续战术断言再决定统计重复次数和阈值。
