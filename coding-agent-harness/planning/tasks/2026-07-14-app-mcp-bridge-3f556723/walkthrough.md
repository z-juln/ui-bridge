# 收口记录：统一 App MCP Bridge 内部名称

## 摘要

应用内部程序、系统身份、本地状态、启动项、Cursor/WorkBuddy 连接和当前文档已统一为 App MCP Bridge。旧状态已迁移，旧启动项已清理。

## 范围

| 范围 | 详情 |
| --- | --- |
| 变更模块 | Swift 可执行目标、App 包、运行状态、安装、客户端配置、Skill 和文档 |
| 新增文件 | `Sources/app-mcp-bridge/`（由旧源码目录迁移） |
| 删除文件 | 旧源码目录、旧启动项和本机旧状态目录 |
| 不在范围内 | 历史任务编号、历史证据路径、Git 历史、Windows 实现 |

## 验证

| 检查 | 命令或过程 | 结果 | 证据 |
| --- | --- | --- | --- |
| 构建 | `swift build` | 通过 | 新目标成功链接 |
| 核心自检 | 两项 Swift 自检 | 通过 | protocol 4 checks；core 读取与截图通过 |
| 真实安装 | `scripts/install-app.sh` | 通过 | 新程序、新系统标识、签名和启动正常 |
| 服务 | 健康检查与错误路径 | 通过 | health=ok，错误提示只显示新名称 |
| MCP | Skill 自检 | 通过 | 工具发现、快照、方案和保护动作通过 |
| 客户端 | 配置 Cursor 与 WorkBuddy 后读取配置 | 通过 | 两端仅保留 `app-mcp-bridge` |
| 工程治理 | Harness check | 通过 | target-project passed |

## 审查结论

| 来源 | 重要发现 | 处理 | 证据 |
| --- | --- | --- | --- |
| self review | 0 | 无需修复 | `review.md` |

## 残余风险

| 风险 | Owner | 是否接受 | 跟进 |
| --- | --- | --- | --- |
| 无 | coordinator | yes | 无 |

## 经验沉淀反思

| 问题 | 答案 |
| --- | --- |
| 是否完成经验候选检查？ | 是；没有需要单独沉淀的候选 |
| 经验候选详情文件 | `lesson_candidates.md` |

## 收口链接

| 产物 | 链接 |
| --- | --- |
| 任务计划 | `task_plan.md` |
| 审查记录 | `review.md` |
| 进度记录 | `progress.md` |

Closeout Status: closed
