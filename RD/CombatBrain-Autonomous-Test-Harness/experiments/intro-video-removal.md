# 开场动画（工作室 Logo 视频）处理记录

日期：2026-09-24
起因：用户建议「开场有一个显示工作室名称的动画，按 ESC 跳过就行」

---

## 结论

**已解决：把开场视频文件移出游戏目录，开场动画消失，到主菜单由 ~30s 降到 ~3s。**

未采用的方式：ESC 按键模拟、第三方 mod。

---

## 为什么没有采用 ESC 按键

按照 prompt 的路线优先级：

```text
Game API / Test Mission
> Console / Debug API
> Process automation
> Computer Use / 鼠标点击
```

ESC 按键模拟属于最后一层「输入注入」，且在无人值守场景需要抢窗口焦点（P1-001 阶段已证明焦点不可靠）。在尚未证明结构化路线不可行之前，不该引入。用户后续也明确指示不要在这一点上死磕、优先找现成方案。

## 为什么没有采用第三方 mod

1. 搜索引擎对该查询返回噪声（"Nexus" 被识别成桌面美化工具、结果全是游戏官网/百科），没有得到有效 mod 链接。
2. 本机测试刻意采用**最小模块集**（Native + CBATH）以排除干扰；引入第三方 mod 等于往刚刚验证干净的链路上加一个未知变量，与「先证明最小闭环」相悖。
3. 找到了更干净的办法（见下）。

---

## 实际采用的办法：移走开场视频资源

### 定位

`GauntletVideoPlaybackScreen` 播放的资源位于游戏 Native 模块的 Videos 目录：

| 文件 | 大小 |
|---|---|
| `TWLogo_and_Partners.mp4` | 12,446,114 |
| `TWLogo_and_Partners.ivf` | 9,554,528 |
| `TWLogo_and_Partners.ogg` | 522,589 |

路径：`E:\SteamLibrary\steamapps\common\Mount & Blade II Bannerlord\Modules\Native\Videos\`

### 操作

三个文件全部备份到 `_intro-video-backup\`，再移到 `_intro-video-hidden\`。**未删除、未修改**，可随时还原。

### 实验数据

判据：新增 `ScreenProbe`，在游戏主线程每 tick 采样 `ScreenManager.TopScreen` 类型，记录每次变化的时刻。

**改之前**（基线）：
```text
CBATH_SCREEN_TRANSITIONS
0s  <null>
14s GauntletVideoPlaybackScreen    ← 开场动画开始
30s GauntletInitialScreen          ← 主菜单到达
```

**改之后**：
```text
CBATH_SCREEN_TRANSITIONS
0s  <null>
3s  GauntletInitialScreen          ← 主菜单到达，视频屏完全消失
```

**到主菜单：30s → 3s，减少约 27 秒。**

### 最终确认（走完整 GABS 链路）

- `games_connect`：`Discovered 3 tools`（新增 `cbath/get_game_state`）
- `cbath/get_game_state` 返回：
  - `topScreenType = TaleWorlds.MountAndBlade.GauntletUI.GauntletInitialScreen`
  - `activeGameState = TaleWorlds.MountAndBlade.InitialState`
  - `mission = <null>`（尚未进 Mission，符合预期）
  - `transitions = 0s <null> | 3s GauntletInitialScreen`
- `games_stop`：`terminated — workload pid 31716 is gone`，无残留进程

游戏态健康，没有因为缺视频而报错或卡住。

---

## 顺带产出的能力：`cbath/get_game_state`

为了量化这个问题而加，但这项能力**本身就是 P1-004 必需的**——prompt 明确要求：

> 必须存在实际状态检查。不要「调用创建函数 → sleep 10 秒 → 假设已经进入」。

它返回 `topScreenType` / `activeGameState` / `mission` / `transitions`，使得后续「等 MissionRunning」可以基于真实条件而非 sleep。

新增文件：
- `experiments/test-mod/CBATH/ScreenProbe.cs`
- `CbathTools.cs` 增加 `cbath/get_game_state`
- `ProbeSubModule.cs` 在 tick 中调用 `ScreenProbe.Sample()`

---

## 复现 / 还原

- 还原：`_intro-video-backup\` 三个文件复制回 `Modules\Native\Videos\`
- 当前状态：**视频已移走**（`_intro-video-hidden\`）
- 注意：Steam 验证游戏文件完整性会把这三个文件恢复回来，届时开场动画会重新出现

---

## 过程中的失误记录

1. **窗口标题不能作为启动阶段判据**。游戏窗口标题从 2s 起就是 `- Singleplayer`，到 95s 都没变过，无法区分「播片中」和「已到主菜单」。改用 `ScreenManager.TopScreen` 才拿到真实阶段。
2. **第一次 A/B 的判据写错了**：抓的是「首个非 null screen」，而那恰好就是视频屏本身，所以有无 ESC 都是 2s，实验无效。改成记录 screen 类型序列后才有效。
3. **`ScreenManager` 命名空间猜错**。它不在 `TaleWorlds.MountAndBlade`（尽管打包在 core 包里），而在 `TaleWorlds.ScreenSystem`。第一次「编译通过」是假象——那个文件当时还没加进 csproj 的 Compile 列表，根本没被编译。
4. **又一次踩到 `safely_exited`**：本轮收尾时强杀进程导致它被写回 0，下一次经 GABS 启动时游戏进入 Safe Mode，Mod 未加载（未产生任何 CBATH 文件）。复位为 1 后正常。此坑已出现两次，应把复位动作加到任何「杀进程」之后。
