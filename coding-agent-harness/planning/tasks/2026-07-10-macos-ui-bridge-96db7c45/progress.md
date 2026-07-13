# 实现 macOS 通用 UI Bridge 第一轮 - 进度

## 状态：审查中

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

### 2026-07-13 - 后台事件与自动启动

- 做了什么：补充后台按键、滚动和窗口相对坐标点击；切前台需要独立许可，坐标强制限制在当前快照窗口；截图改用内容指纹验证实际变化；安装脚本增加登录后自动启动。
- 验证：独立 TextEdit 实例中后台 Tab 和滚动均改变真实画面并返回 confirmed；越界坐标返回错误且未执行；测试实例与临时文件均已清理；安装版两项权限保持 true，登录启动任务处于 running，健康检查、安装版 MCP 自测、Skill 校验和 Harness 检查通过。
- 下一步：重建安装 App，完成坐标安全冒烟和 Finder/企业微信/Electron 代表应用回归。
- 证据：`command:TARGET:Sources/UIBridgeMacCore/ProcessEventExecutor.swift:real key/scroll and coordinate bounds smoke passed`

### 2026-07-13 - 通用应用兼容性读取

- 做了什么：使用安装版 MCP 对 TextEdit、Finder、企业微信和 Electron 应用执行同一套应用发现、窗口发现和实时控件快照流程；补修整数坐标输入兼容。
- 验证：TextEdit 已完成写值、按键、滚动和窗口相对坐标点击并验证；Finder 返回 complete、500 个控件、147 个常用可操作控件；企业微信返回 complete、500/83；Cursor 返回 partial、500/54；飞书返回 partial、500/9。企业微信只读，未搜索联系人或发送消息。
- 下一步：补充 element_find、截图读取和会话停止能力，再做企业微信受控动作路径验证。
- 证据：`command:TARGET:Sources/UIBridgeMCP:four application live compatibility smoke passed`

### 2026-07-13 - 无打扰查询与紧急停止

- 做了什么：MCP/HTTP 增加快照内控件筛选、按句柄读取截图和紧急停止；停止会清空当前快照并拒绝同一会话后续动作；MCP 错误返回稳定代码和具体原因；Skill 规定仅在结构不足时读取截图。
- 验证：纯构建、协议自检、Skill 校验和 MCP 工具契约通过；紧急停止后模拟动作被拒绝并返回明确 stopped 原因。按用户要求未打开、切换或操作任何桌面应用。
- 下一步：补充诊断接口和 HTTP/MCP 契约自测；真实桌面回归等用户空闲时统一执行。
- 证据：`command:TARGET:Sources/UIBridgeMacCore/AutomationRuntime.swift:headless query and emergency stop contract passed`

### 2026-07-13 - 无内容诊断

- 做了什么：MCP/HTTP 增加诊断入口，只返回权限、版本和运行应用数量，不返回窗口标题、控件文本或截图。
- 验证：无界面 MCP 与带鉴权 HTTP 实测均返回两项权限 ready 和正确版本；构建通过，未操作用户桌面。
- 下一步：实现 Streamable HTTP MCP 入口与收口文档；桌面动作回归保持暂停。
- 证据：`command:TARGET:Sources/UIBridgeMCP:headless diagnostics MCP and HTTP smoke passed`

### 2026-07-13 - 权限弹窗误报修复

- 做了什么：移除 App 启动和只读 CLI 查询时的主动弹窗；仅在 Agent 调用权限检查且实时复查仍缺权时显示引导，避免重装后的短暂权限波动造成误报。
- 验证：重建安装后两项权限均为 true，登录启动任务正常，等待后 Bridge 无任何可见窗口，健康检查正常。
- 下一步：继续 Streamable HTTP MCP 与最终收口。
- 证据：`command:TARGET:Sources/macos-ui-bridge/main.swift:authorized startup has no permission dialog`

### 2026-07-13 - 本地地址 MCP

- 做了什么：App 的 `POST /mcp` 增加标准无状态 HTTP MCP，与直接启动方式共享同一工具和运行状态；继续使用本机令牌保护；README 与 Skill 接入说明增加推荐配置和备用方式。
- 验证：HTTP MCP 完成协议初始化、9 工具发现和 diagnostics_get 调用；无令牌访问返回 401；stdio MCP、协议自检、核心真实截图自检、Skill 校验和完整构建通过。
- 下一步：安装最终版本，完成审查、walkthrough 和任务收口。
- 证据：`command:TARGET:Sources/UIBridgeServer/MCPHTTPHandler.swift:authenticated HTTP MCP roundtrip passed`

### 2026-07-13 - 程序坞与菜单栏入口

