# Visual Map / 可视化图谱

Visual Map Contract: v1.0

本文件是任务图表集合，不只是阶段路线图。只有对人或 agent 理解任务有实际帮助的图才放进来。

## 图表索引（Map Index）

| ID | Type | Purpose | Required For Understanding | Source Evidence | Promotion Candidate |
| --- | --- | --- | --- | --- | --- |
| MAP-01 | phase | 展示执行阶段和依赖关系 | yes | `task_plan.md` | no |

## 阶段关系图（Phase Graph）

```mermaid
flowchart LR
  INIT01["INIT-01 范围与上下文\nkind=init"] --> EXEC01["EXEC-01 设置窗口与真实状态\nkind=execution"]
  EXEC01 --> EXEC02["EXEC-02 实时画面与活动映射\nkind=execution"]
  EXEC02 --> EXEC03["EXEC-03 安全确认与诊断\nkind=execution"]
  EXEC03 --> GATE01["GATE-01 Agent 提交审查\nkind=gate"]
  GATE01 --> GATE02["GATE-02 人工审查确认\nkind=gate"]
```

## 阶段表（Phase Table，表头供 checker 解析）

| Phase ID | Kind | Depends On | State | Completion | Output | Required Evidence | Exit Command | Actor | Evidence Status | Blocking Risk | Owner / Handoff |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- |
| INIT-01 | init | none | done | 100 | 任务计划和执行策略已确认 | `task_plan.md`; `execution_strategy.md` | `harness task-start 2026-07-14-item-65db687f` | agent | present | none | coordinator |
| EXEC-01 | execution | INIT-01 | planned | 0 | 设置窗口、导航、总览和真实状态 | 构建、安装版窗口截图 | `harness task-phase 2026-07-14-item-65db687f EXEC-01 --state done --completion 100 --evidence present` | agent | missing | 布局与现有菜单生命周期冲突 | coordinator |
| EXEC-02 | execution | EXEC-01 | planned | 0 | 多应用真实画面、映射和事件 | 真实窗口截图、资源占用记录 | `harness task-phase 2026-07-14-item-65db687f EXEC-02 --state done --completion 100 --evidence present` | agent | missing | 持续截图性能与隐私 | coordinator |
| EXEC-03 | execution | EXEC-02 | planned | 0 | 应用访问、安全确认和诊断 | 门禁自检、安装版拒绝/允许证据 | `harness task-phase 2026-07-14-item-65db687f EXEC-03 --state done --completion 100 --evidence present` | agent | missing | 跨进程确认被绕过 | coordinator |
| GATE-01 | gate | EXEC-03 | planned | 0 | Agent Review Submission | `review.md`、progress update、lesson routing | `harness task-review 2026-07-14-item-65db687f --message "<summary>"` | agent | missing | 真实 UI 证据不完整 | coordinator |
| GATE-02 | gate | GATE-01 | planned | 0 | Human Review Confirmation | review packet 和人工确认 | `harness review-confirm 2026-07-14-item-65db687f --confirm 2026-07-14-item-65db687f` | human | missing | Agent 不能代办人工确认 | human |

允许的 `State`：`planned`, `in_progress`, `review`, `blocked`, `done`, `skipped`。

允许的 `Evidence Status`：`missing`, `partial`, `present`, `waived`。

允许的 `Kind`：`init`, `execution`, `gate`。

允许的 `Actor`：`agent`, `human`, `coordinator`。

`Completion` 使用 `0..100` 的整数；`done` 应为 `100`，`planned` 应为 `0`，`skipped` 不计入 dashboard 总完成度。dashboard 的实现完成度只由非 skipped 的 `execution` 阶段计算；`init` 和 `gate` 阶段表达生命周期门禁、下一步命令和责任人，不拉低实现完成度。

## 支持性图表（Supporting Maps）

按需添加，不要求每类都存在：

- architecture：模块、组件、服务结构。
- sequence：前端、后端、服务、数据库、agent 时序。
- data-flow：数据流转和所有权。
- state：状态机或生命周期。
- topology：repo、服务、worker、worktree 拓扑。
- decision：方案分叉和决策树。

```mermaid
flowchart LR
  CLIENT["Cursor / WorkBuddy"] --> BRIDGE["App MCP Bridge"]
  BRIDGE --> ACTIVITY["有界活动记录"]
  ACTIVITY --> LIVE["实时操控页"]
  BRIDGE --> RISK{"删除 / 购买 / 权限变更?"}
  RISK -- 否 --> TARGET["目标 App"]
  RISK -- 是 --> CONFIRM["App 内二次确认"]
  CONFIRM -- 同意 --> TARGET
  CONFIRM -- 拒绝或超时 --> STOP["不执行"]
```
