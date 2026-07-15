# 实现通用 Skill 安装教学入口 - 进度

## 状态：已完成

`## 状态` 是受控机器字段，只能使用以下值之一：

- `未开始`
- `计划中`
- `进行中`
- `审查中`
- `已阻塞`
- `已完成`

不要把 `计划审阅中`、`等待 coordinator pass`、`本地审查就绪` 等细粒度协作状态写入本字段。
这些状态应记录到进度记录、残余或协调者交接中。

## 进度记录

证据使用 `type:path:summary` 格式。

允许的 `type`：`command`, `diff`, `fixture`, `screenshot`, `review`, `report`。

证据较长或数量较多时，不要粘贴全文；放入 `artifacts/INDEX.md` 并在这里引用 ID。

### 2026-07-15 22:20 - 任务开始

- 做了什么：确认第一版只打包现有 Skill，并提供通用教学弹窗和复制提示词。
- 验证结果：当前 App Resources 只有图标，尚未包含 Skill；连接页只有地址和已验证客户端静态信息。
- 下一步：实现资源打包和教学入口。
- 证据：command:TARGET:/Applications/UI Bridge.app/Contents/Resources:only AppIcon.icns before implementation

### 2026-07-15 22:45 - 第一版 Skill 教学入口完成

- 做了什么：将现有 Skill 完整打包进 App；连接页新增通用教学卡片和说明弹窗；提示词要求 Agent 按自身规则安装、备份旧版本、核对名称，并严格禁止子进程恢复 App。
- 验证结果：Debug/Release 构建和安装通过；安装包 4 个 Skill 文件与仓库完全一致；安装版后台打开连接页，教学按钮、弹窗、提示词和“已复制”反馈可见；剪贴板提示词引用真实目录、不含令牌；两轮测试均未抢前台，最终前台保持 Figma，窗口已收起。
- 下一步：随 Web 和经验库等新能力逐步扩展 Skill 内容，不在本任务加入自动安装或状态检测。
- 证据：command:TARGET:diff -rq skills/macos-ui-control /Applications/UI Bridge.app/.../macos-ui-control:identical, 4 files
- 证据：ui:TARGET:UI Bridge 连接页:Agent Skill card, guide sheet and copied feedback passed
- 证据：command:TARGET:clipboard assertions:real source path, independent launch rule, no Bearer token

### 2026-07-15 23:05 - 安装提示词职责收窄

- 做了什么：根据用户反馈删除弹窗中的三步说明和六条运行要求；安装提示词只保留 Skill 来源、复制安装和结果反馈。运行期的连接恢复与安全规则继续由 `SKILL.md` 负责。
- 验证结果：弹窗从 660×500 缩小为 620×330，内容无需滚动即可理解；安装版辅助功能树和截图均确认编号步骤已移除。复制内容缩短到 182 个字符，只包含来源、安装和结果，不含 MCP、子进程、令牌或“要求”列表；复制反馈正常，测试后前台保持 Google Chrome，窗口已收起。
- 下一步：无；后续运行规则只维护在 `SKILL.md`。
- 证据：diff:TARGET:Sources/ui-bridge/SettingsRootView.swift:installer prompt reduced to source, install and result only
- 证据：ui:TARGET:UI Bridge compact skill guide:620x330 layout and copied feedback passed
- 证据：command:TARGET:clipboard assertions:182 chars and no duplicated runtime rules

### 2026-07-15 23:35 - Skill 改为跨平台名称

- 做了什么：Skill 目录、声明名、触发名、App 内资源路径和安装提示词统一改为 `ui-bridge-control`；当前能力说明继续明确只实现 macOS，未来 Windows 沿用同一个 Skill。
- 验证结果：Skill 结构校验通过；构建、四组自检、安装和 Harness 检查通过；安装包只包含新目录且与仓库完全一致。后台打开安装版连接页后，弹窗显示新路径，复制反馈正常，剪贴板 183 个字符且不含旧名；测试窗口已收起。
- 下一步：无；Windows 能力落地时在同一个 Skill 内增加平台分支，不再改名。
- 证据：command:TARGET:quick_validate.py skills/ui-bridge-control:Skill is valid
- 证据：command:TARGET:swift build + protocol/core/safety/skill self-tests:all passed
- 证据：command:TARGET:diff -rq skills/ui-bridge-control /Applications/UI Bridge.app/.../ui-bridge-control:identical
- 证据：ui:TARGET:UI Bridge Skill installation guide:new source path and copied feedback verified

## 残余

- 无阻塞残余。首版有意不自动安装、不检测安装状态、不扩展 Skill 内容。

## 协调者交接（Coordinator，启用模块并行时填写）

- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：任务收口时更新
- 负责人：coordinator