- 做了什么：App 改为程序坞可见，运行时设置专属蓝色图标；增加菜单栏常驻入口，提供运行状态、权限检查、复制 MCP 配置和退出；登录启动改由系统 App 启动方式执行，并运行正式 macOS 事件循环。
- 验证：debug/release 构建和安装通过；系统识别 bundle、显示名和正常 App 类型，Computer Use 可发现运行中的 macOS UI Bridge，健康接口正常。无主窗口 App 的菜单栏内容无法被 Computer Use 读取，等待用户肉眼确认。
- 下一步：用户确认程序坞和菜单栏显示后重新提交最终审查。
- 证据：`command:TARGET:Sources/macos-ui-bridge/AppShell.swift:installed app identity and event loop passed`

### 2026-07-13 - 菜单栏图标一致性

- 做了什么：菜单栏不再使用系统显示器符号，改为与程序坞共用同一张蓝色 Bridge 图标并做 19pt 适配。
- 验证：debug/release 构建、签名检查、重装和健康检查通过；等待用户肉眼确认最终显示。
- 下一步：用户确认后重新提交最终审查。
- 证据：`command:TARGET:Sources/macos-ui-bridge/AppShell.swift:shared Dock and status icon build passed`

### 2026-07-13 - 菜单栏透明图标

- 做了什么：程序坞保留蓝色完整图标；菜单栏改为同源连接窗口标记的透明单色模板，自动适配浅色/深色背景。
- 验证：debug/release 构建、签名、重装和健康检查通过；等待用户肉眼确认。
- 下一步：用户确认后重新提交最终审查。
- 证据：`command:TARGET:Sources/macos-ui-bridge/AppShell.swift:transparent adaptive status icon build passed`

### 2026-07-13 - 重装权限身份稳定

- 做了什么：开发版签名改用固定程序身份，避免每次代码变化后系统把同一路径、同一名称的 App 当作新程序，导致设置开关仍开启但运行进程实际无权限。
- 验证：构建脚本会检查生成 App 的固定身份；安装前确认旧版正在运行的服务进程实际返回两项权限 false，而同一程序从终端查询会受宿主权限影响返回 true，定位到此前验证方式的盲点。
- 迁移说明：旧签名升级到固定身份时需要重新开关两项授权一次；此后重装应保留权限。
- 下一步：安装新版、重新授权一次，并连续覆盖安装验证权限保持。
- 证据：`command:TARGET:scripts/build-app.sh:stable designated requirement asserted`

### 2026-07-13 - 录屏权限正式申请

- 做了什么：“检查系统权限”会先调用 macOS 的正式授权申请，再复查并显示补充引导；解决只打开设置但 App 未登记、列表里找不到的问题。权限检查不再改变 App 的程序坞显示模式。
- 验证：构建与既有权限分支自检通过；实际系统提示与登记需要用户在安装版菜单中点击一次确认。
- 下一步：用户完成首次授权后，连续覆盖安装验证权限保持。
- 证据：`diff:TARGET:Sources/UIBridgeMacCore/PermissionGuidance.swift:request before settings guidance`

### 2026-07-13 - 本机长期签名身份

- 做了什么：替换仍会随版本失效的临时签名，为开发版自动创建并长期复用一个本机专用身份；构建时临时加入签名搜索范围，结束后恢复用户原有设置。
- 验证：在临时钥匙串原型中连续签名成功，生成的 App 身份由同一证书固定，不再依赖可执行文件内容指纹。
- 下一步：安装长期身份版，用户重新授权一次后连续覆盖安装验证。
- 证据：`command:TARGET:scripts/ensure-local-signing-identity.sh:certificate-backed signing prototype passed`

### 2026-07-13 - 辅助功能提示去重

- 做了什么：辅助功能的系统登记提示改为每个授权周期只出现一次，并持久记录；首次提示后立即结束当前流程，避免再叠加自定义弹窗。后续检查只给出前往设置的引导，不重复触发系统提示。
- 验证：运行中服务已确认录屏权限为 true、辅助功能为 false，与用户截图一致；待安装后验证持久去重分支。
- 下一步：安装并设置本次迁移标记，用户在设置中打开辅助功能开关后继续覆盖安装验证。
- 证据：`diff:TARGET:Sources/UIBridgeMacCore/PermissionGuidance.swift:persistent accessibility prompt guard`

### 2026-07-13 - 权限迁移实机通过

