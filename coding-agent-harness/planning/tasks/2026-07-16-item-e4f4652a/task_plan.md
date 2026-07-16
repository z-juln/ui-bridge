# 验证并接入本机视觉文字定位

Task Contract: harness-task/v1
Task Package Index: required

## 目标

验证 Apple Vision 在 M3 16GB 真实 macOS 界面上的文字区域识别；通过门槛后接入为只读视觉后备能力。

## 范围

- 做什么：跨平台文字区域契约、macOS Apple Vision 实现、真实窗口探针、只读 MCP/HTTP 查询和说明。
- 不做什么：本地大视觉模型、图标识别、自动点击、Windows 实现、经验库存储和截图落盘。
- 主要风险：OCR 文字正确但区域不适合作为控件候选；Retina、裁剪和坐标原点换算导致偏移；模型冷启动影响延迟。

## 目标对齐反问

进入 implementation 前，从用户原始请求出发回答，而不是从当前最容易交付的局部切片出发回答。此表仍有占位时，不得开始实现。

| 问题 | 回答 / 证据 |
| --- | --- |
| 必须保持为真的原始用户目标是什么？ | 先在本机验证 Apple Vision，效果足够好才用于 UI Bridge；Windows 将来使用对应系统实现。 |
| 本任务是否直接让该目标更真实？ | yes；先用真实窗口形成证据，再以平台无关契约接入，不凭文档推测效果。 |
| 最容易误用的便利替代是什么？ | 只证明能调用 Vision，或者只看识别文字而不验证区域、速度和坐标。 |
| 本任务完成后不能声称什么？ | 不能声称能识别无文字图标、理解复杂画面或已经支持 Windows。 |
| 如果这是 evidence-only、parity、comparison 或 gate-profile 工作，为什么它不等于 cutover 或完成？ | 验证通过只是接入门槛；只有默认服务入口、回归和文档同步后才能声明可用。 |
| 如果这是 rewrite、retirement 或 cutover 工作，什么生产/default path 变化或删除证据能证明替换完成？ | 不替换原有无障碍读取；新增按需后备入口，并证明正常任务默认仍走结构路线。 |

## 预算选择

选择预算：simple

选择理由：单个平台识别器、一个只读接口和一组真实窗口证据，边界清楚且可独立回滚。

## 上下文包（Context Packet）

| ID | 类型 | 路径 | 为什么需要 | 使用者 |
| --- | --- | --- | --- | --- |
| C-001 | code | TARGET:Sources/UIBridgeMacCore/WindowCapture.swift | 复用当前窗口截图，不新增截屏流程 | coordinator |
| C-002 | code | TARGET:Sources/UIBridgeMacCore/AutomationRuntime.swift | 绑定当前快照、过期和截图生命周期 | coordinator |
| C-003 | private-plan | TARGET:docs/01-product-and-architecture.md | 保持结构优先、视觉后备和跨平台边界 | coordinator |

## 步骤

1. 建立平台无关文字区域结果和 macOS Apple Vision 识别器，制作真实窗口探针。
2. 在真实中文窗口中检查文字命中、区域范围、坐标换算和冷热延迟；不通过则只记录结论。
3. 通过后接入当前截图的只读查询入口，补齐 MCP/HTTP、Skill、文档和回归。

## 验收标准

- [x] 真实中文窗口关键文字命中，区域位于当前窗口截图内且可映射到窗口坐标。
- [x] 返回文字、置信度和区域，不返回截图原文之外的推测；失败为空而不是猜测。
- [x] 识别耗时和内存适合作为按需后备路线，不成为正常结构读取的固定成本。
- [x] 接入不提供直接点击，仍须使用当前快照、`plan_check` 和写后验证。
- [x] 全部现有自检和安装版冒烟通过，文档明确当前 macOS、未来 Windows 对应实现。

## 工作树（Worktree）

- 路径：当前仓库
- 分支：master
- Worker owner：coordinator
- Worker handoff commit required：不适用
- Coordinator integration branch：master
- 未使用 worktree 的原因：单协调者、小范围验证，不需要并行写入。

## 长程任务判定

- 是否属于长程任务：否
- 若是，合同文件：`long-running-task-contract.md`
- 连续执行权限：已授权
- Stop Condition 摘要：真实验证不达门槛或需要放宽安全边界时停止接入。

## 审查判定

- 是否需要对抗性审查：否
- 若是，报告文件：`review.md`
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
