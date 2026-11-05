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

### OpenRouter 实测（2026-11-05）

使用项目 `ImageGenerationApi.generate`，模型 `openai/gpt-image-2.6-flare`，直接 POST 到 `https://openrouter.ai/api/v1/images`，未使用 Python 代发生成请求。

| 请求 | 实际响应 | 结论 |
| --- | --- | --- |
| GIF，`quality: low`、2 帧、200 ms | HTTP 400，`output_format` 仅接受 `png/jpeg/webp/svg` | 当前 OpenRouter 接口校验不接受 GIF |
| SVG，`quality: low` | HTTP 403，`The request is prohibited due to a violation of provider Terms Of Service.` | 本次请求被服务商限制，无法验证 SVG 成图 |
| 用户示例原始请求，仅 model + 山景 prompt | HTTP 403，同一错误；通过项目 `OpenAiClient.postJson` 发出 | 限制不只出现在 SVG 请求，不能据此判定模型不支持 SVG |

本次没有生成 GIF、SVG 或静态图片。未将密钥写入项目或报告。可复用实测入口为 `test/api/live_image_formats_smoke_test.dart`，默认跳过；显式设置 `RUN_LIVE_IMAGE_FORMATS=1`、`TEST_BASE_URL`、`TEST_MODEL`、`TEST_API_KEY` 后运行。可另设 `RUN_LIVE_IMAGE_CONTROL=1` 执行原始静态示例对照。再次运行可能产生 API 费用。

报告保存在 `build/live_image_formats/openrouter-flare-20261105/`。OpenRouter 使用独立的 `/images` 路径，项目已针对该路径做适配；普通 Images API 继续使用 `/v1/images/generations`。

### OpenRouter 协议适配复核（2026-11-05）

