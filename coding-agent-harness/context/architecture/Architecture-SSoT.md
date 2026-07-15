# Architecture SSoT

Context Doc Type: architecture-ssot
Owner: project coordinator
Source Evidence: TARGET:docs/01-product-and-architecture.md
Last Verified: 2026-07-15
Confidence: high

## 系统边界

UI Bridge 当前是 macOS 本机服务。系统输入是来自受信任本地客户端的 HTTP/MCP
请求，输出是应用/窗口/控件快照、动作结果和验证证据。服务不监听局域网，不把
截图默认上传云端。

统一产品边界是“本机界面目标”，而不是“桌面 App”。当前仅实现 `native_app`；
未来计划增加 `browser_page` 与 `embedded_webview`，三类目标共享权限、风险确认、
活动展示和结果验证，底层读取与执行通道分别实现。Web 方案尚未定型，见
`TARGET:docs/05-future-web-plan.md`。

## 核心边界

- `Protocol`：与平台无关的数据模型、错误和动作契约。
- `MacCore`：应用、窗口、AX 树、截图、动作和验证。
- `Server`：回环 HTTP、令牌、会话和动作串行化。
- `MCPAdapter`：把 MCP 工具映射到同一 Server/Core 能力。
- `CLI`：start/stop/status/permissions/token/doctor/mcp。
- `Skill`：只规定 Agent 调用流程，不承载底层实现。

## 硬约束

1. 核心不可依赖具体应用名称或固定坐标。
2. 写动作必须引用当前快照并产生新快照证据。
3. 后台到前台是显式升级，不是内部自动重试。
4. HTTP 与 MCP 不得实现两套业务逻辑。
5. 系统权限归属稳定 App Bundle，CLI 不直接持有权限。

完整设计见 `TARGET:docs/01-product-and-architecture.md`。
