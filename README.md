# macOS UI Bridge

本机 macOS 桌面操作服务，当前提供通用应用/窗口发现、控件树核心、窗口截图、
动作验证和带令牌保护的本地 HTTP 接口。MCP 与 Skill 正在后续阶段实现。

## 构建与自检

```bash
swift build
swift run protocol-self-test
swift run core-self-test
```

## 启动服务

```bash
swift run macos-ui-bridge start
swift run macos-ui-bridge status
```

默认只监听 `127.0.0.1:8765`。查看令牌：

```bash
swift run macos-ui-bridge token
```

检查接口：

```bash
TOKEN=$(swift run macos-ui-bridge token 2>/dev/null)
curl http://127.0.0.1:8765/health
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/v1/permissions
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/v1/apps
```

停止：

```bash
swift run macos-ui-bridge stop
```

当前接口：

- `GET /health`
- `GET /v1/permissions`
- `GET /v1/apps`
- `GET /v1/apps/{pid}/windows`

除 `/health` 外均需 `Authorization: Bearer <token>`。
