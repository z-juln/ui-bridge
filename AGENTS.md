# App MCP Bridge Agent 入口

本仓库当前开发 App MCP Bridge 的 macOS 实现，通过本地 HTTP、MCP 和 Skill
供 Cursor、WorkBuddy 及其他 Agent 使用。详细产品范围见 `docs/`，当前任务事实见
`coding-agent-harness/planning/tasks/2026-07-10-macos-ui-bridge-96db7c45/`。

## 项目概况

- 技术栈：Swift 6、macOS 14.4+、AXUIElement、ScreenCaptureKit、官方 MCP Swift SDK。
- 仓库形态：单仓、单协调者、可跨 Agent 接力。
- 第一轮入口：无界面服务 App、本地 HTTP、MCP stdio、MCP Streamable HTTP、通用 Skill。
- 默认分支：`master`。

## 不可违反的规则

1. 核心能力必须通用，禁止在核心代码写应用名称、联系人名称或固定屏幕坐标。
2. 所有坐标必须来自目标窗口的当前快照；窗口变化后旧快照必须失效。
3. 优先按控件操作，坐标仅作补充；后台失败不得静默升级前台。
4. 系统调用成功不等于任务成功，写动作后必须重新读取并验证界面结果。
5. 服务只监听本机回环地址；不得提交密钥、令牌、截图、聊天正文或真实用户数据。
6. 密码类控件值不得返回；疑似敏感字段默认遮盖。
7. 发送、删除、购买、权限变更等高影响动作必须返回确认要求，不能自行完成最终动作。
8. 保护任务范围外的用户改动，不使用破坏性 Git 命令。
9. 每个可运行、已验证的切片都必须更新任务 `progress.md` 并提交。
10. 提交信息必须包含 `Harness: 2026-07-10-macos-ui-bridge-96db7c45` 和
    `AI-Co-Authored-By: <Agent 名称>`。
11. 每次接力先执行 `git status --short`、阅读任务计划和进度，再从“下一步”继续。
12. 不得因为额度不足而留下未说明的半成品；停止前必须提交可用切片并更新交接。

## 阅读路由

| 任务 | 先读 |
| --- | --- |
| 任何实现 | 当前任务的 `brief.md`、`task_plan.md`、`progress.md`、`long-running-task-contract.md` |
| 架构或边界 | `docs/01-product-and-architecture.md`、`coding-agent-harness/context/architecture/Architecture-SSoT.md` |
| HTTP/MCP/Skill | `docs/02-protocol-and-integrations.md` |
| 测试与验收 | `docs/03-delivery-and-validation.md`、`coding-agent-harness/governance/regression/Regression-SSoT.md` |
| 本地构建 | `coding-agent-harness/context/development/local-setup.md` |
| 研究和决策 | 当前任务 `findings.md` |

## 标准执行循环

1. 阅读当前任务 `progress.md` 的最后记录和残余。
2. 选择一个边界清楚、能单独验证的切片。
3. 实现并运行相关构建、测试或真实应用冒烟。
4. 更新 `progress.md`、必要的 `findings.md` 和架构文档。
5. 只暂存本切片文件并提交。
6. 重复，直到完成条件满足或触发暂停条件。

## 提交切片

推荐顺序：

1. Harness 与交接规范。
2. Swift 包、协议模型和基础测试。
3. 应用/窗口发现与辅助功能树。
4. 单窗口截图和坐标换算。
5. 通用动作与验证。
6. 本地 HTTP 服务和管理命令。
7. MCP 服务。
8. 通用 Skill 与 Cursor/WorkBuddy 接入。
9. 四类应用回归和收口。

## 当前本地命令

项目骨架建立前，以任务 `progress.md` 为准。骨架建立后必须维护以下稳定入口：

- 构建：`swift build`
- 基础自检：`swift run protocol-self-test`
- 状态：`swift run macos-ui-bridge status`
- Harness 检查：`npx --yes coding-agent-harness check --profile target-project .`

## 完成标准

只有当第一轮核心、HTTP、MCP、通用 Skill 和四类代表应用证据均已落盘，任务审查
无阻塞发现，walkthrough 与进度记录完整时，才能声明完成。
