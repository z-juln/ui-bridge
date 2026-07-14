# 实现 WorkBuddy Cursor 真实写入闭环

## Task ID

`2026-07-14-workbuddy-cursor-24d76f05`

## 创建日期

2026-07-14

## 一句话结果

WorkBuddy 与 Cursor 都能通过 App MCP Bridge 在独立临时文稿中完成一次可验证的真实写入。

## 完成后能得到什么

得到一套不会碰现有文稿的客户端验收流程，以及 WorkBuddy、Cursor 两端各自的真实写入与回读证据。
后续改动 MCP、Skill 或客户端配置时，可以复用同一流程确认“客户端能看到工具”之外，确实能完成安全写入、结果验证和失败清理。

## 交付物

- 可见产物：客户端真实写入验收脚本、操作说明和两端验收记录。
- 修改位置：`scripts/`、`skills/macos-ui-control/`、`docs/` 与本任务目录。
- 验证证据：独立 TextEdit 文稿、Bridge 回读结果、客户端调用结果和完整项目检查。

## 第一眼应该看什么

先读 `task_plan.md`、`progress.md`，再看客户端验收脚本和 `skills/macos-ui-control/references/setup.md`。

## 边界

- 范围内：安全测试夹具、客户端提示词与配置修正、WorkBuddy/Cursor 实际调用、结果回读、文档和证据。
- 范围外：向第三方发送消息、改动用户现有文稿、Windows 支持、公开签名与公证。
- 停止条件：客户端无法稳定定位测试会话、需要关闭含未保存内容的用户窗口，或两种路线均失败。

## 完成判断

- 测试目标与用户现有内容隔离，结束后可以安全清理。
- WorkBuddy 通过 `app-mcp-bridge` 写入唯一文本并由 Bridge 回读一致。
- Cursor 通过 `app-mcp-bridge` 写入另一唯一文本并由 Bridge 回读一致。
- 两端写入都经过计划检查、动作执行和写后验证；失败不留下测试内容。
- 构建、Skill 自检和 Harness 检查通过。

## 执行合同

- Owner：coordinator
- 生命周期状态：审查中
- 必需文件：`INDEX.md`、`task_plan.md`、`execution_strategy.md`、`visual_map.md`、
  `progress.md`、`findings.md`、`review.md`
- 完成条件：验证证据必须记录到 `progress.md`

## 当前下一步

检查最终差异和证据，完成任务生命周期收口。
