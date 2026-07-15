# UI Bridge 本地开发、安装与接入

本文面向本地开发者和接入方。项目介绍请先阅读仓库根目录的 `README.md`。

当前 macOS 版本提供通用应用/窗口发现、控件树核心、窗口截图、
动作执行前检查、动作验证、带令牌保护的本地 HTTP 接口、MCP 接入和通用 Skill。
未来将把浏览器页面和内嵌 WebView 纳入同一目标模型，已确认的产品方案见
[`05-future-web-plan.md`](05-future-web-plan.md)。

## 构建与自检

```bash
swift build
swift run protocol-self-test
swift run core-self-test
python3 skills/ui-bridge-control/scripts/self_test.py
```

## 构建并安装 App

```bash
./scripts/build-app.sh
./scripts/install-app.sh
```

安装位置为 `/Applications/UI Bridge.app`。首次打开会提示缺少的系统权限；
选择“前往设置”后，App 会以自己的名称登记到对应权限列表。

产品名不绑定应用、平台或接入协议，便于以后增加 Web 和 Windows。当前版本仍只支持 macOS 原生界面；
MCP 连接名、安装后的程序文件名和 macOS 身份均已统一为 `ui-bridge`。

首次构建会在本机创建一个只供此项目使用的长期程序身份，因此之后重新构建、覆盖安装时会沿用已有权限。
从旧名称升级到 `UI Bridge` 时，macOS 会把它视为新应用，需要重新授予辅助功能和录屏权限；
旧应用、启动项、连接配置和本地数据会自动迁移或清理。

App 提供完整设置与实时操控窗口，启动后也会在程序坞和菜单栏显示图标。菜单栏可
打开设置、检查权限、复制 MCP 连接配置或退出服务。第一次点“检查系统权限”时，
App 会先向 macOS 正式申请缺少
的权限，使自身出现在对应的系统设置列表中。可用下面的命令确认后台服务：

App 启动时也会自动校验权限；两项都已授权时保持静默，只有确实缺少权限才提示。
从菜单手动点击“检查系统权限”时，即使权限正常也会显示明确的检查结果。
权限页为辅助功能和屏幕录制分别提供对应的系统设置入口，并常驻提示授权后需要重启
UI Bridge 才能生效。

当前已完成能力和后续范围见 [`04-current-status.md`](04-current-status.md)。

```bash
curl http://127.0.0.1:8765/health
```

安装脚本同时启用登录后自动启动，不需要每次手动打开 App。

普通打开设置会把 App 带到前台；调试或自动验收时可在后台显示指定页面，不改变
用户当前正在使用的应用：

    '/Applications/UI Bridge.app/Contents/MacOS/ui-bridge' show liveControl --background

登录后的自动启动同样使用后台方式，不主动弹出窗口或抢占焦点。

## 启动服务

```bash
swift run ui-bridge start
swift run ui-bridge status
```

默认只监听 `127.0.0.1:8765`。查看令牌：

```bash
swift run ui-bridge token
```

检查接口：

```bash
TOKEN=$(swift run ui-bridge token 2>/dev/null)
curl http://127.0.0.1:8765/health
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/v1/permissions
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/v1/apps
```

停止：

```bash
swift run ui-bridge stop
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

## 接入 MCP 客户端

推荐连接已运行 App 的本地地址。先执行：

```bash
TOKEN=$('/Applications/UI Bridge.app/Contents/MacOS/ui-bridge' token)
```

再把 `$TOKEN` 替换成上一步输出：

```json
{
  "mcpServers": {
    "ui-bridge": {
      "url": "http://127.0.0.1:8765/mcp",
      "headers": {
        "Authorization": "Bearer $TOKEN",
        "X-App-MCP-Client": "WorkBuddy"
      }
    }
  }
}
```

连接失败时，先独立启动 App，再让客户端重连：

```bash
open -g "/Applications/UI Bridge.app"
```

禁止通过 `swift run`、`ui-bridge start`、`serve`、`mcp`、`nohup` 或 shell 后台任务恢复
App。只有客户端明确不支持本地地址时，才使用下面的兼容方式，且不能作为连接失败后的自动降级：

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

两种方式提供相同工具。详细权限和排错说明见 `skills/ui-bridge-control/references/setup.md`。
本地地址连接可通过 `X-App-MCP-Client` 传入客户端显示名；直接启动连接会从 MCP
初始化信息识别客户端。实时操控页据此显示真实来源。Cursor 和 WorkBuddy 是已经完成
真实写入验收的示例，不是产品绑定或客户端白名单。

## 安装 Agent Skill

当前通用 Skill 位于仓库的 `skills/ui-bridge-control/`，构建后也会完整复制到
`/Applications/UI Bridge.app/Contents/Resources/skills/ui-bridge-control`。用户可在设置的
“连接”页点击“安装 Agent Skill”，预览并复制安装提示词。源码开发阶段也可把下面这段
提示词连同仓库路径交给当前 Agent：

```text
请从当前 UI Bridge 仓库的 skills/ui-bridge-control/ 安装 Agent Skill。
请按当前客户端支持的 Skill 安装方式复制完整目录，不要影响其他 Skill。
安装完成后重新读取 SKILL.md，并告诉我安装位置和结果。
```

App 教学按钮复制同等含义的自包含提示词，并引用 App 内随包提供的稳定只读 Skill 源。
它不绑定指定 Agent，不通过 MCP 自动安装，也不扫描或猜测 Skill 是否已经加载。客户端
若未明确支持 Skill，仍可只使用 MCP；关键安全规则由 Bridge 强制。
连接恢复、独立启动和操作安全等规则由安装后的 `SKILL.md` 提供，不在安装提示词中重复。

首次检查发现缺少辅助功能或屏幕录制权限时，服务会主动弹窗。选择“前往设置”即可
打开对应的系统设置页；同一次运行不会重复弹出相同提醒。
