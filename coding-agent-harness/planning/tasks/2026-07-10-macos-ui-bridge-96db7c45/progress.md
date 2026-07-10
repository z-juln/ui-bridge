# 实现 macOS 通用 UI Bridge 第一轮 - 进度

## 状态：进行中

## 当前阶段

- 阶段：MCP 与 Agent 接入。
- 最近完成：快照与已验证动作已开放到 MCP/HTTP，并通过临时 TextEdit 真实写入回归。
- 下一步：更新已安装 App，补齐其余动作类型与代表应用回归。

## 进度记录

### 2026-07-10 - 设计文档

- 做了什么：完成三份第一轮通用设计文档。
- 验证：章节、代码围栏和范围冲突检查通过。
- 提交：`92fa692`。
- 证据：`diff:TARGET:docs/:第一轮产品、协议和验收设计`

### 2026-07-10 - 任务登记

- 做了什么：安装中文 core + long-running-task Harness，创建 complex 长任务包。
- 验证：任务 CLI 成功生成任务 ID。
- 提交：`0b34c93`（Harness CLI 自动提交）。
- 证据：`command:TARGET:coding-agent-harness/:任务包已登记`

### 2026-07-10 - Harness 项目化配置

- 做了什么：定制 AGENTS/CLAUDE 入口、架构上下文、回归面、长任务合同、阶段图和交接规则。
- 验证：`npx --yes coding-agent-harness check --profile target-project .` 通过；仅剩预期的未提交文件警告。
- 下一步：提交本切片并开始 Swift 协议核心。
- 证据：`command:TARGET:coding-agent-harness/:target-project check passed`

### 2026-07-10 - CORE-01 Swift 与协议

- 做了什么：建立 Swift 6 包；实现应用、窗口、元素、快照、动作、验证和错误模型；增加 CLI 版本/状态入口与三项 JSON 自检。
- 验证：`swift build` 通过；`swift run protocol-self-test` 输出 3 checks passed；CLI `version`/`status` 可运行。
- 环境发现：当前只有 Command Line Tools，缺少完整 Xcode 测试模块；改用无外部依赖的项目自检程序，完整 Xcode 阶段再补标准测试目标。
- 下一步：实现 `UIBridgeMacCore` 的应用、窗口和 AX 读取。
- 证据：`command:TARGET:Package.swift:build and protocol self-test passed`

### 2026-07-10 - CORE-02 发现与控件树

- 做了什么：实现通用运行应用发现、Core Graphics 窗口发现、辅助功能权限检查，以及递归读取 children/rows/visible rows/contents 等关系的 AX 树读取器。
- 验证：`swift build`、协议自检和核心自检通过；本机发现 72 个应用、215 个窗口，并从当前前台应用读取 100 个连续编号控件节点，结构质量正确标记为 partial。
- 下一步：实现目标窗口截图、动作执行和验证。
- 证据：`command:TARGET:Sources/UIBridgeMacCore:live app/window/AX smoke passed`

### 2026-07-10 - CORE-03 截图、动作与验证

- 做了什么：实现 ScreenCaptureKit 单窗口截图、快照控件注册表、后台辅助功能动作执行器和独立验证引擎；前台动作只返回显式升级要求。
- 验证：构建和两组自检通过；本机发现 74 个应用、234 个窗口，读取 100 个控件节点，并真实捕获 4,557,670 字节 PNG；验证引擎正确观察预期元素。
- 下一步：实现回环 HTTP 服务与 CLI 管理入口。
- 证据：`command:TARGET:Sources/UIBridgeMacCore:window capture and verification smoke passed`

### 2026-07-10 - SRV-01 HTTP 与 CLI

- 做了什么：实现仅回环监听的 HTTP 服务、持久随机令牌、健康/权限/应用/窗口接口，以及 start/stop/status/serve/token/permissions/version 命令。
- 验证：后台启动后 `/health` 返回 ok；无令牌访问应用接口返回 401；正确令牌返回 72 个应用和权限状态；start/status/stop 生命周期全部通过。
- 下一步：添加 MCP stdio 与 Streamable HTTP 映射。
- 证据：`command:TARGET:Sources/UIBridgeServer:HTTP auth and daemon lifecycle smoke passed`

### 2026-07-10 - MCP-01 stdio 接入

