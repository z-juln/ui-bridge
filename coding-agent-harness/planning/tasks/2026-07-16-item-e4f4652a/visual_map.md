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
  INIT01["INIT-01 范围与上下文\nkind=init"] --> EXEC01["EXEC-01 实现切片\nkind=execution"]
  EXEC01 --> GATE01["GATE-01 直接完成\nkind=gate"]
```

## 阶段表（Phase Table，表头供 checker 解析）

| Phase ID | Kind | Depends On | State | Completion | Output | Required Evidence | Exit Command | Actor | Evidence Status | Blocking Risk | Owner / Handoff |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- |
| INIT-01 | init | none | done | 100 | 验证门槛和安全边界已明确 | `task_plan.md` | `harness task-start 2026-07-16-item-e4f4652a` | agent | present | none | coordinator |
| EXEC-01 | execution | INIT-01 | done | 100 | 真实窗口验证和只读后备入口已完成 | diff、command 或 artifact path | `harness task-phase 2026-07-16-item-e4f4652a EXEC-01 --state done --completion 100 --evidence present` | agent | present | none | coordinator |
| GATE-01 | gate | EXEC-01 | done | 100 | 构建、真实窗口和既有回归完成 | progress update 和最终证据说明 | `harness task-complete 2026-07-16-item-e4f4652a --message "<summary>"` | agent | present | none | coordinator |

允许的 `State`：`planned`, `in_progress`, `review`, `blocked`, `done`, `skipped`。

允许的 `Evidence Status`：`missing`, `partial`, `present`, `waived`。

允许的 `Kind`：`init`, `execution`, `gate`。

允许的 `Actor`：`agent`, `human`, `coordinator`。

`Completion` 使用 `0..100` 的整数；`done` 应为 `100`，`planned` 应为 `0`，`skipped` 不计入 dashboard 总完成度。dashboard 的实现完成度只由非 skipped 的 `execution` 阶段计算；`init` 和 `gate` 阶段表达生命周期门禁、下一步命令和责任人，不拉低实现完成度。

## 支持性图表（Supporting Maps）

```mermaid
flowchart LR
  SNAP["当前窗口快照"] --> OCR["平台文字识别器"]
  OCR --> RESULT["文字 + 置信度 + 截图区域 + 窗口区域"]
  RESULT --> READ["只读候选查询"]
  READ --> PLAN["当前快照安全检查"]
  PLAN --> ACTION["执行一次"]
  ACTION --> VERIFY["新快照验证"]
```

Apple Vision 只读取当前快照附带的窗口截图，不直接执行操作，也不替代后续安全检查。

按需添加，不要求每类都存在：

- architecture：模块、组件、服务结构。
- sequence：前端、后端、服务、数据库、agent 时序。
- data-flow：数据流转和所有权。
- state：状态机或生命周期。
- topology：repo、服务、worker、worktree 拓扑。
- decision：方案分叉和决策树。
