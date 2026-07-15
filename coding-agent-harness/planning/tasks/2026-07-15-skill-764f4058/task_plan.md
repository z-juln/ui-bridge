# 实现通用 Skill 安装教学入口

Task Contract: harness-task/v1
Task Package Index: required

## 目标

提供通用、透明、无需检测 Agent 状态的 Skill 安装教学入口。

## 范围

- 做什么：随 App 打包现有 Skill；连接页展示教学按钮；复制自包含安装提示词；更新文档。
- 不做什么：自动安装、客户端列表、安装状态检测、Skill 功能扩展、Web 和经验库。
- 主要风险：提示词引用不存在路径；教学入口被误解为自动安装；安装动作启动错误进程。

## 目标对齐反问

进入 implementation 前，从用户原始请求出发回答，而不是从当前最容易交付的局部切片出发回答。此表仍有占位时，不得开始实现。

| 问题 | 回答 / 证据 |
| --- | --- |
| 必须保持为真的原始用户目标是什么？ | 先提供一个简单、通用的 Skill 安装方式，后续再逐步丰富。 |
| 本任务是否直接让该目标更真实？ | yes；用户能从 App 获得真实可用的 Skill 源和安装提示词。 |
| 最容易误用的便利替代是什么？ | 只写文档却不把 Skill 放进 App，或硬编码某个 Agent 的安装目录。 |
| 本任务完成后不能声称什么？ | 不能声称 App 自动安装、能检测 Skill 状态或已经支持 Web。 |
| 如果这是 evidence-only、parity、comparison 或 gate-profile 工作，为什么它不等于 cutover 或完成？ | 不适用；默认 App 会新增可见入口。 |
| 如果这是 rewrite、retirement 或 cutover 工作，什么生产/default path 变化或删除证据能证明替换完成？ | 不适用。 |

## 预算选择

选择预算：simple

选择理由：只涉及一个资源打包切片、一个设置页弹窗和对应文档，可独立验证。

## 上下文包（Context Packet）

| ID | 类型 | 路径 | 为什么需要 | 使用者 |
| --- | --- | --- | --- | --- |
| C-001 | code | TARGET:Sources/ui-bridge/SettingsRootView.swift | 复用现有连接页结构和组件 | coordinator |
| C-002 | code | TARGET:scripts/build-app.sh | 确保安装包内真实存在 Skill | coordinator |
| C-003 | public-doc | TARGET:docs/02-protocol-and-integrations.md | 保持已确认的通用教学边界 | coordinator |

## 步骤

1. 将 `skills/ui-bridge-control/` 复制到 App 的只读 Resources。
2. 在连接页增加教学卡片、弹窗和复制提示词。
3. 构建安装，检查资源、界面、剪贴板内容和既有回归，再更新文档收口。

## 验收标准

- [x] App 包含完整 Skill 目录，源文件与仓库一致。
- [x] 教学入口不绑定 Agent，不显示猜测性的安装状态。
- [x] 复制提示词引用真实路径，只说明安装来源、安装动作和结果反馈。
- [x] 安装版交互、构建和现有自检通过。

## 工作树（Worktree）

- 路径：当前仓库
- 分支：master
- Worker owner：coordinator
- Worker handoff commit required：不适用
- Coordinator integration branch：master
- 未使用 worktree 的原因：单个小切片，文件边界清楚且无需并行。

## 长程任务判定

- 是否属于长程任务：否
- 若是，合同文件：`long-running-task-contract.md`
- 连续执行权限：已授权
- Stop Condition 摘要：需要修改未知 Agent 私有目录或扩大到自动安装时暂停。

## 审查判定

- 是否需要对抗性审查：否
- 若是，报告文件：不适用
- Reviewer：self
- No-finding 要求：不适用

## 关联

- 相关 Regression Gate：`coding-agent-harness/governance/regression/Regression-SSoT.md`
- 审查报告：不适用
- Generated Ledger：由 lifecycle CLI / `harness governance rebuild` 重建
- 前置任务：`2026-07-14-item-65db687f`

## 模块关联（启用模块并行时填写）

- Module：不适用
- Step：不适用
- Module Plan：不适用

## 协调者交接（Coordinator，启用模块并行时填写）

- Global sync owner：coordinator
- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：任务收口时重建
- Closeout / Regression update needed：`walkthrough.md`、`docs/04-current-status.md`