- 做了什么：接入官方 MCP Swift SDK，增加 `mcp` 命令，并提供权限、运行应用、指定进程窗口三个通用工具。
- 验证：完整构建、协议自检、核心真实截图自检通过；真实 stdio 客户端完成初始化、工具列表和工具调用，识别 3 个工具并返回 70 个当前应用。
- 下一步：制作仓库内通用 Skill、Cursor/WorkBuddy 配置示例和一键自测脚本。
- 证据：`command:TARGET:Sources/UIBridgeMCP:real stdio initialize/list/call smoke passed`

### 2026-07-10 - SKILL-01 通用 Skill 与客户端接入

- 做了什么：创建与具体应用无关的 macOS UI Skill，加入安全操作流程、Cursor/WorkBuddy stdio 配置、权限排错说明和一键只读自测；同步更新项目使用说明。
- 验证：Skill 官方校验通过；自测真实启动 MCP、完成初始化/工具发现/应用调用，识别 3 个工具和 70 个当前应用；完整构建通过。
- 下一步：开放快照和动作 MCP/HTTP 接口，再使用代表应用做端到端回归。
- 证据：`command:TARGET:skills/macos-ui-control:validator and real MCP self-test passed`

### 2026-07-10 - 权限阻塞原生引导

- 做了什么：权限检查现在同时识别辅助功能和屏幕录制；缺失时由服务弹出原生提示，可直接前往对应系统设置，并在单次运行内抑制重复提醒；Skill 改为优先依赖此流程。
- 验证：完整构建、协议自检、核心真实截图自检、Skill 校验、真实 MCP 自测和 Harness 检查通过；缺失权限组合与全授权分支均有自动断言。
- 未覆盖：当前执行环境两项权限均已授权，未强行撤销用户权限验证实际弹窗外观；首次未授权状态需人工确认一次。
- 下一步：开放快照和动作 MCP/HTTP 接口，再使用代表应用做端到端回归。
- 证据：`command:TARGET:Sources/UIBridgeMacCore/PermissionGuidance.swift:permission decision and full regression passed`

### 2026-07-10 - 最小可安装 macOS App

- 做了什么：增加固定名称与标识的无界面 App 包装、正式构建和安装脚本；App 独立启动本地服务并以自身身份申请辅助功能与屏幕录制权限；客户端配置改为调用已安装 App 内的程序。
- 验证：生产构建、配置文件和系统签名检查通过；App 已安装到 `/Applications`，系统识别固定标识；用户确认它已出现在辅助功能列表并启用；重新打开后进程保持运行且健康接口返回 ok；App 自检读取到两项权限均为 true。
- 下一步：开放快照和动作 MCP/HTTP 接口，再使用代表应用做端到端回归。
- 证据：`command:TARGET:scripts/build-app.sh:installed app launch, permissions and health passed`

### 2026-07-10 - 快照与已验证动作接口

- 做了什么：增加会过期的实时快照、截图内存保管、控件句柄注册、动作后重新读取验证、高影响动作确认拦截；MCP 增加 snapshot_get/action_run，HTTP 增加 snapshots/actions；密码控件不再返回值，Skill 改用完整读写流程。
- 验证：MCP 和 HTTP 均从真实窗口读取 100 个控件；独立临时 TextEdit 通过 set_value 写入并重新读取，返回 confirmed，测试进程和临时文件已清理；未确认的高影响动作返回 confirmation_required 且未执行；完整构建、两组核心自检和 Skill 校验通过。
- 下一步：重建安装 App，补齐按键、滚动、坐标后备与四类代表应用回归。
- 证据：`command:TARGET:Sources/UIBridgeMacCore/AutomationRuntime.swift:real MCP/HTTP snapshot and verified TextEdit action passed`

## 残余

- 完整 Xcode 未安装，App Bundle/系统权限测试暂不可执行；纯 Swift 核心可继续。
- 系统权限和真实应用验证尚未开始。

## 交接

- 当前 Owner：coordinator。
- 恢复命令：`git status --short && git log --oneline -8`。
- 下一文件：本目录 `task_plan.md` 的阶段 1。

### [2026-07-10 08:58] - task-start

- 做了什么：Harness 已配置并验证，开始 Swift 通用核心实现
- 验证结果：已记录
- 下一步：继续执行
- 证据：n/a
