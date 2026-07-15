# 实现完整设置与实时调试界面

Task Contract: harness-task/v1
Task Package Index: required

## 目标

把当前菜单栏工具扩展为完整、可调试、可确认危险动作的原生 macOS 管理界面。

## 范围

- 做什么：设置导航、真实状态总览、活动应用实时画面、客户端映射、应用访问、安全确认、诊断导出。
- 不做什么：Windows 实现、远程访问、账户系统、长期保存截图或应用正文。
- 主要风险：持续截图的性能与隐私、跨进程活动信息不足、危险动作确认不能只停留在展示层。

## 目标对齐反问

| 问题 | 回答 / 证据 |
| --- | --- |
| 必须保持为真的原始用户目标是什么？ | App 内能看到所有正在操作应用的实时界面，并能管理设置与危险动作确认。 |
| 本任务是否直接让该目标更真实？ | yes；它直接实现用户确认的原型，而不是新增孤立调试页。 |
| 最容易误用的便利替代是什么？ | 用静态示意图、假事件或单张历史截图冒充实时映射。 |
| 本任务完成后不能声称什么？ | 不能声称已支持 Windows，也不能把未接入执行链的弹窗称为安全闭环。 |
| 如果这是 evidence-only 工作，为什么它不等于完成？ | 不适用，本任务必须改变安装版默认可见行为。 |
| 如何证明替换完成？ | 安装版菜单与程序坞均可打开窗口，真实 MCP 操作会出现在实时页，危险动作必须经过 App 确认。 |

## 预算选择

选择预算：complex

选择理由：涉及原生界面、持续截图、跨进程状态、安全门禁和真实应用验收。

## 上下文包（Context Packet）

| ID | 类型 | 路径 | 为什么需要 | 使用者 |
| --- | --- | --- | --- | --- |
| C-001 | code | `TARGET:Sources/ui-bridge/` | 现有菜单栏、活动提示和 App 生命周期 | coordinator |
| C-002 | code | `TARGET:Sources/UIBridgeMacCore/AutomationActivityCenter.swift` | 现有真实活动来源 | coordinator |
| C-003 | public-doc | `TARGET:docs/01-product-and-architecture.md` | 产品边界和隐私规则 | coordinator |
| C-004 | private-plan | `TARGET:coding-agent-harness/planning/tasks/2026-07-10-macos-ui-bridge-96db7c45/` | 已完成能力与回归证据 | coordinator |

## 步骤

1. 建立设置窗口、导航和总览，接入服务、权限、连接与活动状态。
2. 建立唯一的操控会话中心：由常驻 App 持有活动目标和 ScreenCaptureKit 持续画面流，界面只订阅最新画面，不自行截图或启动辅助进程。
3. 接入应用访问、安全策略及危险动作 App 内二次确认。
4. 完成诊断、安装版真实应用验收、文档和审查收口。

## 验收标准

- [ ] 菜单栏和程序坞均能打开设置窗口，七个栏目可导航。
- [ ] 所有状态来自当前服务、权限或活动记录，不使用演示数据。
- [x] 活动应用有真实实时缩略图和大画面，窗口消失后能安全降级。
- [x] 实时页不轮询单张截图、不启动旧单张截图子进程；离开页面后所有预览流均停止。
- [x] 实时页展示真实客户端到目标应用的映射，并区分只读、执行、复查、待确认和取消事件。
- [x] 诊断页展示真实服务、权限、客户端和画面状态，可复制摘要并主动导出脱敏报告。
- [x] 删除、购买、权限变更必须 App 内二次确认，拒绝或超时不执行。
- [x] 产品、App、命令、连接、系统身份和本地状态统一为 UI Bridge / `ui-bridge`，旧名称只用于升级迁移和历史审计。
- [x] 浏览器页面与内嵌 WebView 的未来方向已形成独立边界文档，明确细节待定且当前未实现。
- [ ] 安装版构建、自检、真实只读与安全写入回归通过。

## 工作树（Worktree）

- 路径：当前仓库
- 分支：master
- Worker owner：coordinator
- Worker handoff commit required：不适用
- Coordinator integration branch：master
- 未使用 worktree 的原因：单协调者连续开发，用户要求不间断小提交。

## 长程任务判定

- 是否属于长程任务：是
- 若是，合同文件：`long-running-task-contract.md`
- 连续执行权限：已授权
- Stop Condition 摘要：安全闭环无法实现或需扩大权限时暂停。

## 审查判定

- 是否需要对抗性审查：是
- 若是，报告文件：`review.md`
- Reviewer：self
- No-finding 要求：无 open P0/P1/P2，且完成真实 App 验收。

## 关联

- 相关 Regression Gate：`coding-agent-harness/governance/regression/Regression-SSoT.md`
- 审查报告：`review.md`
- Generated Ledger：由 lifecycle CLI 重建
- 前置任务：`2026-07-10-macos-ui-bridge-96db7c45`

## 模块关联

- Module：不适用
- Step：不适用
- Module Plan：不适用

## 协调者交接

- Global sync owner：coordinator
- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：任务收口时更新
- Closeout / Regression update needed：`docs/04-current-status.md`