依据 [Image API 文档](https://openrouter.ai/docs/api/api-reference/images/generate-an-image) 与 `GET /api/v1/images/models` 实时目录：

- 生图与图生图共用 `POST /api/v1/images`（JSON），图生图通过 `input_references: [{type: image_url, image_url: {url}}]` 传参考图，最多 16 张；不存在 `/images/edits`（实测 404），也不接受 multipart。
- 目录中 `openai/gpt-image-2.6-flare` / `sunburst` 的 `output_format` 仅 `png/jpeg/webp`；`complexity` 只能经 `provider.options.openai.complexity` 透传。
- 未知字段会被静默丢弃（`safety_identifier`、顶层 `complexity`、`markup`、`svg`、`frame_count` 均无报错），因此项目在发送前拒绝 GIF、标注引导和自定义 SVG 绘制模型，安全标识改用 OpenRouter 的 `user` 字段。
- 显式像素 `size` 会被遵守（FLUX 实测 `1536x1024` 返回 1536×1024 PNG）。
- 流式事件为 `image_generation.partial_image` / `image_generation.completed` / `error`，与现有解析兼容。
- 模型列表改用 `/api/v1/images/models`，避免列出文本模型。

本次密钥下所有 `openai/*` 图像模型（含 gpt-image-1-mini、gpt-image-2）对任意请求都返回 HTTP 403 ToS，判断为账户或上游层面的限制，与请求参数无关。因此使用 `black-forest-labs/flux.2-klein-4b`，经项目 `ImageGenerationApi` / `ImageEditApi` / `ModelListApi` 完成了非流式生图、流式生图、`input_references` 图生图和模型列表的实测，均成功；flare 的 403 能完整显示给用户。实测花费 0.071 美元。

### Cubence 实测（2026-11-05）

使用项目 `ImageGenerationApi.generate`，模型 `gpt-image-2.6-flare`，POST 到 `https://api-lb.cubence.ai/v1/images/generations`。GIF / SVG / 静态 PNG 均返回 HTTP 200，且文件原始编码与请求格式一致。SVG 为 1024×1024，已通过项目 `RecordSvgImage` 渲染；存储测试确认三种格式均原样保存。

GIF 参数对照通过相同项目调用链发送，`quality: low`、自动尺寸、`n: 1`，并直接解码返回的 GIF 原始字节统计帧数与每帧延迟：

| 请求帧数 | 请求每帧时长 | 返回帧数 | 返回每帧时长 | HTTP | 参数核验 |
| --- | --- | --- | --- | --- | --- |
| 2 | 200 ms | 9 | 全部 200 ms | 200 | 帧数不符 |
| 12 | 150 ms | 9 | 全部 200 ms | 200 | 帧数与时长均不符 |
| 16 | 300 ms | 9 | 全部 200 ms | 200 | 帧数与时长均不符 |

日志确认请求 JSON 包含对应的 `frame_count` 和 `frame_duration_ms`；12 / 16 帧测试的提示词不指定帧数，排除提示词与参数冲突。三组输出均是实际 GIF，参数核验失败不代表生成失败。结果与默认 9 帧、200 ms 一致，强烈提示中转链路未透传、忽略或重置了动画参数，但仅凭客户端无法断定具体发生在哪一层。未用 OpenAI 直连接口对照，不能断言一定是 Cubence 丢参。

官方文档也已重新核查：

- [图像生成指南](https://developers.openai.com/api/docs/guides/image-generation) 写 `frame_count` 为 2–64，默认 9，`frame_duration_ms` 为 20–2000 ms，默认 200。
- [Images Generate API 参考](https://developers.openai.com/api/reference/resources/images/methods/generate) 写帧数 2–16，默认 9；每帧延迟最小 20 ms，按 10 ms 取整，并说明 GIF 预览访问权限。
- 两处上限暂不一致，但**最低均为 2 帧，9 是默认值而非最低值**。本次 12、16 均在两处文档范围内；返回 9 帧不能用最低帧数限制解释。现有客户端 64 帧上限源自指南，不代表所有服务商都接受；不能据此承诺 17–64 帧可用。

报告和原始文件：`build/live_image_formats/cubence-flare-20261105/`；更多帧数的两组报告分别位于 `frames-12-delay-150/gif.json` 与 `frames-16-delay-300/gif.json`。默认跳过的实测入口额外支持 `TEST_FRAME_COUNT`、`TEST_FRAME_DURATION_MS` 覆盖参数。

### GUI 与 CLI

新增高级设置：

- 格式 → SVG：可选开启“自定义 SVG 绘制模型”，填写模型 ID，选择推理强度。关闭时整个 svg 对象不发送；默认推理强度不发送 reasoning。主模型仍负责参考图，SVG 模型负责矢量编写，权限和可用档位由服务商决定。
- 添加参考图后 → “绘制标注”：大画布直接圈选或涂画，支持五种颜色、笔刷粗细、擦除、撤销/重做、清空、移动缩放和原图对照。更多菜单可导入已有透明 PNG。桌面弹窗、手机全屏布局；应用前的修改可取消。
- 标注针对第一张参考图；保存源图尺寸的透明 PNG，原图不会合并进标注。参考图会按 EXIF 方向校正后确定画布尺寸。移除或更换第一张参考图会清除当前标注关联。
- markup 表达编辑意图，不是硬性限制修改区域的 mask。当前发送 markup，不同时发送 mask 或 prompt_rewriter。需要支持该参数的 Images API 模型；不支持 Responses、GIF/SVG 编辑输出。
- API 配置 → 高级设置：可选 safety_identifier，留空不发送，最多 128 字符。建议匿名 ID 或哈希。该字段也用于 Responses 顶层请求。
- SVG 设置保存在最近使用选项和历史中；标注保存在每条任务历史中，支持重试、复用和备份恢复，不作为全局默认沿用。

CLI 同步增加 --svg-model、--svg-reasoning-effort、--markup 和 --safety-identifier。SVG 推理档位：none / minimal / low / medium / high / xhigh / max。标注通过 multipart 的独立 markup 文件上传；异步 JSON 使用 markup.image_url。PNG 类型、透明度、尺寸及大小在项目共享 Dart 逻辑中校验。

以上高级字段通过本地 HTTP 测试核验请求内容，未追加真实付费测试，不能据此保证中转服务会执行这些参数。

GUI：在生图配置中选择 Images API，模型填写 `gpt-image-2.6-flare` 或 `gpt-image-2.6-sunburst`。点击质量按钮调整画质与规划复杂度；点击格式按钮选择 PNG / JPEG / WEBP / GIF / SVG，选择 GIF 时在同一面板调整帧数和帧时长，点击“应用设置”保存。

UI 用小型 `2.6` 徽标标注超高／最高画质、规划复杂度和 GIF／SVG；点击或悬停查看模型与接口要求，具体可用能力以模型和 API 服务商为准。

CLI：

```bash
mint-image generate --model gpt-image-2.6-flare --api-mode images --prompt '一只招手的小猫，无缝循环' --format gif --size auto --frame-count 9 --frame-duration-ms 200 --output cat.gif
mint-image generate --model gpt-image-2.6-sunburst --api-mode images --prompt '薄荷叶标志，简洁矢量路径' --format svg --complexity high --output leaf.svg
```

`--count` 仍表示独立任务数，每次网络请求固定 `n: 1`，所以批量 SVG 不会违反单请求数量限制。

## 验证范围

包含本地 HTTP 协议回归、GIF / SVG 原始字节与扩展名识别、CLI 输出、GUI 参数校验、双帧 GIF 列表和全屏播放、SVG 矢量预览、数据库迁移以及备份恢复测试。经用户授权，另执行了 OpenRouter 和 Cubence 的真实请求，结果见对应实测段落；密钥未写入项目或报告。
