# 执行策略

## Subagent Authorization

| Role | Status | Permission | Authorized By | Authorized At | Scope | Worktree / Branch | Reuse |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reviewer subagent | not-needed | read-only | coordinator | task creation | 当前任务自审足够 | n/a | no |
| worker subagent | not authorized | none | task contract | task creation | 不适用 | n/a | no |

## Subagent Delegation Decision

| Question | Decision | Reason | Next Action |
| --- | --- | --- | --- |
| Should a reviewer subagent be used? | no | 单机真实交互不能并行，任务合同指定 self review | coordinator 自审并记录证据 |
| Would a worker subagent materially help? | no | WorkBuddy、Cursor、TextEdit 共用桌面状态，顺序执行更安全 | coordinator 独立完成 |

## User Authorization Decision

| Gate | State | Decided By | Decided At | Scope | Worktree / Branch | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| worker subagent | not-needed | coordinator | 2026-07-14 | 单机顺序验收 | master | 用户未要求子代理，任务也不适合并行桌面操作 |

## 决策表

| 决策 | 选择 | 说明 |
| --- | --- | --- |
| 主执行者 | coordinator | 统一维护桌面状态、隔离测试文稿和最终收口 |
| Subagent 模式 | none | 避免多个执行者争用 WorkBuddy、Cursor 和 TextEdit |
| 审查模型 | self-check | 两个真实客户端、独立界面和安装后回归提供直接证据 |
| Worktree 策略 | same checkout | 单协调者、单分支、连续小提交 |
| 冲突控制 | coordinator owns shared files | 全部本任务文件由 coordinator 顺序修改 |
| 证据深度 | L3 | 真实客户端写入加安装后运行验证 |

## 子代理 / Worker 合同

| 角色 | 输入包 | 写入范围 | 交接要求 | 负责人 |
| --- | --- | --- | --- | --- |
| n/a | C-001、C-002、C-003 | n/a | n/a | coordinator |

## 证据计划

| 证据层级 | 计划命令或检查 | 记录位置 | 完成条件 |
| --- | --- | --- | --- |
| L0 | `git diff --check`、令牌与测试产物检查 | `progress.md` | 无格式问题、无敏感文件 |
| L1 | Swift 构建、协议和核心自检 | `progress.md` | 全部通过 |
| L2 | Skill 自检、安装、状态、健康和错误路径 | `walkthrough.md` | App 可运行，错误不弹崩溃框 |
| L3 | Cursor 与 WorkBuddy 真实写入、最新快照回读、TextEdit 独立核对 | `walkthrough.md`、`review.md` | 两端唯一标记完全一致 |

## 暂停 / 升级条件

- 需要覆盖用户现有内容或关闭非测试窗口。
- 需要把令牌写入提示词、命令或仓库文件。
- 两个安全入口都不能完成写入。
- 出现开放 P0/P1/P2 或任务范围发生变化。
