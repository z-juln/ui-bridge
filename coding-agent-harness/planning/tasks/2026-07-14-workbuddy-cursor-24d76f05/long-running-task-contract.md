# 实现 WorkBuddy Cursor 真实写入闭环 - 长程任务合同

## 目标

让 WorkBuddy 与 Cursor 都通过 UI Bridge 完成一次隔离、可回读验证的真实写入。

## 范围

### 范围内

- `scripts/` 的安全验收夹具。
- `skills/macos-ui-control/` 与客户端接入文档。
- 为修复真实客户端链路所必需的 Bridge 代码与测试。
- WorkBuddy、Cursor 和独立 TextEdit 测试会话。

### 范围外

- 用户现有文稿和第三方消息。
- Windows、公开签名、公证和其他应用专项适配。

### 共享文件 / 冲突风险

- 客户端本机配置只做必要更新并保留备份；Bridge 代码由 coordinator 独占修改。

## 主调用入口（Primary Caller / Entry）

- 主调用方（Primary caller）：WorkBuddy UI、Cursor UI
- 本任务必须支持的入口：WorkBuddy Streamable HTTP MCP、Cursor 当前配置的 MCP。
- 明确不要求的入口：Windows 客户端、第三方远程客户端。

## 执行授权（Execution Permission）

- 是否允许连续执行（Continuous execution）：allowed
- 是否允许每轮后不再询问直接继续：yes
- 是否允许启动审查 agent / 子代理：no
- 是否需要审查报告：no
- 仍需人工批准的动作：
  - 向第三方发送消息、覆盖用户现有内容、删除非测试数据。

## 必需循环

每一轮至少包含：

1. 实现、编辑或配置。
2. 本地运行。
3. 测试、冒烟或检查。
4. 执行 Confidence Challenge。
5. 如合同要求审查者或子代理，更新 `review.md`。
6. 修复 findings。
7. 重新收集证据。
8. 重跑 Confidence Challenge，直到没有 open 重要发现。
9. 更新 `progress.md`。

最低循环次数或无重要发现要求：

- 至少两轮：WorkBuddy 一轮、Cursor 一轮；任一修复后重跑对应客户端。

## 审查者 / 子代理合同（Reviewer / Subagent）

- 审查者角色（Reviewer role）：self
- 审查范围（Reviewer scope）：客户端写入链路、隔离性、写后验证与清理。
- 如果是 code-change worker：
  - Worktree path：不适用
  - Branch：master
  - 任务目录：`coding-agent-harness/planning/tasks/2026-07-14-workbuddy-cursor-24d76f05/`
  - 交接前提交（Commit before handoff）：不适用
  - 交接必须包含：commit SHA、checks、residual risks
- Reviewer 必须报告：
  - 缺陷、回归、缺失测试和未验证假设。
- Reviewer 不得：
  - 改动用户现有内容、发送外部消息、擅自扩大到其他平台。

## 证据

完成前必需证据：

- [x] `swift build`
- [x] Bridge 与 Skill 自检
- [x] WorkBuddy 真实写入并回读
- [x] Cursor 真实写入并回读
- [x] Harness check
- [x] 自审无 open P0/P1
- [x] walkthrough 和 progress 已更新

## 完成条件（Stop Condition）

任务只有在以下条件满足后才可停止并声明完成：

- [x] 两个客户端各自完成真实写入和回读一致。
- [x] 构建、自检和 Harness 检查通过。
- [x] 客户端与 Bridge 错误已清除，或记录为非阻塞残余。
- [x] 自审无 open P0/P1。
- [x] 测试内容可安全清理；为保留当前人工核对证据，三个未保存测试窗口暂未关闭。

## 暂停条件（Pause Conditions）

遇到以下情况必须暂停并汇报：

- [ ] 目标或范围已经失效。
- [ ] 需要高风险的产品、架构、安全或数据决策。
- [ ] 未知的无关改动与本任务冲突。
- [ ] 环境阻断了所有有用证据的收集。
- [ ] 审查者发现改变了任务方向。

## 交付物（Deliverables）

- [x] 代码 / 配置改动
- [x] 测试 / 回归证据
- [x] 文档更新
- [x] 如要求审查，`review.md` 报告
- [x] `progress.md` / `findings.md` 更新
- [x] Harness Ledger 更新
- [x] 收口记录
- [x] Lessons 反思与检查：`lesson_candidates.md` 已进入 `no-candidate-accepted` / `needs-promotion` / `promoted` / `rejected`
- [x] PR / commit / 发布说明
- [x] 残余风险摘要
