# P2-009 SetControlledByAI 双参语义 + FinishDeployment 就绪条件 — 最小确认实验（IL 层）

日期：2026-09-25
类型：IL/元数据层最小确认（Mono.Cecil 直接读取游戏程序集）
来源：`E:\SteamLibrary\...\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.dll`
（游戏实际加载的程序集，非引用集）

---

## 一、结论

| 项 | 结论 | 依据 |
|---|---|---|
| `SetControlledByAI` 参数语义 | `(bool isControlledByAI, bool enforceNotSplittableByAI)` | 游戏程序集 IL 参数名 |
| F6 实际调用的参数 | **`SetControlledByAI(true, false)`** | `Team.DelegateCommandToAI` IL 逐条确认 |
| `FinishDeployment` 就绪条件 | **`DeploymentMissionController.TeamSetupOver == true`**（public getter） | 元数据 + OnMissionTick IL |
| 就绪后调用链 | `TeamSetupOver → SetupTeams → (可选自动) FinishDeployment` | OnMissionTick / SetupTeams IL |

---

## 二、证据 1：`SetControlledByAI` 双参语义（游戏程序集）

```
=== Formation.SetControlledByAI ===
  params: Boolean isControlledByAI, Boolean enforceNotSplittableByAI
```

**第二个参数 = `enforceNotSplittableByAI`**（是否强制该编队不可被 AI 拆分）。

IL 体关键路径（上一轮已 dump，此处摘要）：

```
if (IsAIControlled == isControlledByAI) return;          // 幂等
set_IsAIControlled(isControlledByAI);
if (isControlledByAI) {
    if (AI.ActiveBehavior != null && CountOfUnits > 0) {
        forceTick; AI.Tick(); restoreForceTick;
        if (behavior changed) behavior.OnBehaviorActivated();
        SetMovementOrder(AI.ActiveBehavior.CurrentOrder);   // ← 副作用：重设移动命令
    }
    _enforceNotSplittableByAI = enforceNotSplittableByAI;
} else {
    _enforceNotSplittableByAI = false;
    if (AI.ActiveBehavior != null) AI.ActiveBehavior.OnLostAIControl();
}
```

**副作用确认（重要）**：
1. `SetMovementOrder(AI.ActiveBehavior.CurrentOrder)` —— **调用时会重设该编队的移动命令**。
   这正是 Charter 记载的"AI 接管时 Movement 域被写"的行为，属于引擎设计，不是异常。
2. 编队拆分限制：`_enforceNotSplittableByAI` 字段被设置 —— F6 用 `false` 表示**不限制拆分**。

---

## 三、证据 2：F6 = `Team.DelegateCommandToAI()` = `SetControlledByAI(true, false)` 全编队

```
=== Team.DelegateCommandToAI (F6) ===
  params: (无参)
  SetControlledByAI call site prev ops: ldc.i4.1, ldc.i4.0, callvirt
```

`ldc.i4.1` = `true`（isControlledByAI）
`ldc.i4.0` = `false`（enforceNotSplittableByAI）

完整 IL（上一轮已 dump）：

```
foreach (var f in Team.FormationsIncludingEmpty)
    f.SetControlledByAI(true, false);
```

**逐条对应**：F6 键 = 遍历玩家队**所有** Formation（含空编队）调用 `SetControlledByAI(true, false)`。
这就是人工 F6 的完整引擎语义。

> 顺带确认：`DelegateCommandToAI` 的唯一调用者是 `Mission.OnAgentRemoved`
> （由玩家 Agent 移除/阵亡时触发），F6 键的输入处理在 UI 层直接调用它。

---

## 四、证据 3：`FinishDeployment` 就绪条件 = `TeamSetupOver`（public）

```
=== DeploymentMissionController ===
  PROP TeamSetupOver getter public=True
```

`OnMissionTick` IL（上一轮已 dump）：

```
if (!TeamSetupOver) {
    if (Mission.Current.Scene != null) {
        SetupTeams();
        TeamSetupOver = true;
    }
}
if (TeamSetupOver && !AfterSetupTeamsCalled) { OnAfterSetupTeams?.Invoke(); AfterSetupTeamsCalled = true; }
```

**就绪判定**：`TeamSetupOver == true` 表示 teams 已设置、场景已加载。
这是**公开属性**，可直接轮询，无需 sleep。

### 调用链

```
DeploymentMissionController.FinishDeployment 的调用者：
  DeploymentHandler.FinishDeployment           ← 「准备」按钮的 handler
  DeploymentMissionController.SetupTeams        ← 当 CanPlayerSideDeployWithOrderOfBattle()==false 时自动调用

DeploymentHandler.FinishDeployment 的调用者：
  SiegeDeploymentHandler.FinishDeployment      ← 围城专用
```

`FinishDeployment()` 内部（已 dump）关键效果：
- `Mission.Current.OnDeploymentFinished()` —— 引擎级"部署结束"信号
- `Mission.AllowAiTicking = true` —— **AI 开始可 tick**（部署期被 `AfterStart` 置 false）
- 设置 `InitialPlayerAgent` detachable、玩家 Agent controller=2
- `Mission.OnAfterDeploymentFinished()`
- 移除自身 behavior

**关键洞察**：`AllowAiTicking=true` 是 `FinishDeployment` 的**直接可观测效果**，
也是"现在 AI 可以动"的引擎级前提。这与 F6 的 `SetControlledByAI(true)` 是**互补**关系：
先 `FinishDeployment`（开 AI ticking）再 `DelegateCommandToAI`（把编队交给 AI）。

---

## 五、结论性建议（供工具实现）

### `cbath/auto_finish_deployment`

```
1. 找到 Mission 上的 DeploymentMissionController（或其子类 BattleDeploymentMissionController）
2. 轮询 TeamSetupOver == true（公开 getter；场景加载完成 + teams 设置完成的信号）
3. 调用 controller.FinishDeployment()（public void）
4. 验证：Mission.AllowAiTicking == true 且 / 或 mission 的 deployment 状态已切换
```

### `cbath/delegate_team_to_ai`

```
1. 取玩家 Team（Mission.PlayerTeam）
2. 遍历 Team.FormationsIncludingEmpty（与 F6 完全一致）
3. 对每个调用 f.SetControlledByAI(true, false)
4. 返回每个编队调用前后 IsAIControlled
```

**两者都与 F6/「准备」的引擎行为逐字节一致，无 Win32 输入模拟。**

---

## 六、需要一次运行期验证的剩余问题

IL 层已确认 API 与参数。仍须**最小运行实验**验证：

1. `TeamSetupOver` 在 CustomBattle 实际从 false→true 的时机（是否与部署界面出现一致）；
2. 调用 `FinishDeployment()` 后 `Mission.AllowAiTicking` 确实变 true（IL 已证，运行期再确认一次）；
3. 调用 `SetControlledByAI(true, false)` 后 `IsAIControlled` 稳定为 true，且不破坏战斗
   （P2-007 已人工 F6 验证过同样参数，风险低）；
4. 全程无需鼠标键盘。

该运行期实验在实现两个工具时以"工具自验证"形式完成（工具返回调用前后状态，
由测试断言确认），不另做一次性探针。
