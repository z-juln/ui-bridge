# 收口记录：验证并接入本机视觉文字定位

## 摘要

Apple Vision 已在真实中文 macOS 窗口中通过文字、区域、坐标和延迟验证，并作为
`visual_text_find` 只读后备入口接入 UI Bridge。正常完整结构仍优先使用无障碍树；
macOS 底层可由未来 Windows 对应实现替换，不改变 Agent 调用方式。

## 范围

| 范围 | 详情 |
| --- | --- |
| 变更模块 | 通用结果、Apple Vision、快照运行时、MCP/HTTP、本地调用、Skill 和文档 |
| 新增文件 | `VisualText.swift`、`AppleVisionTextRecognizer.swift`、`visual-text-self-test` |
| 删除文件 | 无 |
| 不在范围内 | 无文字图标、Canvas 语义、本地大模型和 Windows 实现 |

## 验证

| 检查 | 命令或过程 | 结果 | 证据 |
| --- | --- | --- | --- |
| 真实中文窗口 | 后台打开 UI Bridge 连接页，连续识别“连接”和“Agent Skill” | 23 个区域、两项命中、与无障碍区域重合、热运行约 187-214ms | `progress.md` |
| 安装版完整链路 | 隔离中文夹具 → 快照 → `visual_text_find` 两次 | 首次 377ms、置信度 1、第二次缓存命中 | `progress.md` |
| 安全 | `swift run safety-self-test` | 8 项通过，安全输入区域被排除 | `progress.md` |
| 回归 | 构建、协议、核心、MCP Skill、安装和 Harness | 全部通过 | `progress.md` |

## 审查结论

| 来源 | 重要发现 | 处理 | 证据 |
| --- | --- | --- | --- |
| coordinator 自检 | 0 | 无阻塞项 | `progress.md` |

## 残余风险

| 风险 | Owner | 是否接受 | 跟进 |
| --- | --- | --- | --- |
| 无文字图标仍不能由本能力理解 | project | 是 | 后续单独评估本地小型视觉模型 |
| Windows 尚无识别实现 | project | 是 | Windows 版本使用相同上层契约接入系统能力 |

## 经验沉淀反思

| 问题 | 答案 |
| --- | --- |
| 是否完成经验候选检查？ | 简单任务无独立候选；平台识别必须隐藏在通用契约后的结论已写入架构文档 |
| 经验候选详情文件 | 不适用 |

## 收口链接

| 产物 | 链接 |
| --- | --- |
| 任务计划 | `task_plan.md` |
| 审查记录 | 简单任务不要求独立审查文件 |
| 进度记录 | `progress.md` |
