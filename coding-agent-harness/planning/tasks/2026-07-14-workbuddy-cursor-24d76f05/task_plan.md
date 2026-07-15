# 实现 WorkBuddy Cursor 真实写入闭环

Task Contract: harness-task/v1
Task Package Index: required

## 目标

WorkBuddy 与 Cursor 均能通过 UI Bridge 对独立临时 TextEdit 文稿完成真实写入，并由最新界面快照确认结果。

## 范围

- 做什么：提供隔离验收流程；修正必要的客户端配置、Skill 和 Bridge 行为；在两个真实客户端完成写入和回读。
- 不做什么：不操作用户已有文稿，不发送外部消息，不扩展 Windows，不处理公开分发签名。
- 主要风险：客户端缓存旧连接；Cursor 的 stdio 进程权限归属；WorkBuddy 页面状态与内部任务状态不同步；测试窗口误选。

## 目标对齐反问

进入 implementation 前，从用户原始请求出发回答，而不是从当前最容易交付的局部切片出发回答。此表仍有占位时，不得开始实现。

| 问题 | 回答 / 证据 |
| --- | --- |
| 必须保持为真的原始用户目标是什么？ | Cursor/WorkBuddy 不只是连上 MCP，而是能用通用 Bridge 完成可验证的真实写入。 |
| 本任务是否直接让该目标更真实？ | yes；验收从“工具可见”提升到“客户端实际写入并回读一致”。 |
| 最容易误用的便利替代是什么？ | 用自测客户端代替 WorkBuddy/Cursor，或只展示工具列表和只读快照。 |
| 本任务完成后不能声称什么？ | 不能声称 Windows 已支持、所有应用都可写、公开分发已就绪。 |
| 如果这是 evidence-only、parity、comparison 或 gate-profile 工作，为什么它不等于 cutover 或完成？ | 不适用；若发现客户端路径缺陷，本任务会直接修复并重跑。 |
| 如果这是 rewrite、retirement 或 cutover 工作，什么生产/default path 变化或删除证据能证明替换完成？ | 不适用。 |

## 预算选择

选择预算：standard

选择理由：范围只包含两个客户端和一个隔离文本目标，但需要真实桌面交互、失败清理与多轮验证。

## 上下文包（Context Packet）

| ID | 类型 | 路径 | 为什么需要 | 使用者 |
| --- | --- | --- | --- | --- |
| C-001 | private-plan | TARGET:coding-agent-harness/planning/tasks/2026-07-10-macos-ui-bridge-96db7c45/walkthrough.md | 第一轮能力、已知残余和客户端现状 | coordinator |
| C-002 | code | TARGET:scripts/configure-mcp-clients.sh | 两个客户端的实际连接方式 | coordinator |
| C-003 | private-plan | TARGET:skills/macos-ui-control/SKILL.md | 写动作、确认和写后验证规则 | coordinator |

## 步骤

1. 建立独立临时 TextEdit 测试夹具、唯一测试文本与清理约束。
2. 从 WorkBuddy 发起完整写入，读取最新快照确认结果；修复发现的问题。
3. 从 Cursor 发起同样闭环，重跑构建、自检与文档检查并记录交接。

## 验收标准

- [x] WorkBuddy 真实写入与最新快照回读一致。
- [x] Cursor 真实写入与最新快照回读一致。
- [x] 测试窗口与用户内容隔离，失败和完成路径均可清理。
- [x] 配置、Skill、构建和项目检查通过。

## 工作树（Worktree）

- 路径：不适用
- 分支：`master`
- Worker owner：coordinator
- Worker handoff commit required：不适用
- Coordinator integration branch：不适用
- 未使用 worktree 的原因：单协调者顺序执行，客户端真实交互不能并行争用桌面。

## 长程任务判定

- 是否属于长程任务：是
- 若是，合同文件：`long-running-task-contract.md`
- 连续执行权限：已授权
- Stop Condition 摘要：两个客户端各自完成隔离写入回读，或两条安全路线均受客户端环境阻断。

## 审查判定

- 是否需要对抗性审查：否
- 若是，报告文件：`review.md`
- Reviewer：self
- No-finding 要求：自审无 open P0/P1。

## 关联

- 相关 Regression Gate：TARGET:coding-agent-harness/governance/regression/Regression-SSoT.md
- 审查报告：不适用
- Generated Ledger：由 lifecycle CLI / `harness governance rebuild` 重建
- 前置任务：TASKS/2026-07-10-macos-ui-bridge-96db7c45

## 模块关联（启用模块并行时填写）

- Module：不适用
- Step：不适用
- Module Plan：不适用

## 协调者交接（Coordinator，启用模块并行时填写）

- Global sync owner：coordinator
- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：由 lifecycle CLI 重建
- Closeout / Regression update needed：`walkthrough.md`；Regression SSoT 无需调整
