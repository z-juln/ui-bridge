# UI Bridge：协议与接入设计

状态：macOS 核心、客户端写入闭环和内部名称迁移均已验收

## 1. 接口设计目标

- MCP 和 HTTP 使用同一套内部请求模型。
- 客户端不接触 macOS 原生对象或内存地址。
- 所有可操作控件都来自当前快照。
- 所有副作用动作都可在执行前检查、紧急停止并在执行后验证。
- 协议明确表达“需要前台”“需要确认”“快照过期”和“结构不完整”。

## 2. 连接和身份

### 本地端口

- 默认地址：`127.0.0.1:8765`
- MCP：`POST /mcp`
- HTTP：`/v1/*`
- 健康检查：`GET /health`

端口可配置，但必须仍绑定回环地址。当前没有配对界面：首次启动生成随机令牌，
以仅当前用户可读的权限写入 `~/.ui-bridge/token`，再由配置脚本写给可信客户端。

### 客户端身份

除健康检查外，每个请求当前都携带 bearer token。客户端级身份、配对和细粒度并发
额度尚未实现。

## 3. 通用数据结构

### App

```json
{
  "app_id": "com.tencent.WeWorkMac",
  "pid": 29942,
  "name": "企业微信",
  "running": true,
  "frontmost": false,
  "authorized": true
}
```

### Window

```json
{
  "window_id": 1926,
  "pid": 29942,
  "title": "企业微信",
  "bounds": { "x": 364, "y": 33, "width": 1148, "height": 944 },
  "visible": true,
  "capturable": true
}
```

### Snapshot

```json
{
  "snapshot_id": "snap_01J...",
  "app_id": "com.tencent.WeWorkMac",
  "pid": 29942,
  "window_id": 1926,
  "created_at": "2026-07-10T17:00:00+08:00",
  "expires_at": "2026-07-10T17:01:00+08:00",
  "tree_quality": "complete",
  "window_bounds": { "x": 364, "y": 33, "width": 1148, "height": 944 },
  "screenshot": {
    "handle": "shot_01J...",
    "width": 1568,
    "height": 1289,
    "mime_type": "image/png"
  },
  "elements": []
}
```

`tree_quality`：

- `complete`：结构与画面基本一致。
- `partial`：画面有内容但结构只暴露部分区域。
- `shell_only`：只有窗口、菜单和外壳。
- `unavailable`：应用不支持或读取失败。

### Element

```json
{
  "handle": "snap_01J...:51:8fd2",
  "index": 51,
  "parent_index": 25,
  "role": "row",
  "label": "庄俊霖 | Junlin Zhuang",
  "value": null,
  "frame_in_window": { "x": 58, "y": 430, "width": 360, "height": 64 },
  "screenshot_frame": { "x": 79, "y": 587, "width": 492, "height": 87 },
  "states": {
    "enabled": true,
    "selected": false,
    "focused": false,
    "settable": false
  },
  "actions": ["press", "select"]
}
```

### Action request

```json
{
  "snapshot_id": "snap_01J...",
  "target": { "element_handle": "snap_01J...:51:8fd2" },
  "action": "select",
  "delivery": "background",
  "verify": {
    "type": "element_text_present",
    "text": "庄俊霖 | Junlin Zhuang"
  }
}
```

### Action result

```json
{
  "action_id": "act_01J...",
  "status": "confirmed",
  "delivery_used": "accessibility",
  "focus_changed": false,
  "new_snapshot_id": "snap_01J...",
  "evidence": {
    "matched_condition": "element_text_present",
    "observed": "庄俊霖 | Junlin Zhuang"
  }
}
```

## 4. 错误模型

所有错误包含稳定代码、简短说明、是否可重试和建议下一步。

| 代码 | 含义 | 默认处理 |
|---|---|---|
| `permission_missing` | 缺少系统权限 | 引导用户到 App 权限页 |
| `app_not_found` | 应用未运行或标识错误 | 重新发现应用 |
| `window_ambiguous` | 找到多个候选窗口 | 返回候选，不猜测 |
| `snapshot_stale` | 窗口或控件已变化 | 重新获取快照 |
| `element_not_found` | 句柄已失效 | 重新搜索控件 |
| `partial_tree` | 结构读取不完整 | 使用截图或备用通道 |
| `background_dropped` | 后台事件未产生效果 | 请求前台升级 |
| `foreground_required` | 下一步需要切前台 | 向用户确认 |
| `confirmation_required` | 动作具有外部影响 | 展示动作内容并确认 |
| `verification_ambiguous` | 无法确定是否成功 | 停止，不自动重复 |
| `rate_limited` | 同一窗口动作过密 | 等待或合并动作 |
| `unsupported` | 应用或动作不支持 | 换动作路线 |

## 5. MCP 工具

第一版提供以下工具，名称保持短且稳定：

### `apps_list`

列出可发现应用及权限状态。

### `windows_list`

输入应用标识或 pid，返回窗口列表。

### `snapshot_get`

读取指定窗口的结构与截图。支持：

- 是否包含截图。
- 最大节点数和深度。
- 文本过滤，但过滤不能改变控件句柄。
- 只返回与上次快照的变化。

### `element_find`

