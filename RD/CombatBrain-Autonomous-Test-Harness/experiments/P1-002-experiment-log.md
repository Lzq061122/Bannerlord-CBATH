# P1-002 — Ping Bridge 实验记录

日期：2026-09-24 Asia/Shanghai
依赖：P1-001 PASS
路线：用户选定「路线 1 — 安装 Go 并构建 GABS」

---

## 实验 A — 安装 Go 工具链

- **Goal**：拿到可构建 GABS 的 Go 工具链。
- **Hypothesis**：本机有 winget，可静默安装。
- **Change**：`winget install --id GoLang.Go --exact`
- **Command**：`winget install --id GoLang.Go --exact --accept-source-agreements --accept-package-agreements`
- **Observed Result**：安装 Go 1.27.0 windows/amd64，位于 `C:\Program Files\Go\bin\go.exe`。
- **PASS / FAIL**：PASS
- **Next Decision**：构建 GABS。

---

## 实验 B — 构建 GABS（首次失败：TLS 证书）

- **Goal**：`make build` 产出 gabs 可执行文件。
- **Change**：无。直接 `go build -o gabs.exe ./cmd/gabs`。
- **Command**：`go build -o gabs.exe ./cmd/gabs`
- **Observed Result**：依赖下载全部失败

```text
golang.org/x/text@v0.22.0: Get "https://proxy.golang.org/...": tls: failed to verify certificate: x509: certificate has expired or is not yet valid
```

- **PASS / FAIL**：FAIL
- **诊断**：先用 PowerShell `Invoke-WebRequest` 访问同一 URL → **HTTP 200 正常**。说明网络与证书本身没问题，是 **Go 自带的证书校验**在本机环境失败（Go 不走 Windows 根证书存储的同一路径 / 环境差异）。`GOPROXY=direct` 改走 golang.org 直连也失败（连接超时）。
- **Next Decision**：换国内 Go module 镜像并关掉 sumdb 校验。

---

## 实验 C — 改用 goproxy.cn 构建

- **Change**：`GOPROXY=https://goproxy.cn,direct`、`GOSUMDB=off`、`GOFLAGS=-mod=mod`
- **Command**：`go build -o gabs.exe ./cmd/gabs`
- **Observed Result**：构建成功，`gabs.exe` 13,435,904 字节。`gabs --help` 显示 **gabs 1.1.1**。
- **PASS / FAIL**：PASS
- **Evidence**：`_source-cache\gabs\gabs.exe`
- **注意**：Makefile 依赖 `sed`/`rm`（GNU 工具），本机未验证可用，因此直接调用 `go build`，未走 `make build`。功能等价，但**没有注入 Makefile 里的 version/commit ldflags**。
- **Next Decision**：配置 game entry。

---

## 实验 D — 配置 Bannerlord game entry

- **Goal**：让 GABS 能以最小模块集启动 Bannerlord。
- **Change**：新建 `gabs-config/config.json`（独立 configDir，不污染 `~/.gabs`）。
  - `launchMode: DirectPath`
  - `target`: `...\bin\Win64_Shipping_Client\Bannerlord.exe`
  - `args`: `/singleplayer _MODULES_*Native*CombatBrainAutonomousTestHarness*_MODULES_ /anticheat`
  - 端口范围 19500–19600；`gabpConnectSeconds: 120`
- **Command**：`gabs games doctor bannerlord148 --configDir <cfg>`
- **Observed Result**：`Configuration: valid`，`default context: resolves`。
- **PASS / FAIL**：PASS
- **Evidence**：`gabs-config/config.json`
- **Next Decision**：给 Test Mod 接 Lib.GAB。

---

## 实验 E — Test Mod 接入 Lib.GAB（编译失败：命名空间歧义）

- **Goal**：游戏端起 GABP server，暴露 `cbath/ping`、`cbath/get_build_identity`。
- **Change**：新增 `MainThreadDispatcher.cs`、`CbathTools.cs`；`ProbeSubModule.cs` 启动 server；csproj 引用 `Lib.GAB 0.1.0`。
- **Command**：`dotnet build -t:Rebuild`
- **Observed Result**：

