# 实现完整设置与实时调试界面 - 进度

## 状态：进行中

## 进度记录

### 2026-07-14 13:30 - 原型确认与任务登记

- 做了什么：把用户确认的完整设置、所有活动应用实时画面和危险动作二次确认整理为独立长任务。
- 验证结果：核对现有 App 菜单、活动提示、窗口截图和动作安全链路，确认可以分片复用。
- 下一步：实现设置窗口外壳和真实状态总览。
- 证据：`diff:TARGET:coding-agent-harness/planning/tasks/2026-07-14-item-65db687f/:approved scope recorded`

### 2026-07-14 14:05 - 设置窗口与实时画面骨架

- 做了什么：增加原生设置窗口、七个栏目、菜单栏与程序坞打开入口；接入真实服务、权限、活动记录；实时页支持多应用缩略图、大画面、指针标记、事件和停止入口，截图只在页面可见时保存在内存。
- 验证结果：Debug/Release 构建和安装通过；安装版窗口 1080×720 可见，辅助功能树完整读取 62 个元素；真实截图确认总览布局正常，七个栏目均存在；实时页活动出现后进入画面加载路径。
- 下一步：完成实时刷新稳定性检查，再接入应用访问规则和危险动作二次确认。
- 证据：`screenshot:TARGET:/tmp/ui-bridge-settings.png:installed native settings overview rendered correctly`
- 证据：`command:TARGET:Sources/ui-bridge/:swift build and installed window AX snapshot passed`

### 2026-07-14 14:30 - 统一会话与低负载实时画面服务

- 做了什么：删除设置页定时截图和重复启动的截图进程；新增唯一操控会话中心，由它统一管理活动目标、实时画面、错误和退出清理。实时画面改为持续连接，限制为每个窗口每秒 1 张、最大 720 像素宽、只保留内存最新画面。
- 验证结果：Debug 构建通过；持续画面命令运行 2.2 秒输出 2 张有效 JPEG、总计 70,673 字节，结束后无残留进程；协议 4 项和安全 6 项自检通过；旧截图轮询代码搜索为空。
- 下一步：仅在用户电脑空闲时做一次安装版低负载界面验收，确认实时页显示画面且离开页面后内部画面进程退出。
- 证据：command:TARGET:.build/debug/ui-bridge preview-stream 102:frames=2 total_bytes=70673 max_frame=35352
- 证据：command:TARGET:swift build && swift run protocol-self-test && swift run safety-self-test:passed

### 2026-07-14 15:00 - 安装版回传阻塞定位

- 做了什么：安装版以每秒 1 张画面的参数做了一次短时验收；内部画面进程能启动和退出，但界面仍停在等待画面。确认画面回传沿用了会被原生事件循环压住的主界面任务队列，已改为直接投递到主事件队列。
- 验证结果：修复后 Debug 构建通过；测试退出后无内部画面进程残留。按用户要求停止重复界面尝试，本切片尚未再次打开实时页。
- 下一步：下次只做一次短时安装版验收；若仍不显示，停止实现并请求人工协助，不再更换路线。
- 证据：command:TARGET:swift build:passed

### 2026-07-14 15:20 - 安装版单次复验仍阻塞

- 做了什么：按低负载约束安装最新版本，只读飞书的一个可见窗口并打开实时页约 3 秒。
- 验证结果：目标和活动记录正常出现，但页面仍停在“正在连接 1 个窗口”，没有收到画面；退出实时页后内部画面进程已全部清理，工作区无临时文件。
- 下一步：停止继续更换实现路线。需要先增加不依赖界面的内部状态证据，或由用户协助确认系统活动监视器中的进程状态后再继续。
- 证据：ui:TARGET:UI Bridge 实时操控页:目标存在但画面未连接
- 证据：command:TARGET:pgrep preview-stream:退出页面后无残留

### 2026-07-14 15:25 - 实时画面安装版验收通过