按 role、label、value、state 和祖先关系搜索当前快照。禁止仅返回模糊匹配的第一项；
多个结果时必须返回候选及匹配原因。

### `plan_check`

在执行前检查一次候选动作。它不调用模型，也不消耗额外模型额度；只根据当前快照判断：

- 控件句柄是否仍属于当前界面。
- 坐标是否来自同一份截图且位于窗口内。
- 是否需要用户允许切到前台。
- 发送、删除、提交等动作是否已获得明确确认。

只有返回 `ready` 才进入 `action_run`。其他结果必须先刷新界面、读取截图或请求确认，
不能直接绕过。

### `action_run`

执行一个动作并验证。支持：

- `press`
- `select`
- `set_value`
- `type_text`
- `press_key`
- `scroll`
- `show_menu`
- `coordinate_click`

当前不保存挂起动作，也没有单独的确认或取消工具。高影响动作先由 `plan_check`
返回需要确认；用户确认后，客户端在 `action_run` 的同一次请求中明确标记已确认。

### `emergency_stop`

立即停止当前会话，释放输入状态并拒绝后续动作，直到用户在 App 中恢复。

### `diagnostics_get`

返回权限、连接、应用兼容性和最近错误摘要，不包含聊天正文和密码字段。

## 6. HTTP 接口

HTTP 与 MCP 使用同一套内部能力。当前动作同步返回结果和新快照，不提供事件流或
异步动作查询。

建议采用 JSON Schema 生成：

- Swift 请求模型。
- MCP 工具定义。
- TypeScript 客户端。
- HTTP 接口文档。
- 契约测试样例。

避免手工维护四套字段定义。

## 7. Cursor 接入

### 当前 Cursor 实测：MCP stdio

```json
{
  "mcpServers": {
    "ui-bridge": {
      "command": "/Applications/UI Bridge.app/Contents/MacOS/ui-bridge",
      "args": ["mcp"]
    }
  }
}
```

Cursor 3.6.31 已实测能加载此配置。当前直接启动模式仍可能要求 Cursor 拥有桌面权限；
后续把这个入口改为只转接已运行 App。

### 本地 HTTP MCP

服务地址为 `http://127.0.0.1:8765/mcp`。WorkBuddy 4.24.8 已实测支持；Cursor
3.6.31 在本机连接失败，因此暂不作为 Cursor 默认配置。

## 8. WorkBuddy 接入

优先确认 WorkBuddy 支持哪种能力：

1. 支持 MCP：直接使用本地 MCP 地址。
2. 支持自定义工具或 HTTP：使用 `/v1` 接口和生成的 OpenAPI 文件。
3. 只支持 Skill 脚本：通过配套命令行调用本地 HTTP 接口。

当前 macOS 版本通过“自定义连接器 → 配置 MCP”界面实测读取 `~/.workbuddy/mcp.json`，支持 `streamable-http` 类型、
本地 URL、自定义请求头和超时。配置脚本会保留现有 `connector-proxy` 与其他服务，
只增加 `ui-bridge`；发现早期连接项时，备份配置后迁移并删除旧项。
配置脚本还会写入 `X-App-MCP-Client: WorkBuddy`，供 App 的实时操控页区分客户端来源。
stdio 连接不需要额外配置，Bridge 会读取 MCP 初始化时提供的客户端名称。

## 9. 配套 Skill

Skill 不实现桌面操作，只规定如何安全、可靠地调用 MCP。目录建议：

```text
skills/macos-ui-control/
├── SKILL.md
├── agents/openai.yaml
└── references/
    ├── action-routing.md
    ├── confirmations.md
    └── app-compatibility.md
```

`SKILL.md` 保持简短，包含：

- 先读状态再操作。
- 优先按控件，不优先按坐标。
- 每次导航后刷新快照。
- 发现结构不完整时切换路线。
- 后台失败后才申请前台。
- 发送、删除、提交等动作按宿主规则确认。
- 操作后必须验证。
- 两种不同路线失败后停止，不盲目重试。

应用特殊经验放入 `references/app-compatibility.md`，避免主 Skill 随应用数量膨胀。

第一轮必须交付可用 Skill，而不是只提供设计稿。Skill 的验收包括：

- 能在 Cursor 中触发并调用本项目 MCP。
- 能在支持 Skill 的 WorkBuddy 中通过 MCP 或本地命令调用。
- 对未指定应用的通用任务，先发现应用和窗口再决定动作。
- 不包含企业微信、微信或任何联系人专属的固定流程。
- 通过 Skill 创建规范的格式检查，并用至少四类代表应用做真实任务测试。

## 10. 会话与并发

- 当前运行时统一串行保护快照和动作状态，避免并发修改内部状态。
- 当前没有跨客户端持久会话、窗口级排队或挂起确认动作。
- 多客户端同时写同一窗口的更细粒度协调仍属于后续增强。

## 11. 隐私处理

- 默认响应中不返回密码类控件的值。
- 对疑似令牌、验证码、密码、银行卡号和身份证号进行遮盖。
- 截图句柄默认 60 秒失效。
- HTTP 不提供任意文件路径读取。
- 诊断日志不保存完整输入文本和聊天正文。
- 用户可通过 `status` 命令查看本地服务是否运行；菜单栏显示最近被读取或操作的应用。