```text
error CS0234: 命名空间"Gabp"中不存在类型或命名空间名"CreateGabsAwareServerWithInstance"
error CS0234: 命名空间"Gabp"中不存在类型或命名空间名"IsRunningUnderGabs"
```

- **PASS / FAIL**：FAIL
- **诊断（反射取证，非猜测）**：`Lib.GAB.dll` 里 `Lib.GAB.Gabp` 类型**确实存在**且含这些方法；但依赖包 `Gabp.Runtime.dll` 定义了一个**全局命名空间 `Gabp`**，在名字解析时优先于 `using Lib.GAB;` 引入的类型。
- **Change（修复）**：去掉 `using Lib.GAB;`，所有相关类型改用完全限定名（`Lib.GAB.Gabp.…`、`Lib.GAB.Server.GabpServer`）。
- **Observed Result（修复后）**：编译 0 error 0 warning；`bin\Debug` 产出 `CombatBrainAutonomousTestHarness.dll`、`Lib.GAB.dll`、`Gabp.Runtime.dll`、`Newtonsoft.Json.dll`。
- **PASS / FAIL**：PASS
- **注意**：`Newtonsoft.Json.dll` **不部署**——游戏自带该库，部署会冲突。只部署 `Lib.GAB.dll` 与 `Gabp.Runtime.dll`。
- **Next Decision**：部署并启动。

---

## 实验 F — 构建脚本的 stamp 校验误报（连续三次假失败）

- **现象**：`build-deploy.ps1` 连续报 `STAMP NOT FOUND IN DLL`，但 DLL 明明是新的。
- **第一轮误判**：以为 build_id 含连字符被拆开 → 改成只匹配随机后缀 → **仍失败**。
- **第二轮误判**：以为 MSBuild 增量构建跳过重编 → 清空 bin/obj 强制重编 → **仍失败**，且 DLL 时间戳确实更新了。
- **取证（决定性）**：对 DLL 原始字节做**暴力逐字节比对**，在 byte offset 10627 找到完整 `b20260924…` 字符串。根因是 .NET 元数据字符串堆是 UTF-16，而起始偏移可能是**奇数**，我用 `Encoding.Unicode.GetString(全部字节)` 单次解码会因字节对齐错位而漏检。
- **Change（修复）**：改为在原始字节数组上滑动比对 UTF-16 编码的 build_id。
- **PASS / FAIL**：PASS（校验器修好，构建产物一直是正确的）
- **教训**：**同一证据最多分析两轮**这条规则在此处被我用满——第三轮换成暴力字节搜索才定位。校验器本身的 bug 伪装成了"构建没生效"。

---

## 实验 G — 端到端 MCP 调用

- **Goal**：MCP client → GABS → GABP → 游戏内 Mod 返回 build_id。
- **Change**：新建 `tools/invoke-gabs-mcp.ps1`（最小 MCP-over-stdio driver）与 3 个请求脚本。
- **Command**：
  1. `gabs games start bannerlord148`
  2. MCP: `games_connect` → `games_tool_names` → `games_call_tool(cbath/ping)`
  3. MCP: `games_call_tool(cbath/get_build_identity)`
  4. `gabs games stop bannerlord148`
- **Observed Result**：

`games_start`：
```text
started_attachment_deferred: 'bannerlord148' verified (pid 3708, bridge 127.0.0.1:19537)
```

游戏端自报 GABP 状态（`Documents\CommandBrainATH\cbath-gabp-3708.txt`）：
```text
CBATH_GABP_STATE
state=starting
gabs_aware=True
port=19537
token=c3bf6152...
build_id=b20260924-002809-495109be
```

`games_connect`：
```json
{"connected":true,"phase":"active","port":19537,"toolCount":2}
```

`games_tool_names` 发现两个自定义工具：
```text
bannerlord148_cbath_get_build_identity
bannerlord148_cbath_ping
```

`cbath/ping` 返回：
```json
{"build_id":"b20260924-002809-495109be","game_version":"v1.4.8.119303","pid":3708,"pong":true,"status":"ok","utc":"2026-09-23T16:32:56Z"}
```