- 做了什么：只清除 macOS UI Bridge 的旧辅助功能授权记录，用户为长期身份版重新开启授权；未改动其他 App 权限，录屏授权保持不变。
- 验证：安装版服务进程实时返回 `accessibilityTrusted=true`、`screenCaptureAllowed=true`，不再以设置页开关外观代替运行结果。
- 下一步：增加 App 启动时自动校验；全授权时静默，缺权时才引导。
- 证据：`command:TARGET:/v1/permissions:installed app reports both permissions true`

### 2026-07-13 - 启动时权限校验

- 做了什么：App 事件循环开始后自动执行与菜单相同的权限校验；已完整授权时直接返回且不显示任何内容，缺权时才进入已去重的系统申请与设置引导。
- 验证：使用当前两项已授权状态完成覆盖安装和重启；安装版服务实时返回两项 true，系统读取 App 窗口为空，未出现权限弹窗；授权提示标记已自动清除。
- 下一步：重新提交最终任务审查。
- 证据：`command:TARGET:Sources/macos-ui-bridge/AppShell.swift:authorized reinstall starts silently with both permissions true`

### 2026-07-13 - 启动校验时机修复

- 发现：用户关闭两项权限并重启后没有提示；安装版实时返回两项 false，且没有产生辅助功能申请标记，证明此前把检查排入主队列并不保证在原生 App 启动阶段执行。
- 做了什么：改由 macOS 的 App 完成启动事件触发权限校验，确保菜单栏和事件循环就绪后执行。
- 验证：使用用户当前两项关闭状态完成覆盖安装；安装版仍实时返回两项 false，同时启动后自动生成辅助功能申请标记，证明缺权启动流程已执行，而修复前同条件没有该标记。系统弹窗外观由用户肉眼确认。
- 下一步：用户确认启动弹窗可见后，恢复授权并继续最终审查。
- 证据：`command:TARGET:Sources/macos-ui-bridge/AppShell.swift:didFinishLaunching creates permission request marker with both permissions off`

### 2026-07-13 - 手动检查成功反馈

- 做了什么：菜单中的手动权限检查在两项权限都正常时显示“系统权限已就绪”；自动启动检查和 Agent 查询继续静默，避免后台打扰。
- 验证：当前安装版实时返回两项权限 true；debug/release 构建、协议自检、覆盖安装均通过。Computer Use 能发现 App，但因其没有主窗口，读取状态超时且按规则不能继续点击，弹窗外观留给用户肉眼确认。
- 下一步：用户点击菜单确认“系统权限已就绪”提示可见。
- 证据：`command:TARGET:Sources/UIBridgeMacCore/PermissionGuidance.swift:authorized branch built and installed; native menu UI requires human confirmation`

### 2026-07-13 - 安装包正式图标

- 发现：系统辅助功能提示仍显示默认网格图标；运行时设置的程序坞图标不会被系统权限界面读取，安装包缺少正式图标资源与声明。
- 做了什么：构建时生成包含全套 macOS 尺寸的 Bridge 图标并写入 App 安装包，配置为系统级 App 图标；图形与程序坞的蓝色连接窗口标记一致。
- 验证：生成的 icns 包含 16 到 1024 像素全套资源；覆盖安装后签名通过，两项权限保持 true；使用系统工作区接口读取安装版图标并渲染检查，结果为蓝底白色连接窗口图标，不再是默认网格。
- 下一步：用户确认系统权限提示中的图标外观。
- 证据：`screenshot:TARGET:/tmp/macos-ui-bridge-system-icon.png:macOS resolved installed bundle icon correctly`

### 2026-07-13 - 正式图标人工验收

- 验证：用户确认系统界面中的新版 App 图标显示正常，可以提交。
- 下一步：继续最终任务审查与剩余功能收口。
- 证据：`human-confirmation:TARGET:/Applications/macOS UI Bridge.app:bundle icon accepted`

### 2026-07-13 - Cursor 与 WorkBuddy 真实接入

- 做了什么：增加保留原配置和私有备份的一键客户端配置脚本；通过 WorkBuddy 4.24.8 自定义连接器界面确认真实配置路径；Cursor 3.6.31 使用安装版直接启动方式，WorkBuddy 使用带令牌的本地地址。
- 修复：本地地址此前复用同一个协议服务状态，WorkBuddy 重连返回“已经初始化”；改为每个请求使用独立协议处理实例，同时共享桌面运行状态。
- 验证：Cursor 日志实时返回 connected，并启动安装版 MCP 进程；本地地址连续两轮初始化和工具列表均成功、每轮返回 9 个工具；WorkBuddy 日志确认 streamable HTTP 连接成功并识别全部 9 个 Bridge 工具，重启后的任务运行环境也包含这些工具。
- 下一步：通过客户端完成一个安全、可验证的完整桌面任务。
- 证据：`command:TARGET:Sources/UIBridgeServer/MCPHTTPHandler.swift:Cursor connected and WorkBuddy reconnect exposes nine tools`

