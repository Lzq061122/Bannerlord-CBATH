# Bannerlord v1.4.8.119303 兼容性

## 已验证事实

1. [RUN] 本机 Steam manifest `261550` 给出的 build ID 为 `24573425`，Native/SubModule.xml 声明 `v1.4.8`；见 [本机记录](evidence/local-game-facts.txt)。[NuGet 精确版本](https://www.nuget.org/packages/Bannerlord.ReferenceAssemblies/1.4.8.119303) 页面也标同一 build ID。此为版本关联证据；未检查游戏运行时加载的每个 DLL。
2. [CODE] GABS 的 [supported-game-versions.txt](https://github.com/BUTR/Bannerlord.GABS/blob/b44f5cf085509b2a6544a684a5fc5ec543fa073c/src/Bannerlord.GABS/supported-game-versions.txt) 为 beta `v1.3.15`、stable `v1.3.13`、最低 `v1.2.12`。仓库发布说明支持 v1.2.x / v1.3.x，不能假定对 v1.4.8 可直接使用。
3. [RUN] 在**隔离的源码副本**中仅将上述三行改为 `v1.4.8`，执行 `dotnet build ... -c Stable_Debug -p:CopyToGame=false -p:DeployOnBuild=false`；还原结果确含 `Bannerlord.ReferenceAssemblies` 及 Core、Native、SandBox、CustomBattle 的 `1.4.8.119303`。构建失败：**29 个独立 CS 错误**、20 个 warning。见 [命令与上下文](evidence/gabs-v148-build-context.txt)、[完整编译记录](evidence/gabs-v148-build.txt)。没有部署到游戏目录。
4. [RUN] 独立 [Formation API 探针](experiments/formation-api-probe/FormationApiProbe.cs) 用精确版本总包编译成功：0 error、0 warning。它实际编译了 `Mission.Current.Teams`、TeamIndex/Side、每队 `FormationsIncludingEmpty`、阵型 class/index/unit count、`CurrentPosition`、`Direction`、AI 控制状态及 `OrderController.GetActive*OrderOf` 三类命令；见 [输出](evidence/formation-api-probe-build.txt)。这只证明 API **编译可用**，不证明运行时数值正确。

## 全量 GABS 编译错误分布

| 源码区域 | 独立错误数 | 典型 API 变化 |
|---|---:|---|
| `Behaviors/CombatEventBehavior.cs` | 4 | `MapEventSide.Casualties` 缺失 |
| `Behaviors/HeroEventBehavior.cs` | 2 | 事件参数签名变化、`HeroesMarried` 缺失 |
| `Tools/GauntletUITools.cs` | 1 | `GauntletLayer.MoviesAndDataSources` 缺失 |
| `Tools/KingdomTools.cs` | 4 | `Kingdom.TotalStrength`、`Clan.Lords/CommanderLimit` 缺失 |
| `Tools/PartyTools.CompanionParty.cs` | 7 | 创建/移动 API 的签名或方法名变化 |
| `Tools/PartyTools.cs` | 11 | `MobilePartyAi` 方法和 `ExplainedNumber` 类型变化 |
| **合计** | **29** | 详细位置见编译记录 |

该错误分布说明：**全量 fork 移植风险 HIGH**；成本主要落在 Phase 1 不需要的 campaign/UI/event 工具。**最小测试 Mod 风险 MEDIUM，但运行风险仍 UNKNOWN**：本轮探针覆盖双方阵型读取的关键签名，却没有真实 Mission、spawn、连接、mod 加载结果。因此不报具体工时，也不宣称简单替换版本文件即可使用。

## 实施约束

- Phase 1 不因全量 GABS 报错而修复无关战役功能。先只编译并加载必要的 `ping`、状态、双方 Formation、固定 Mission 生命周期工具。
- 每次构建记录 Git commit 或源码树 hash、DLL SHA-256、构建 ID。游戏端在连接后返回**自己加载的 DLL 文件 SHA-256 与嵌入 build ID**，与刚部署的值对比；不相等立即失败，禁止继续测试。
- 运行时再查对 `Mission.Current.Teams` 是否覆盖玩家/敌军/第三方 Team，空阵型处理、位置/朝向/命令值是否稳定，以及 Custom Battle 的 state 判断。这些是 [10-Open-Questions.md](10-Open-Questions.md) 的待验证项。
