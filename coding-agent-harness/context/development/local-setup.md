# 本地开发

Context Doc Type: local-setup
Owner: project coordinator
Source Evidence: TARGET:docs/03-delivery-and-validation.md
Last Verified: 2026-07-10
Confidence: medium

## 要求

- macOS 14.4+。
- Xcode 与 Swift 6 工具链。
- Node/npm 仅用于 Coding Agent Harness。

## 稳定命令

```bash
swift build
swift run protocol-self-test
swift run core-self-test
swift run ui-bridge start
swift run ui-bridge status
swift run ui-bridge stop
npx --yes coding-agent-harness check --profile target-project .
npx --yes coding-agent-harness status --json .
```

当前机器只有 Command Line Tools，没有完整 Xcode，因此基础测试使用仓库自带的
`protocol-self-test`。完整 Xcode 环境建立后再增加 XCTest/Swift Testing 目标。

系统权限只授予构建出的稳定 App Bundle；不要让不同临时二进制反复触发授权。
