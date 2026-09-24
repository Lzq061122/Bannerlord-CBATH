# DeepSeek Harness ↔ GABS 接入说明

日期：2026-09-24

## 配置位置

DSH 的 MCP 由 **`dsh-mcp-mgr`**（workspace 级 MCP 管理器）发现，读取 workspace 内的：

```text
<workspace>\.dsh\dshmm\mcp.json
```

本机实际路径：

```text
E:\MBmod\CombatBrain Autonomous test harness\.dsh\dshmm\mcp.json
```

这样配置的好处：只作用于本 workspace，不污染 `~/.dsh` 全局，也不影响其他项目。

## 配置内容

标准 Claude/Codex `mcpServers` 格式：

```json
{
  "mcpServers": {
    "gabs": {
      "type": "stdio",
      "command": "E:\\MBmod\\CombatBrain Autonomous test harness\\_source-cache\\gabs\\gabs.exe",
      "args": [
        "server", "stdio",
        "--configDir", "E:\\MBmod\\CombatBrain Autonomous test harness\\gabs-config",
        "--log-level", "info"
      ],
      "cwd": "E:\\MBmod\\CombatBrain Autonomous test harness"
    }
  }
}
```

字段名要点（踩过坑）：

| 字段 | 说明 |
|---|---|
| `type` | **不是 `transport`**。`dsh-mcp-mgr` 的 `parse.js` 读的是 `rawEntry.type`。缺失会被当成 HTTP 简写，然后报 `http servers require a "url"` |
| `command` / `args` | stdio 必需 |
| `cwd` | 默认 workspace 根，显式写更稳 |

`serverName` 必须匹配 `^[A-Za-z0-9_-]{1,32}$`，`gabs` 合法。

## 校验方法（改配置后先做这个，别急着重启）

`dsh-mcp-mgr` 自带解析函数，可以直接调用来验证：

```js
import { parseMcpJson } from '<profile>/node_modules/dsh-mcp-mgr/lib/types/parse.js';
console.log(parseMcpJson(text, workspacePath));
```

返回 `errors: []` 且 `servers` 里出现正确映射（含 `transport: "stdio"`、`toolCallTimeoutMs: 60000`）才算有效。

## 生效方式

**不需要重启 Web 服务。** 管理器有 watch/rescan，新建或修改 `mcp.json` 后约几十秒内自动挂载。

验证是否挂载成功的判据（不是看文档）：

```powershell
Get-Process gabs | Select-Object Id, StartTime
# 再用 WMI 看父进程必须是 node.exe（DSH 宿主），且 CommandLine 与配置逐字一致
Get-CimInstance Win32_Process -Filter "ProcessId = <pid>"
```

## 重要：不要在 start 之后改 mcp.json

改动会触发 DSH 重新加载 MCP 服务器，**杀掉旧的 gabs 子进程**，连带杀掉它启动的游戏。

已发生一次：启动成功 → 中途修正 mcp.json → gabs 与游戏双双退出 → `games_tool_names` 返回 `Game is currently 'stale-runtime-cleaned'`。

排查这类现象先确认 gabs 进程是否还活着。

## mcp-client 的默认行为

| 项 | 值 |
|---|---|
| 工具调用超时 | 60000 ms |
| MCP 启动失败 | `failOnStartupError: false` —— Harness 继续运行但工具不可用 |
| 断线重连 | 500ms 起指数退避，最大 30s，连续失败 10 次后停止并撤销工具 |

因此**工具列在列表里不等于可用**，必须真实调用一次。

## 工具命名

`mcp__<serverName>__<tool>` → 例如 `mcp__gabs__games_start`。

游戏端的自定义工具经 GABS 镜像后是 `bannerlord148_cbath_ping` 这类名字，但 `games_call_tool` 用原始名 `cbath/ping` 调用。
