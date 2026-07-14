# Harness Ledger

## Purpose

Generated canonical task lifecycle index. Humans should use the Dashboard for current status; agents should use `task-list`, `task-index`, or this generated ledger for low-cost lookup.

This file is not a hand-written work log. Do not edit lifecycle rows manually. Update task-local facts (`task_plan.md`, `progress.md`, `review.md`, `lesson_candidates.md`, closeout / walkthrough evidence), then run `harness governance rebuild --archive --apply`.

Repo Governance / CI-CD changes remain routed through their reference standards and task evidence. Regression gates, delivery sequencing, cadence rules, closeout contracts, and module ownership remain in their dedicated governance files until explicitly replaced by equivalent scanner-supported facts.

## Active Ledger

| ID | Scope | Module | Task | State | Queues | Plan | Review | Lessons Check | Closeout | Residual | Updated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| HL-2026-07-10-macos-ui-bridge-96db7c45 | task | none | 实现 macOS 通用 UI Bridge 第一轮 | closed | done | coding-agent-harness/planning/tasks/2026-07-10-macos-ui-bridge-96db7c45/task_plan.md | agent-reviewed | checked | coding-agent-harness/planning/tasks/2026-07-10-macos-ui-bridge-96db7c45/walkthrough.md | state-conflicts:1 | 2026-07-14 |
| HL-2026-07-14-workbuddy-cursor-24d76f05 | task | none | 实现 WorkBuddy Cursor 真实写入闭环 | active | none | coding-agent-harness/planning/tasks/2026-07-14-workbuddy-cursor-24d76f05/task_plan.md | pending | pending | pending | 开始建立隔离测试夹具并验证两个真实客户端写入 | 2026-07-14 |

## Field Rules

- `Scope`: `task` for root planning tasks, `module` for module-local tasks.
- `Module`: module key, or `none`.
- `Queues`: scanner-derived lifecycle queues; query with `harness task-list --queue`.
- `Review`, `Lessons Check`, `Closeout`, and `Residual`: scanner-derived summaries and routes. Detailed evidence stays in task-local files.
- `Updated`: generation date, not a manual edit timestamp.

## Legacy Tables

`Feature-SSoT.md` and `Private-Feature-SSoT.md` are legacy task lifecycle projections. Current Harness versions archive them during `harness governance rebuild --archive --apply` and do not regenerate them.
