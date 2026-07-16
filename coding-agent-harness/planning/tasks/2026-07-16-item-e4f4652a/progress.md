# 验证并接入本机视觉文字定位 - 进度

## 状态：进行中

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

## 残余

- 尚未获得真实窗口识别结果，正式接入仍受门槛约束。

## 协调者交接（Coordinator，启用模块并行时填写）

- Global sync status：n/a
- Registry update needed：不适用
- Harness Ledger update needed：任务收口时更新
- 负责人：coordinator
