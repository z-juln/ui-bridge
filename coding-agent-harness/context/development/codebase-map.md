# Codebase Map

Context Doc Type: codebase-map
Owner: project coordinator
Source Evidence: TARGET:docs/01-product-and-architecture.md
Last Verified: 2026-07-10
Confidence: medium

| 路径 | 职责 |
| --- | --- |
| `Sources/UIBridgeProtocol` | 通用模型、JSON 契约和错误 |
| `Sources/UIBridgeMacCore` | macOS 应用、窗口、控件、截图和动作 |
| `Sources/UIBridgeServer` | HTTP、鉴权、会话、队列 |
| `Sources/UIBridgeMCP` | MCP 工具适配 |
| `Sources/ui-bridge` | CLI 和服务启动入口 |
| `Tests/` | 单元、契约和集成测试 |
| `skills/ui-bridge-control` | 通用 Agent Skill（当前实现 macOS，预留 Windows） |
| `docs/` | 产品和协议设计 |
| `coding-agent-harness/` | 任务、交接和回归事实 |

目录尚未创建的部分是计划结构，创建后必须保持职责单向依赖。
