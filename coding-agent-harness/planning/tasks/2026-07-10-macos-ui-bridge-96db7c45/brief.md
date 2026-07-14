# 实现 macOS 通用 UI Bridge 第一轮

## Task ID

`2026-07-10-macos-ui-bridge-96db7c45`

## 一句话结果

交付一个无产品界面的 macOS 通用桌面操作服务，可由 Cursor/WorkBuddy 通过
HTTP、MCP 和 Skill 发现窗口、读取控件、执行动作并验证结果。

## 交付物

- Swift 服务 App 与命令行入口。
- 通用应用/窗口/控件/截图/动作/验证核心。
- 本地 HTTP 与 MCP。
- 可安装的通用 Skill 和客户端配置。
- 自动测试与 TextEdit、Finder、企业微信、Electron 真实应用证据。
- 持续更新的任务进度、发现、提交和交接记录。

## 第一眼应该看什么

1. `progress.md`：当前做到哪里、最后验证和下一步。
2. `task_plan.md`：完整阶段和验收标准。
3. `long-running-task-contract.md`：连续执行与暂停边界。
4. `docs/`：产品、架构和协议事实。

## 边界

- 范围内：macOS 通用核心、端口、MCP、Skill、四类代表应用验证。
- 范围外：Windows、产品 UI、自动更新、正式公证、云端视觉模型、应用专属脚本。
- 暂停条件：需要改变架构主方向、需要外部凭据/付费、权限无法取得、或所有可用
  验证路线均受阻。

## 完成判断

- `swift build` 和 `swift test` 通过。
- HTTP 与 MCP 能完成同一组通用任务。
- Skill 能在 Cursor 触发；WorkBuddy 至少一种入口实测可用。
- 四类代表应用证据完成且核心没有应用专属逻辑。
- 每个阶段有可恢复提交，任务文档能让新 Agent 直接继续。

## 当前下一步

macOS 第一轮已完成验收并进入最终收口。后续工作转入独立任务：完成由
WorkBuddy/Cursor 真实发起的安全写入与回读确认闭环。
