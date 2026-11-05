# GPT Image 2.6 支持调查

核查日期：2026-11-05。依据 [OpenAI 图像生成官方文档](https://developers.openai.com/api/docs/guides/image-generation)。模型是否可调用以及第三方兼容程度，仍由 API 账户、分组和服务商决定。

## 官方新增能力与接入情况

| 能力 | 官方协议 | MintImage |
| --- | --- | --- |
| Sunburst / Flare | `gpt-image-2.6-sunburst` / `gpt-image-2.6-flare` | 设置中填写模型名或从接口获取模型列表；保留用户原有默认模型 |
| GIF 动画生成 | Images generations，`output_format: gif` | GUI 和 CLI 可选 GIF；列表、收藏夹、全屏预览保留动画；保存原始 GIF 文件 |
| GIF 帧控制 | `frame_count` 2–64，默认 9；`frame_duration_ms` 20–2000，默认 200 | GUI 动画设置与 CLI 参数；选项、历史记录、重试和备份均保留 |
| SVG 矢量生成 | Images generations，`output_format: svg`，`n: 1` | GUI 和 CLI 可选 SVG；列表、收藏夹、全屏矢量缩放预览；保存原始 XML 文件 |
| 规划复杂度 | `complexity: low / medium / high`，省略时服务端默认 high | Images API 可选；默认不发送，兼容既有模型和服务商 |
| 高质量档位 | `xhigh`、`max`（2.5 / 2.6 Sunburst 和 Flare） | GUI 和 CLI 可选，具体支持由模型决定 |
| 标注引导编辑 | edits 的 `markup`，透明 PNG 标注层须与第一张输入图定向后尺寸一致 | 已调查；本次未增加标注画布或 markup 上传入口 |

## GIF / SVG 限制

- 两者均通过 `/v1/images/generations` 生成，不支持 `/v1/images/edits` 输出；应用在提交前校验。
- 两者均不支持流式、partial images、自定义 `output_compression` 和 `prompt_rewriter`；生成这两种格式时自动使用非流式请求，不改变已保存的流式配置。
- 本次仅接入官方已确认的 Images API 路径，Responses API 选用这两种格式会得到本地明确提示。兼容异步服务商仍使用原有任务轮询。
- GIF 尺寸表示每帧尺寸，宽高须为 16 的正整数倍，或选择自动；帧数、每帧尺寸和数量共同受服务端像素预算限制。不要把静态图的 4K 预设理解为 64 帧 4K 动画一定可用。
- GIF 时长由服务端按 10 毫秒取整。提示词中描述运动和循环方式；本地保留编码后的动画字节，不重新编码为静态图片。
- SVG 是静态矢量文档；官方输出不包含脚本、外部资源或嵌入位图。SVG 不可作为图生图栅格参考图；应用不会把 SVG 直接发送到 edits。
- SVG 预览使用矢量绘制；下载与导出保存 SVG 原文。Flutter SVG 渲染器对字体和部分 SVG 特性的支持可能与浏览器不同。

## 使用方式

GUI：在生图配置中选择 Images API，模型填写 `gpt-image-2.6-flare` 或 `gpt-image-2.6-sunburst`。点击质量按钮调整画质与规划复杂度；点击格式按钮选择 PNG / JPEG / WEBP / GIF / SVG，选择 GIF 时在同一面板调整帧数和帧时长，点击“应用设置”保存。

UI 用小型 `2.6` 徽标标注超高／最高画质、规划复杂度和 GIF／SVG；点击或悬停查看模型与接口要求，具体可用能力以模型和 API 服务商为准。

CLI：

```bash
mint-image generate --model gpt-image-2.6-flare --api-mode images --prompt '一只招手的小猫，无缝循环' --format gif --size auto --frame-count 9 --frame-duration-ms 200 --output cat.gif
mint-image generate --model gpt-image-2.6-sunburst --api-mode images --prompt '薄荷叶标志，简洁矢量路径' --format svg --complexity high --output leaf.svg
```

`--count` 仍表示独立任务数，每次网络请求固定 `n: 1`，所以批量 SVG 不会违反单请求数量限制。

## 验证范围

包含本地 HTTP 协议回归、GIF / SVG 原始字节与扩展名识别、CLI 输出、GUI 参数校验、双帧 GIF 列表和全屏播放、SVG 矢量预览、数据库迁移以及备份恢复测试。未使用用户 API 密钥执行真实付费请求。
