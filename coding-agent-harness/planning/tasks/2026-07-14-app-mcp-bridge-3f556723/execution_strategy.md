# 执行策略

## Subagent Authorization

| Role | Status | Permission | Authorized By | Authorized At | Scope | Worktree / Branch | Reuse |
| --- | --- | --- | --- | --- | --- | --- | --- |
| reviewer subagent | not-needed | read-only | coordinator | task creation | self review | n/a | no |
| worker subagent | not authorized | none | task contract | task creation | n/a | n/a | no |

## 决策表

| 决策 | 选择 | 说明 |
| --- | --- | --- |
| 主执行者 | coordinator | 迁移改动高度交叉，单人顺序执行更安全 |
| Subagent 模式 | none | 避免并行改名产生路径冲突 |
| 审查模型 | self-check | 全文零残留、产物检查和真实安装回归 |
| Worktree 策略 | same checkout | 当前 master 上连续小提交 |
| 证据深度 | L3 | 构建、安装、客户端配置和真实调用 |

## 证据计划

| 证据层级 | 检查 | 完成条件 |
| --- | --- | --- |
| L0 | 全文搜索、差异检查 | 当前树无旧名称 |
| L1 | Swift 构建与自检 | 全部通过 |
| L2 | App 包和客户端配置检查 | 新程序名、新标识、新路径 |
| L3 | 安装后状态、健康和调用 | 新 App 可用且错误不弹崩溃框 |
