# 实现 macOS 通用 UI Bridge 第一轮

Task Contract: harness-task/v1
Task Package Index: required

## 目标

完成可运行、可接入、可跨 Agent 继续开发的 macOS 通用 UI Bridge 第一轮。

## 范围

- 做：通用核心、无界面端口服务、HTTP、MCP、Skill、测试与真实应用回归。
- 不做：Windows、产品 UI、正式发布、云视觉、应用专属固定流程。
- 风险：辅助功能树因应用而异；后台事件可能被丢弃；系统权限依赖稳定 App 身份。

## 目标对齐

| 问题 | 回答 / 证据 |
| --- | --- |
| 原始目标 | 做通用 macOS App，第一轮包含核心功能、端口、MCP 和 Skill，并可持续交接。 |
| 当前任务是否直接推进 | 是；交付物就是用户要求的第一轮可用产品。 |
| 最容易误用的替代 | 只做企业微信脚本、只写文档、只做协议空壳。 |
| 不能提前声称 | 未经真实构建、MCP/Skill 接入和四类应用回归，不得称为通用可用。 |

## 阶段与提交点

1. Harness 与交接规范：检查通过并提交。
2. Swift 基础与协议模型：构建、单测通过并提交。
3. 通用发现与控件树：测试和本机只读冒烟通过并提交。
4. 截图、坐标、动作与验证：单测和测试 App 通过并提交。
5. HTTP 服务与管理命令：端口冒烟通过并提交。
6. MCP：工具列表与端到端调用通过并提交。
7. Skill 和客户端：格式检查、Cursor/WorkBuddy 入口验证并提交。
8. 四类应用回归、审查和收口：证据、walkthrough 和残余完整并提交。
9. 客户端与智能规划增强：Cursor/WorkBuddy 真实接入、安全完整任务、截图判断与步骤规划入口通过并提交。
10. 可见操控反馈：目标窗口提示、菜单栏目标列表和渐变模拟指针完成实机视觉验收并提交。

## 验收标准

- [x] 无界面服务可启动、停止、报告状态和权限。
- [x] 任意应用/窗口发现、控件树、截图、快照和结构质量可用。
- [x] 点击、选择、写值、输入、按键、滚动和验证有统一接口。
- [x] 后台失败与前台需求可解释，旧快照不会误操作。
- [x] HTTP 和 MCP 覆盖同一核心能力。
- [x] 通用 Skill 可安装、可触发、无应用专属流程。
- [x] TextEdit、Finder、企业微信、Electron 回归证据完成。
- [x] 所有已完成切片有提交和进度记录。

## 工作树

- 路径：当前 checkout。
- 分支：`main`。
- Owner：coordinator。
- 未使用 worktree：当前单 Agent 串行开发，用户要求通过提交接力而非并行 worker。

## 长程任务

- 是。
- 合同：`long-running-task-contract.md`。
- 连续执行权限：已授权。
- Stop Condition：第一轮验收完成，或触发合同中的暂停条件。

## 审查

- 自审必须执行；本轮未授权可写子代理。
- 任务收口前填写 `review.md`，不得有 open P0/P1。

## 关联

- Regression：`TARGET:coding-agent-harness/governance/regression/Regression-SSoT.md`
- 架构：`TARGET:docs/01-product-and-architecture.md`
- 协议：`TARGET:docs/02-protocol-and-integrations.md`
- 验收：`TARGET:docs/03-delivery-and-validation.md`