- 做了什么：增加只记录阶段、不记录画面内容的诊断入口，确认画面服务已写出、主 App 已收到，唯一阻塞点是界面事件投递；改为项目现有操作提示已经验证过的原生事件循环投递。
- 验证结果：安装版实时页显示飞书真实缩略图和大画面，状态为“实时画面已连接”，来源、动作和最近事件正常；切回总览后画面进程立即退出，无残留。每个窗口仍限制为每秒 1 张、最大 720 像素宽。
- 下一步：继续完成诊断页导出和任务最终审查，不再改动实时画面主链路。
- 证据：ui:TARGET:UI Bridge 实时操控页:真实缩略图、大画面和已连接状态可见
- 证据：diagnostic:TARGET:preview-diagnostics:worker_first_frame_written -> coordinator_frame_received -> coordinator_frame_applied
- 证据：command:TARGET:pgrep preview-stream:离开实时页后无残留

### 2026-07-14 15:40 - 多应用后台验收通过

- 做了什么：新增后台显示设置页的方式，并把登录后自动启动改为后台启动；使用 Cursor 和 ChatGPT 两个可见窗口做只读实时画面验收。
- 验证结果：实时页同时显示 ChatGPT、Cursor 两个真实缩略图，选中的 Cursor 大画面正常；测试前后前台应用均为 ChatGPT，UI Bridge 未抢焦点。退出后临时截图、诊断记录和画面进程均已清理。
- 下一步：完成诊断页导出和任务最终审查。
- 证据：ui:TARGET:UI Bridge 后台实时操控页:ChatGPT 与 Cursor 双缩略图和 Cursor 大画面可见
- 证据：command:TARGET:apps_list frontmost:before=com.openai.codex after=com.openai.codex
- 证据：diagnostic:TARGET:preview-diagnostics:worker_first_frame_written count=2

### 2026-07-14 16:00 - 真实客户端映射与事件状态

- 做了什么：让直接连接从 MCP 初始化信息识别 Cursor，让本地地址连接从配置请求头识别 WorkBuddy；实时页改为第一屏同时显示实时画面、客户端到应用的链路和事件，并补齐待确认、取消、执行和复查状态。修复改名后遗留的安装与客户端配置脚本语法错误。
- 验证结果：安装版中 Cursor 直接连接和 WorkBuddy 本地地址连接都完成真实窗口只读快照，活动记录分别保留正确来源；后台同时建立 Cursor→Google Chrome 与 WorkBuddy→Cursor 两个实时画面进程，前台应用保持 Google Chrome；离开实时页后两个画面进程全部退出。原生辅助功能树确认第一屏同时包含两条客户端链路和两条实时事件。
- 下一步：完成诊断导出和任务最终审查。
- 证据：command:TARGET:skills/macos-ui-control/scripts/self_test.py:Cursor stdio snapshot passed
- 证据：command:TARGET:/mcp:WorkBuddy HTTP snapshot passed with client identity
- 证据：ui:TARGET:UI Bridge 实时操控页:real preview, two client routes and events visible together
- 证据：command:TARGET:pgrep preview-stream:two apps active, zero after leaving page

### 2026-07-14 16:10 - 调试与诊断完成

- 做了什么：诊断页接入真实服务记录、系统权限、最近客户端、实时画面状态和问题汇总；增加复制排错摘要、保存面板导出脱敏 JSON 报告和成功反馈。报告只保留状态、数量和阶段，明确排除截图、应用名称、窗口编号、界面正文和凭据。补充本机网络声明，并禁止 Bridge 把自身作为自动化目标。
- 验证结果：安装版诊断页显示服务正常、权限 2/2、问题汇总无异常；复制按钮通过真实外部点击，摘要内容和成功反馈正确，原剪贴板已恢复；导出按钮通过系统保存面板生成 778 字节有效报告，隐私字段全部为 false，敏感字段搜索为空，临时文件已删除。测试前台最终恢复为 Google Chrome。
- 下一步：完成危险操作二次确认的安装版回归和任务最终审查。
- 证据：command:TARGET:ui-bridge diagnostic-report:JSON schema and privacy assertions passed
- 证据：ui:TARGET:UI Bridge 调试与诊断页:service, permissions, clients, preview, issues and privacy notice visible
- 证据：ui:TARGET:复制排错信息:success feedback and redacted clipboard content passed
- 证据：ui:TARGET:导出诊断报告:save panel, JSON validation and cleanup passed

