# 图片合集转加密 PDF / Image to Encrypted PDF

![Version](https://img.shields.io/badge/version-2.3.1-blue)
![Platform](https://img.shields.io/badge/macOS-11%2B-lightgrey)
![Arch](https://img.shields.io/badge/arch-arm64%20%7C%20x86__64-green)
![License](https://img.shields.io/badge/license-MIT-orange)
![Offline](https://img.shields.io/badge/network-none-success)

一款**纯原生 macOS App**：把加密压缩包里几百张图片，合并成一个体积很小、可加密码的 PDF，
方便用微信分享。全程离线，不上传任何文件。

> 2~3 GB 图片 → 约 20 MB PDF，在你的 Mac 上一分钟内完成。

[English README](README.md) · [更新日志](CHANGELOG.md) ·
[贡献指南](CONTRIBUTING.md) · [安全策略](SECURITY.md) · [测试说明](tests/README.md) · [行为准则](CODE_OF_CONDUCT.md)

---

## 为什么做这个

212 张、2.8 GB 的照片压缩包没法直接发微信，直接转成的 PDF 依旧巨大。
本工具直接读取压缩包，按「目标体积 ÷ 张数」为每张图计算体积预算，
逐张缩放并重编码 JPEG，再无损嵌入 PDF；页面尺寸跟随图片比例（没有 A4 白边），
最后用 AES-256 加密。

界面是 Swift / AppKit，处理引擎是 Go 子进程，两者通过 stdout 的 JSON 行通信。
**不启动浏览器、不启本地 HTTP 服务、不含任何联网代码。**

## 功能

- **加密输入**：直接读取 7z、ZIP（AES）、RAR / RAR5（含文件名加密），密码只在内存中使用。
- **顺序由你定**：清单里拖拽排序，或用移动按钮、右键菜单置顶 / 移动 / 移除 / 反序；清单顺序就是 PDF 页序。
- **预览与位置**：点选可看缩略图（EXIF 自动转正）、原始尺寸、体积、包内完整路径；可复制路径或在 Finder 中显示。预览可以整体关闭。
- **精确控制体积**：填目标 MB，引擎自动二分搜索满足预算的最高 JPEG 画质。
- **并行**：图片处理使用有界工作线程池；「任务队列」窗口还能同时跑多个独立任务（1~4 并发）。
- **容错**：尾部数据不完整的 JPEG 会自动补齐；确实无法修复的图片只跳过自己那一页，不会中断整批任务，并可输出诊断报告。
- **PDF 加密**：纯 Go 实现 PDF 2.0 AES-256（R=6）打开密码。
- **双语与主题**：中文 / English，跟随系统 / 浅色 / 深色；清单—预览分栏、日志区高度都可拖动。
- **版本信息**：主窗口有 `v2.3.1` 版本胶囊，关于窗口显示完整版本号与当前语言的「开发者：aibanana」。

## 安装

从 Releases 下载 `ImageToEncryptedPDF_macOS.dmg`，打开后把 App 拖进「应用程序」。
首次启动用**右键 → 打开 → 打开**（二进制为 ad-hoc 签名，未做 Apple Developer ID 公证）。

ZIP 与 DMG 内的 App 目录名均为 ASCII 的 `ImageToEncryptedPDF.app`，避免 Windows / 第三方解压工具出现中文乱码；访达里显示的仍是本地化名称（由 `CFBundleDisplayName` 决定）。

要求 macOS 11+。包体为 Universal 2，Apple Silicon（M1~M4）与 Intel 均原生运行，无需 Rosetta：

```bash
lipo -archs "/Applications/ImageToEncryptedPDF.app/Contents/MacOS/imgtopdf_ui"
# x86_64 arm64
```

## 从源码构建

```bash
make verify-version  # 校验 VERSION / App.swift / version.go 三处版本一致
make engine-test     # Go 引擎单元测试与端到端回归
make build           # 生成 .app / DMG / ZIP（默认落在仓库内 .build/ 与 outputs/）
```

需要 macOS + Xcode 命令行工具、Go 1.22+；生成图标可选装 Python 3 + Pillow。
若想把产物放到仓库外，可用 `IMGTOPDF_ROOT=/path/to/workspace` 与
`IMGTOPDF_OUT=/path/to/outputs` 两个环境变量覆盖。

## 架构

```
┌─────────────────────────────────────────────┐
│  Swift / AppKit  (macapp/App.swift)          │
│  原生窗口 · 清单 · 预览 · 任务队列           │
└───────────────────┬─────────────────────────┘
                    │ 子进程，stdout 上每行一个 JSON
┌───────────────────▼─────────────────────────┐
│  Go 引擎  (imgtopdf/)                       │
│  list · thumb · build → progress/log/result │
│  解压 → 解码/补齐 → 缩放 → JPEG             │
│  → PDF（fit 页面）→ AES-256 加密            │
└─────────────────────────────────────────────┘
```

`build` 子命令也可直接用于自动化：

```bash
imgtopdf-helper build \
  --src "photos.rar" --archive-pass '...' \
  --out "out.pdf" --pdf-pass '...' \
  --target-mb 20 --max-edge 1600 --quality 82 \
  --page fit --workers 4 --error-log "out_错误报告.log"
```

## 多语言架构

所有界面文案都集中在 `macapp/App.swift` 顶部的 `ZH` / `EN` 两份字典里，是唯一真源。
`Lang.allCases` 自动生成语言下拉、偏好记忆以及传给引擎的 `--lang` 参数。Go 引擎
不产生给界面看的文字，只发语言无关的 `{key, args}` 事件（`imgtopdf/msg.go`），
由界面在渲染时查表。日志按「渲染器」存储而不是存成品文字，所以切换语言时
整段历史（包括之前引擎打印的消息）会一起重渲染，英文界面不会出现任何中文。

新增一种语言：在 `Lang` 加一个 case、在 `STRINGS` 加一份字典、再补 `lang.*`
两个语言名即可，其它代码不用动。

默认输出名与报告名也跟随界面语言（`_压缩加密` / `_encrypted`、
`_错误报告.log` / `_error_report.log`），切换语言时自动同步；但用户手动输入
或另存过的文件名一律保留，不会被覆盖。

## 随时补加队列任务

生成过程中主按钮自动变成「加入队列」，队列窗口有常驻「添加当前配置」，
加入后还会自动弹出队列窗口。队列已启动后再补加的任务会被立即调度，
输出名重名时自动改名，避免两个进程写同一个 PDF。

## 实测性能

212 张、2.8 GB RAR5、目标 20 MB、Apple M4：

| 线程数 | 耗时 | 产物 | 备注 |
| --- | --- | --- | --- |
| 1 | 150.2 s | 18.8 MB / 212 页 | 1 张截断 JPEG 自动补齐 |
| 4 | **44.1 s** | 18.8 MB / 212 页 | 提速 3.4 倍，CPU 400% |

## 已知限制

- 纯 Go 引擎不能解码 HEIC / HEIF / AVIF，请先转成 JPEG 或 PNG。
- 同时加密文件名的 7z、分卷 RAR、微信内置 PDF 预览对加密 PDF 的兼容性可能需要绕行方案。
- 暂未做 PDF 线性化（linearization），超大 PDF 在手机上可能需要下载完才显示。
- Windows 版仍是早期的「浏览器界面」版本，本分支暂不维护；旧源码保留在 [`legacy/`](legacy/README.md)。
- App 为 ad-hoc 签名，未公证；首次打开需右键 → 打开。

## 隐私

无遥测、无统计、无网络请求、无云端。密码不会写入日志或错误报告，
错误报告只记录「是否设置密码」。详见 [SECURITY.md](SECURITY.md)。

## 许可

MIT © 2026 **aibanana**。见 [LICENSE](LICENSE)。
