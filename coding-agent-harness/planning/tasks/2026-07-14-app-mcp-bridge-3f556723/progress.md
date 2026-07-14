# 统一 App MCP Bridge 内部名称 - 进度

## 状态：计划中

## 进度记录

### 2026-07-14 11:50 - 任务规划

- 做了什么：确认旧名称仍来自内部可执行程序、包目标、签名标识、本地目录和启动项；确定完整迁移范围。
- 验证结果：当前 App 展示名已正确，但包内程序仍为旧名称，因此 macOS 崩溃报告显示旧名。
- 下一步：完成代码、App 包、本地状态和客户端配置迁移。
- 证据：command:TARGET:Resources/App-Info.plist:CFBundleExecutable 和 CFBundleIdentifier 仍使用旧值

## 残余

- 新内部标识安装后需重新授予 macOS 权限。
