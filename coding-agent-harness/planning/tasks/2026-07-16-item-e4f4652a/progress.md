# 验证并接入本机视觉文字定位 - 进度

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

### 2026-07-16 00:20 - 验证门槛与接入边界确认

- 做了什么：确定先验证真实中文窗口的文字、区域、坐标与延迟；只有通过才新增正式只读入口。
- 验证结果：当前已有单窗口截图、快照过期和坐标安全检查，可复用；仓库尚未依赖 Vision。
- 下一步：实现平台无关结果、Apple Vision 识别器和独立真实窗口探针。
- 证据：command:TARGET:rg Vision Sources Package.swift:no existing Vision integration

### 2026-07-16 00:45 - Apple Vision 真实中文窗口验证通过

- 做了什么：增加平台无关文字区域结果、Apple Vision 识别器和只读真实窗口自检；使用 UI Bridge 安装版“连接”页连续识别中英文文字。
- 验证结果：每轮识别 23 个文字区域；“连接”和“Agent Skill”均命中，文字区域中心与对应无障碍区域重合，所有截图与窗口坐标均在边界内。首次进程运行冷启动约 730ms，后续冷调用 303-427ms，热调用 187-214ms。侧边栏图标偶尔被识别成字符，证明本能力适合作为文字候选而不能单独决定点击。
- 下一步：门槛通过；把识别器接入当前截图的只读 MCP/HTTP 查询，并保留结构优先和安全检查。
- 证据：command:TARGET:swift run visual-text-self-test --expect 连接:23 regions, ax_aligned=true, warm 188ms
- 证据：command:TARGET:swift run visual-text-self-test --expect Agent Skill:23 regions, ax_aligned=true, warm 187ms

### 2026-07-16 01:20 - 正式只读入口和安全回归完成

- 做了什么：新增跨平台 `visual_text_find` MCP/HTTP/本地调用入口；识别结果绑定当前截图快照并缓存到过期，排除安全输入框区域，不生成控件句柄或直接动作；Skill 和产品文档同步结构优先、视觉后备和未来 Windows 对应实现。
- 验证结果：安装版完整链路识别隔离中文测试窗口，返回 `apple_vision`、置信度 1 和正确窗口区域，首次正式调用 377ms，第二次命中缓存；协议 5 项、核心、8 项安全、11 个 MCP 工具和 Harness 检查通过。重新安装后需先后台打开测试窗口的环境前置已补入说明；隔离夹具和测试窗口均已停止。
- 下一步：无；未来另开任务评估无文字图标和本地小型视觉模型。
- 证据：command:TARGET:installed UI Bridge call visual_text_find:one exact Chinese match, confidence=1, cached on second call
- 证据：command:TARGET:swift build + protocol/core/safety/skill tests:all passed
- 证据：command:TARGET:scripts/install-app.sh:signature, install and launch passed
- 证据：command:TARGET:coding-agent-harness check:passed

## 残余

- 无文字图标、Canvas 语义和 Windows 实现不在本任务范围，已明确保留为后续方向。

## 协调者交接（Coordinator，启用模块并行时填写）

- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：任务收口时更新
- 负责人：coordinator
