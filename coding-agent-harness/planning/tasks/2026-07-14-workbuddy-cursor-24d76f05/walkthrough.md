# 收口记录：实现 WorkBuddy Cursor 真实写入闭环

## 摘要

Cursor 与 WorkBuddy 都已通过真实客户端对各自独立的 TextEdit 文稿完成写入和最新快照回读。

## 隔离约束

- 每个客户端使用独立的新建 TextEdit 文稿。
- 文稿保持未保存，不包含用户已有内容。
- 每个客户端使用不同的唯一标记，避免把旧结果误判为当前结果。
- 写入目标只能来自当前窗口的新快照。

## Cursor 证据

- 测试标记：`UI_BRIDGE_CURSOR_20260714_1030`
- 客户端实际调用：`apps_list`、`windows_list`、`snapshot_get`、`element_find`、`plan_check`、`action_run`，之后对动作返回的新快照再次调用 `element_find`。
- `plan_check`：`ready`。
- `action_run`：`confirmed`，返回新的快照标识。
- 客户端回读：新快照文本与测试标记完全一致。
- 独立核对：从 TextEdit 当前界面再次读取，值仍与测试标记完全一致。
- 清理状态：文稿未保存、未关闭，未触碰其他文稿。

## WorkBuddy 证据

- 测试标记：`UI_BRIDGE_WB_20260714_1055`
- 客户端实际调用：已安装 App 的安全 `call` 入口；依次执行 `apps_list`、`windows_list`、`snapshot_get`、`element_find`、`plan_check`、`action_run`，之后对动作返回的新快照再次执行 `element_find`。
- `plan_check`：`ready`。
- `action_run`：`confirmed`，返回新快照 `6C4B19D6-576A-487E-8117-E3B66DB28E95`。
- 客户端回读：新快照中的输入区值与测试标记完全一致。
- 独立核对：从 TextEdit “未命名3”直接读取，值仍与测试标记完全一致。
- 清理状态：WorkBuddy 自行生成的一条测试记忆已删除；文稿未保存并保留给用户核对。

## 范围

| 范围 | 详情 |
| --- | --- |
| 变更模块 | 本地调用入口、HTTP 接收、方案检查接口、命令错误处理、接入与验收文档 |
| 新增文件 | `Sources/ui-bridge/LocalBridgeClient.swift` |
| 删除文件 | 无；WorkBuddy 测试生成的未跟踪记忆文件已清理 |
| 不在范围内 | Windows、第三方消息发送、公开签名、公证、用户文稿 |

## 验证

| 检查 | 命令或过程 | 结果 | 证据 |
| --- | --- | --- | --- |
| 构建 | `swift build` | 通过 | 所有目标完成编译 |
| 协议自检 | `swift run protocol-self-test` | 通过 | 4 checks passed |
| 核心自检 | `swift run core-self-test` | 通过 | TextEdit 代表窗口读取、范围和截图通过 |
| Skill 自检 | `python3 skills/macos-ui-control/scripts/self_test.py` | 通过 | 10 个工具、快照、方案和确认保护通过 |
| 安装冒烟 | `./scripts/install-app.sh`、状态、诊断、健康检查 | 通过 | App 已签名安装，权限可用，服务可访问 |
| 错误路径 | `call unsupported` | 通过 | 退出码 1，错误清楚，无新增崩溃报告 |
| 真实客户端 | Cursor、WorkBuddy 各一次隔离写入 | 通过 | 两端均检查、写入、新快照回读、独立界面核对一致 |

## 审查结论

| 来源 | 重要发现 | 处理 | 证据 |
| --- | --- | --- | --- |
| self | 分段请求、令牌泄漏、错误弹窗、写后假阳性 | 已修复并重跑，无开放 P0/P1/P2 | `review.md` |

## 残余风险

| 风险 | Owner | 是否接受 | 跟进 |
| --- | --- | --- | --- |
| WorkBuddy 可能自行写记忆 | coordinator | 接受 | 每次测试后检查工作树并清理测试产物 |
| 三个测试文稿仍打开 | user | 接受 | 核对后关闭且不保存 |

## 经验沉淀反思

| 问题 | 答案 |
| --- | --- |
| 是否完成经验候选检查？ | 是；关键经验已直接写入接入与验收文档，不另建治理候选 |
| 经验候选详情文件 | `lesson_candidates.md` |

## 收口链接

| 产物 | 链接 |
| --- | --- |
| 任务计划 | `task_plan.md` |
| 审查记录 | `review.md` |
| 进度记录 | `progress.md` |

Closeout Status: closed