### 2026-07-13 - 通用执行前判断

- 做了什么：增加 `plan_check`，让外部模型在执行动作前用当前快照校验目标、截图依据、前台切换许可和高影响确认；App 本身不内置模型，不额外消耗模型额度。
- 验证：生产版构建、签名、覆盖安装成功；MCP 自测识别 10 个工具；无截图坐标动作被要求先取截图，未确认高影响动作被拦截，Skill 格式检查通过。
- 客户端现状：WorkBuddy 连接器已在线，但其窗口出现画面停留在连接器页、可访问结构已切到新任务页的不一致，未继续反复点击以免干扰桌面；完整客户端动作仍待补测。
- 下一步：用稳定客户端或专用 MCP 测试客户端完成一个 TextEdit 写入与回读闭环，再做最终审查。
- 证据：`command:TARGET:skills/macos-ui-control/scripts/self_test.py:ten tools, plan checked, confirmation protected`

### 2026-07-13 - 可见操控反馈

- 做了什么：目标窗口左上角增加紫色“操作中”胶囊；菜单栏动态列出最近操控的目标应用；动作位置增加 128 点大范围蓝色渐变模拟指针。三者都不接收鼠标事件，不会挡住原应用操作。
- 跨客户端：操控状态使用进程间通知并由权限为 600 的本机状态文件兜底，因此 App 内本地地址和 Cursor 直接启动的进程都能驱动同一套反馈；状态不包含界面正文。
- 修复：macOS App 主事件循环会阻塞主派发队列，普通定时任务不执行；改为在 App 完成启动后注册主事件循环计时，提示和指针可稳定出现并自动消失。
- 验证：真实 MCP 只读快照在飞书窗口左上角显示“操作中”；动作预览显示大范围渐变指针；2.4 秒后两者均从截图消失。菜单内容按当前活动目标动态构建；系统菜单栏无法由当前 Computer Use 窗口接口自动点击，仍需自然使用时肉眼确认。
- 下一步：用户在一次真实 Cursor/WorkBuddy 操作中确认菜单列表外观，再完成最终收口。
- 证据：`screenshot:TARGET:/tmp/macos-ui-bridge-visible.png:badge and gradient cursor visible; /tmp/macos-ui-bridge-hidden.png:both overlays dismissed`

### 2026-07-13 - 后台提示与窗口范围修复

- 用户反馈：WorkBuddy 读取访达时没有看到访达页面，当前屏幕却凭空出现“操作中”；任务完成后菜单没有“正在操控 访达”。结果中的搜索控件坐标也超出所选窗口。
- 根因：提示面板跨桌面显示且未判断目标是否最前；菜单记录只保留 15 秒；快照从应用根节点读取，混入同一进程其他窗口；辅助功能的屏幕坐标被误当成窗口内坐标。
- 做了什么：后台目标只写入菜单、不再显示悬浮提示；菜单保留改为 90 秒；快照先匹配指定 `AXWindow` 并只遍历该窗口；控件坐标统一转换为窗口内坐标。
- 验证：WorkBuddy 目标窗口快照返回 9 个窗口内元素，越界数量为 0；前台 pid 为 Cursor、目标 pid 为访达时注入真实窗口状态，当前屏幕截图没有出现紫色提示；访达当前没有普通窗口，服务不再把桌面和菜单小窗当作可操作页面。
- 下一步：用户打开一个普通访达窗口，用 WorkBuddy 重跑只读提示，确认菜单在 90 秒内显示“正在操控 访达”。
- 证据：`command:TARGET:/v1/snapshots:window-scoped WorkBuddy snapshot outOfBoundsCount=0; screenshot:TARGET:/tmp/macos-ui-bridge-hidden-finder.png:no overlay for background Finder`

### 2026-07-13 - 菜单操控记录可恢复

- 用户反馈：WorkBuddy 任务完成后，90 秒内打开菜单仍未看到“正在操控 访达”。
- 根因：菜单记录虽然计划保留 90 秒，但接收端与短时悬浮提示共用了 3 秒新鲜度门槛；App 短暂忙碌或重启后会丢弃本应继续展示的菜单记录。
- 做了什么：拆分短时视觉提示和菜单记录的有效期；悬浮提示仍只响应 3 秒内的新事件，菜单记录改为按事件原始时间保留 90 秒，并能从本机状态记录恢复。
- 验证：安装版在后台读取访达桌面窗口后写入“访达”记录，未在当前前台应用显示悬浮提示；记录超过 3 秒后重启 App，服务恢复正常且 90 秒记录仍可读取。debug/release 构建和协议自检通过。
- 限制：当前 Computer Use 无法读取或点击无主窗口 App 的状态栏菜单；菜单外观仍需用户自然打开时确认，不再继续反复尝试该受限路线。
- 下一步：用户在一次 WorkBuddy 读取结束后的 90 秒内打开 Bridge 菜单，确认显示“正在操控 访达”。
- 证据：`command:TARGET:Sources/macos-ui-bridge/ControlOverlayController.swift:delayed activity survives app restart and health remains ok`

