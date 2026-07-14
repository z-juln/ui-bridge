# App MCP Bridge

本机 macOS 桌面操作服务，当前提供通用应用/窗口发现、控件树核心、窗口截图、
动作执行前检查、动作验证、带令牌保护的本地 HTTP 接口、MCP 接入和通用 Skill。

## 构建与自检

```bash
swift build
swift run protocol-self-test
swift run core-self-test
python3 skills/macos-ui-control/scripts/self_test.py
```

## 构建并安装 App

```bash
./scripts/build-app.sh
./scripts/install-app.sh
```

安装位置为 `/Applications/App MCP Bridge.app`。首次打开会提示缺少的系统权限；
选择“前往设置”后，App 会以自己的名称登记到对应权限列表。

产品名不包含平台名称，便于以后增加 Windows 版本。当前版本仍只支持 macOS；
MCP 连接名、安装后的程序文件名和 macOS 身份均已统一为 `app-mcp-bridge`。

首次构建会在本机创建一个只供此项目使用的长期程序身份，因此之后重新构建、覆盖安装时会沿用已有权限。
从旧构建方式升级到这一版时，需要在系统设置里将两项权限各关闭再开启一次；这是
最后一次迁移，后续重装不再需要重复授权。

App 提供完整设置与实时操控窗口，启动后也会在程序坞和菜单栏显示图标。菜单栏可
打开设置、检查权限、复制 MCP 连接配置或退出服务。第一次点“检查系统权限”时，
App 会先向 macOS 正式申请缺少
的权限，使自身出现在对应的系统设置列表中。可用下面的命令确认后台服务：

App 启动时也会自动校验权限；两项都已授权时保持静默，只有确实缺少权限才提示。
从菜单手动点击“检查系统权限”时，即使权限正常也会显示明确的检查结果。

当前已完成能力和后续范围见 [`docs/04-current-status.md`](docs/04-current-status.md)。

```bash
curl http://127.0.0.1:8765/health
```

安装脚本同时启用登录后自动启动，不需要每次手动打开 App。

普通打开设置会把 App 带到前台；调试或自动验收时可在后台显示指定页面，不改变
用户当前正在使用的应用：

    '/Applications/App MCP Bridge.app/Contents/MacOS/app-mcp-bridge' show liveControl --background

登录后的自动启动同样使用后台方式，不主动弹出窗口或抢占焦点。

## 启动服务

```bash
swift run app-mcp-bridge start
swift run app-mcp-bridge status
```

默认只监听 `127.0.0.1:8765`。查看令牌：

```bash
swift run app-mcp-bridge token
```

检查接口：

```bash
TOKEN=$(swift run app-mcp-bridge token 2>/dev/null)
curl http://127.0.0.1:8765/health
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/v1/permissions
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/v1/apps
```

停止：

```bash
swift run app-mcp-bridge stop
```

当前接口：

- `GET /health`
- `POST /mcp`
- `GET /v1/permissions`
- `GET /v1/apps`
- `GET /v1/apps/{pid}/windows`
- `GET /v1/diagnostics`
- `POST /v1/snapshots`
- `POST /v1/actions`
- `POST /v1/elements/find`
- `POST /v1/plans/check`
- `POST /v1/screenshots/get`
- `POST /v1/emergency-stop`

除 `/health` 外均需 `Authorization: Bearer <token>`。

## 接入 Cursor 或 WorkBuddy

推荐连接已运行 App 的本地地址。先执行：

```bash
TOKEN=$('/Applications/App MCP Bridge.app/Contents/MacOS/app-mcp-bridge' token)
```

再把 `$TOKEN` 替换成上一步输出：

```json
{
  "mcpServers": {
    "app-mcp-bridge": {
      "url": "http://127.0.0.1:8765/mcp",
      "headers": {
        "Authorization": "Bearer $TOKEN",
        "X-App-MCP-Client": "WorkBuddy"
      }
    }
  }
}
```

如果客户端不支持本地地址，使用直接启动方式：

```json
{
  "mcpServers": {
    "app-mcp-bridge": {
      "command": "/Applications/App MCP Bridge.app/Contents/MacOS/app-mcp-bridge",
      "args": ["mcp"]
    }
  }
}
```

两种方式提供相同工具。详细权限和排错说明见 `skills/macos-ui-control/references/setup.md`。
本地地址连接应通过 `X-App-MCP-Client` 传入客户端显示名；直接启动连接会从 MCP
初始化信息自动识别 Cursor、WorkBuddy 或其他客户端。实时操控页据此显示真实来源。

首次检查发现缺少辅助功能或屏幕录制权限时，服务会主动弹窗。选择“前往设置”即可
打开对应的系统设置页；同一次运行不会重复弹出相同提醒。