### 2026-07-14 17:10 - 危险操作二次确认验收通过

- 做了什么：补齐确认窗口超时自动关闭；增加不接触真实数据的隔离验收夹具；覆盖删除、购买、权限变更三类提示，以及拒绝、超时、单次允许后的重新读取。
- 验证结果：删除类操作点击取消后目标保持“未执行”；单次允许后只执行一次并从新快照读到“已执行一次”；购买类等待超时后弹窗自动关闭并返回拒绝；权限变更类显示独立危险提示并在超时后拒绝。安全 7 项、协议 4 项自检通过，确认目录只剩心跳文件，验收进程全部退出。
- 下一步：完成任务最终审查和安装版综合回归。
- 证据：command:TARGET:swift run safety-self-test:safety-self-test 7 checks passed
- 证据：ui:TARGET:UI Bridge 危险操作确认:deletion deny unchanged; purchase timeout dismissed; permission change warning visible
- 证据：command:TARGET:action_run isolated fixture:approved once and verified from new snapshot

### 2026-07-15 14:00 - 全面更名为 UI Bridge 并记录 Web 方向

- 做了什么：产品、App Bundle、内部程序、系统身份、Swift 目标、进程、服务返回值、MCP 连接、启动项、本地状态和 GitHub 仓库统一为 `UI Bridge / ui-bridge`；安装时迁移旧数据并清理两代旧 App、启动项和连接。新增 Web 方向文档，将原生应用、浏览器页面和内嵌 WebView 归入统一界面目标，具体技术路线保持待定。
- 验证结果：Debug/Release 构建通过；协议 4 项、安全 7 项、核心真实窗口和 10 工具 Skill 自检通过；安装版窗口标题、主标题、菜单栏名称均为 UI Bridge；新 bundle identifier 为 `com.juln.ui-bridge`，健康检查服务名和 Cursor/WorkBuddy 连接名均为 `ui-bridge`；旧 App、启动项和数据目录已移除，旧数据迁入新目录；GitHub 仓库已变为 `z-juln/ui-bridge`，本地 origin 可读取其 master。新 App 当前录屏权限正常，辅助功能需在系统设置对新身份重新开启。
- 下一步：用户完成新身份的辅助功能授权后，执行任务最终审查和安装版综合回归。
- 证据：command:TARGET:/Applications/UI Bridge.app:bundle, executable, identity, launch agent and migrated state passed
- 证据：command:TARGET:skills/macos-ui-control/scripts/self_test.py:server ui-bridge and 10 tools passed
- 证据：ui:TARGET:UI Bridge settings:window, heading and menu bar use the new name
- 证据：document:TARGET:docs/05-future-web-plan.md:future browser page and embedded WebView boundaries recorded
- 证据：url:URL:https://github.com/z-juln/ui-bridge:repository renamed and origin reachable

## 残余

- 实时画面主链路已完成安装版验收。
- 诊断导出、危险操作回归和 UI Bridge 全面更名已完成；新系统身份的辅助功能授权与任务最终审查仍待完成。

## 协调者交接

- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：任务收口时更新
- 负责人：coordinator

### [2026-07-14 05:23] - task-start

- 做了什么：开始实现完整设置、实时画面与危险操作确认
- 验证结果：已记录
- 下一步：继续执行
- 证据：n/a