### 2026-07-13 - 菜单收到事件后主动刷新

- 用户复测：WorkBuddy 在 5 秒内完成访达只读任务，状态记录正确写入“访达”，但打开菜单仍没有目标项，排除任务过慢和记录过期。
- 根因：已恢复的目标只存在于控制器中，状态栏菜单仍依赖系统在打开菜单时回调刷新；该回调在实际状态栏入口没有可靠执行，导致菜单继续显示启动时的旧内容。
- 做了什么：控制器收到新目标后立即通知 App 重建现有菜单，不再依赖点击时刷新；每个目标同时注册 90 秒到期刷新，避免菜单项无限残留。
- 验证：安装版后台读取访达后，通过 macOS 辅助功能接口直接读取当前 Bridge 状态栏菜单，明确包含“正在操控”和“正在操控 访达”；协议自检、debug/release 构建、覆盖安装和健康检查通过。临时检查脚本已删除。
- 下一步：用户自然打开菜单确认最终外观；若仍不可见，需核对用户点击的是否为 Bridge 的重叠窗口图标。
- 证据：`command:TARGET:/Applications/macOS UI Bridge.app:AXExtrasMenuBar contains active Finder target after snapshot`

### 2026-07-13 - 状态栏直接展示目标应用

- 用户确认菜单记录可见，并要求移除调试常驻，改成类似 Codex Computer Use 的状态栏应用图标堆叠，不打开菜单也能看到。
- 做了什么：恢复 90 秒自动结束；活动期间把普通 Bridge 图标替换为蓝色胶囊，最多叠放 3 个目标应用图标并显示白色鼠标箭头；菜单继续保留文字详情。补充同进程事件通知和状态栏轮询，兼容 WorkBuddy 本地地址与 Cursor 独立进程。
- 关键修复：安装脚本此前只在 App 包不存在时才构建，导致多轮覆盖安装实际一直复制旧程序；现改为每次安装都先构建、签名最新版本。
- 验证：真实后台访达快照后，状态栏截图明确显示访达图标蓝色胶囊；176 秒后截图恢复普通 Bridge 图标。debug/release 构建、覆盖安装、签名、协议自检和健康检查通过；临时运行记录代码已删除。
- 证据：`screenshot:TARGET:/tmp/macos-ui-bridge-status-active-final2.png:Finder icon pill visible; screenshot:TARGET:/tmp/macos-ui-bridge-status-expired-final.png:idle Bridge icon restored`

### 2026-07-13 - 产品改名为 App MCP Bridge

- 做了什么：面向用户的 App、菜单、权限提示、安装路径和文档统一改名为 `App MCP Bridge`，为后续 Windows 实现保留平台无关的产品名；macOS 程序身份和现有 MCP 连接名保持兼容。
- 迁移：新版安装到 `/Applications/App MCP Bridge.app`，安装成功后移除旧路径；Cursor 的程序路径已迁移，WorkBuddy 的本地地址保持不变。
- 验证：debug/release 构建、协议自检、正式签名、覆盖安装和 10 工具 MCP 自测通过；系统运行信息显示 `App MCP Bridge`，旧 App 路径已移除，两项系统权限均保持 true。
- 证据：`command:TARGET:/Applications/App MCP Bridge.app:installed display name, permissions, health and MCP self-test passed`

## 残余

- 完整 Xcode 未安装，标准 Xcode 测试目标与正式签名/公证暂不可执行；Swift 自检与真实应用回归可继续。
- 企业微信目前只完成只读结构回归，尚未执行涉及联系人或消息的动作。

## 交接

- 当前 Owner：coordinator。
- 恢复命令：`git status --short && git log --oneline -8`。
- 下一文件：本目录 `task_plan.md` 的阶段 1。

### [2026-07-10 08:58] - task-start

- 做了什么：Harness 已配置并验证，开始 Swift 通用核心实现
- 验证结果：已记录
- 下一步：继续执行
- 证据：n/a

### [2026-07-13 03:20] - task-review

- 做了什么：first-round ready
- 验证结果：已记录
- 下一步：继续执行
- 证据：n/a
