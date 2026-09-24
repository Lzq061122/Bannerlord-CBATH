# DeepSeek Harness MCP 审计

审计版本：官方仓库提交 `46a7f68b0922371ce7144b668b90e377d8e799f4`。DeepSeek 官方将其称为 [developer preview](https://www.deepseek.com/harness/en/)；配置与插件 API 可能变化。

## 源码确认

- [CODE] [mcp-client 配置/注册](https://github.com/deepseek-ai/deepseek-harness/blob/46a7f68b0922371ce7144b668b90e377d8e799f4/packages/mcp/mcp-client/src/index.ts) 将一个外部 MCP server 作为一个插件实例接入，按 `mcp__<serverName>__<tool>` 命名；支持 `stdio` 与 `streamable-http`。stdio 由 SDK 启动子进程，HTTP 连 URL。
- [CODE] 每次工具调用默认 `toolCallTimeoutMs=60000`；`failOnStartupError=false` 意味着 MCP 初始连接失败时 Harness 可继续启动，但工具尚不可用。超时、取消和错误由 [tools.ts](https://github.com/deepseek-ai/deepseek-harness/blob/46a7f68b0922371ce7144b668b90e377d8e799f4/packages/mcp/mcp-client/src/tools.ts) 与 [connection.ts](https://github.com/deepseek-ai/deepseek-harness/blob/46a7f68b0922371ce7144b668b90e377d8e799f4/packages/mcp/mcp-client/src/connection.ts) 处理。
- [CODE] 断线后的默认重连从 500ms 指数退避，最大 30s；连续失败 10 次后停止并撤销工具。旧工具在短暂断线期可仍列出，但调用会失败。插件卸载时释放连接/注册。
- [DOC] [客户端 README](https://github.com/deepseek-ai/deepseek-harness/blob/46a7f68b0922371ce7144b668b90e377d8e799f4/packages/mcp/mcp-client/README.md) 提供配置例子和限制；与上述源码一致。没有“任意长同步 tool call 保证不断线”的承诺。

## Phase 1 适用性

**判断：可以作为主要实施/控制 Agent 的候选，但端到端适用性待联调。** GABS 已提供 MCP stdio，DSH 有相应客户端代码，因此协议层具备路径；本轮未在 DSH 中启动 GABS 或控制真实 Bannerlord。P1-002 须验证 `games.list → games.start → games.connect → core/ping → games.stop` 的实际调用、超时与错误上报。

建议在 DSH 配置中独立设置一个 `serverName: gabs`、`transport: stdio` 的 MCP entry，并在本地显式指定 GABS 可执行路径。长时间战斗不要做一次超长同步调用：由游戏端持续运行 Mission，Agent 使用短调用轮询状态和定期快照；若确需长调用，同时设置 DSH `toolCallTimeoutMs` 与 GABS `games.call_tool.timeout`，外层不得短于内层。具体数值由首次联调的真实启动/加载时间确定。

测试 Mod 和 GABS 不引用 DSH 私有类型；通用 MCP 仍供 Codex、Claude Code 或别的 client 使用。这是为 developer preview 的变化保留边界。DSH 被设为控制者而非游戏状态真源。