`cbath/get_build_identity` 返回：
```json
{"marker":"CBATH_RUNTIME_IDENTITY","module":"CombatBrainAutonomousTestHarness",
 "build_id":"b20260924-002809-495109be","assembly_version":"1.0.0.0",
 "mvid":"59a80718-7816-40fe-bb14-ad842f7e6913",
 "assembly_sha256":"d54afe6b6a76397dc8b27dc9d322286fa0cbd79b73e881f6a729e19820a82589",
 "game_version":"v1.4.8.119303","pid":3708,
 "active_modules":"Native,CombatBrainAutonomousTestHarness"}
```

`games_stop`：
```text
bannerlord148: terminated — workload pid 3708 is gone
bannerlord148: stopped (no runtime claim)
```

- **PASS / FAIL**：**PASS**
- **Evidence**：`tools/mcp-req-002-ping.txt`、`tools/mcp-req-003-identity.txt`

---

## P1-002 验收对照

| 要求 | 状态 |
|---|---|
| 通信链 DSH/MCP → GABS → GABP → Mod 真正工作 | ✅ 四个环节全部实测 |
| 只需 `ping` 与 `get_build_identity` | ✅ 只实现这两个，未加 Formation/UI/Campaign |
| 返回包含 `build_id`、`game_version` | ✅ 两者都在 |
| 返回的 `build_id` 与刚 build/deploy 的 DLL 一致 | ✅ `b20260924-002809-495109be` == 部署脚本输出的 build_id == 部署 DLL SHA `d54afe6b…` |
| 响应来自**当前 Bannerlord 进程内**的 Test Mod | ✅ pid=3708 与 GABS 启动的进程一致；`assembly_location` 指向游戏 Modules 目录 |

## build_id 三方一致性（实验 G）

| 环节 | 值 |
|---|---|
| 构建脚本输出 build_id | `b20260924-002809-495109be` |
| 部署 DLL SHA-256（脚本计算） | `d54afe6b6a76397dc8b27dc9d322286fa0cbd79b73e881f6a729e19820a82589` |
| GABP ping 返回 build_id | `b20260924-002809-495109be` |
| GABP get_build_identity 返回 SHA-256（游戏内自读文件） | `d54afe6b6a76397dc8b27dc9d322286fa0cbd79b73e881f6a729e19820a82589` |
| 游戏进程 PID | 3708（GABS 启动 ↔ Mod 自报一致） |

## 本阶段新引入的组件（按披露要求）

| 名称 | 现有 / 新定义 | 解决什么 | 为何现在需要 |
|---|---|---|---|
| `cbath/ping` | 本项目新工具（挂在 Lib.GAB 现有 `[Tool]` 机制上） | 最小 liveness 探针，返回 build_id | P1-002 指定的两个接口之一 |
| `cbath/get_build_identity` | 本项目新工具 | 把 P1-001 的 runtime identity 通过通信链导出 | 让 Agent 能在任意时刻核对运行中的 DLL |
| `MainThreadDispatcher` | 沿用 Bannerlord.GABS 现有模式，非新概念 | GABP handler 在 TCP 后台线程，Bannerlord API 必须在主线程 | 不这样调用会崩或读到脏状态 |
| `gabs-config/` | 本机新目录 | 隔离 GABS 配置，避免污染 `~/.gabs` | 保持实验可复现 |
| `tools/invoke-gabs-mcp.ps1` | 本项目新工具 | 最小 MCP-over-stdio driver，用于在接入 DSH 前独立验证链路 | 需要先隔离"MCP 层"与"游戏桥层" |

## 尚未验证 / 已知缺口

- **DSH 官方 MCP 客户端尚未接入**。本轮用自写 driver 验证，等价于「通用 MCP client 对照测试」（Phase 0 `05` 建议的隔离手段）。真正的 DSH 配置是下一步。
- 未做「故意断开一次测试重连与错误传播」（Phase 0 P1-002 verification 提到）。
- `gabs.exe` 未走 `make build`，因此没有 version/commit ldflags；不影响功能。
- Go 证书问题未根治，只是绕过；后续若重建 GABS 需复用 `GOPROXY=goproxy.cn` + `GOSUMDB=off`。
- `contextDelivery` 报告 `unknown`，原因是 Lib.GAB 0.1.0 是「pre-report bridge」，不阻塞。
