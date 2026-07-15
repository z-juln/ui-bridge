# 实现通用 Skill 安装教学入口

## Task ID

`2026-07-15-skill-764f4058`

## 创建日期

2026-07-15

## 一句话结果

UI Bridge 把现有通用 Skill 随 App 打包，并提供一个不绑定客户端的安装教学按钮。

## 完成后能得到什么

用户在“连接”页点击“安装 Agent Skill”后，可以看到明确步骤并复制一段安装提示词，
再把提示词交给当前 Agent。Agent 从 App 内稳定的只读目录安装 Skill。首版不绑定
Cursor、WorkBuddy 等客户端，不扫描或猜测安装状态，也不通过 MCP 静默安装。

## 交付物

- 可见产物：连接页教学卡片和安装说明弹窗。
- 修改位置：`Sources/ui-bridge/SettingsRootView.swift`、`scripts/build-app.sh`、`docs/`。
- 验证证据：构建后的 App 包含完整 Skill，安装版弹窗和复制提示词实际可用。

## 第一眼应该看什么

先读 `task_plan.md`，再看连接页、构建脚本和 `skills/ui-bridge-control/`。

## 边界

- 范围内：Skill 随 App 打包、教学弹窗、复制提示词、对应文档和验收。
- 范围外：自动识别客户端、自动安装、安装状态检测、Web Skill、经验库。
- 停止条件：必须写入未知 Agent 私有目录或必须通过 MCP 安装时暂停。

## 完成判断

- 构建后的 App 内存在完整可读的 Skill 目录。
- 连接页能打开教学弹窗并复制包含真实源路径的提示词。
- 提示词不包含令牌，不绑定客户端，不要求子进程启动 App。
- 安装版交互和现有构建、自检均通过。

## 执行合同

- Owner：coordinator
- 生命周期状态：已完成
- 必需文件：`INDEX.md`、`brief.md`、`task_plan.md`、`visual_map.md`、`progress.md`、`walkthrough.md`
- 完成条件：验证证据必须记录到 `progress.md`

## 当前下一步

本任务已完成；后续随 Web 和经验库能力逐步扩展 Skill 内容。
