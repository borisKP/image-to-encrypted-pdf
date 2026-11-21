import AppKit
import Foundation

// Single source of truth for the UI version. build_macos.sh reads src/VERSION
// and writes the matching CFBundleShortVersionString into Info.plist.
let UIAppVersion = "2.3.1"
let UIAppVersionShort = "v2.3.1"

// MARK: - Localization
//
// Table-driven single source of truth. Adding a language takes exactly two
// edits: a new case in `Lang` (with its native display name), and one entry in
// `STRINGS`. The language popup, the saved preference, and the --lang value
// handed to the Go helper are all derived from Lang.allCases, so no other
// part of the app has to know how many languages exist.

enum Lang: String, CaseIterable {
    case zh, en
    /// The picker writes every language name in the active UI language, so an
    /// English interface contains no Chinese characters at all.
    var nameKey: String { "lang." + rawValue }
}
private var currentLang: Lang = .zh

private let ZH: [String: String] = [
    "appTitle": "图片合集 → 加密 PDF",
    "subtitle": "选择加密压缩包或图片文件夹 · 调整页序 · 一键生成适合微信分享的加密 PDF",
    "srcLabel": "图片来源", "srcPlaceholder": "点「选择压缩包」或「选择文件夹」",
    "btnArchive": "选择压缩包…", "btnFolder": "选择文件夹…", "btnLoad": "读取图片清单",
    "passLabel": "压缩包密码", "passPlaceholder": "7z / ZIP / RAR 密码（未加密可留空）",
    "passHintArchive": "支持 7z / ZIP / RAR（含 RAR5）加密包；密码只在本机使用，不会保存",
    "passHintFolder": "图片文件夹无需密码；支持 JPG / PNG / GIF / BMP / TIFF / WebP",
    "showPass": "显示密码",
    "listHeader": "图片清单（可拖拽调整顺序，即 PDF 页序）",
    "listHeaderEdited": "图片清单（已自定义顺序 · 即 PDF 页序）",
    "btnTop": "顶", "btnUp": "上", "btnDown": "下", "btnBottom": "底",
    "colNo": "#", "colName": "文件名", "colPath": "所在位置 / 包内路径", "colSize": "原图大小",
    "previewHeader": "图片预览与位置信息", "previewToggle": "显示图片预览",
    "previewOff": "图片预览已关闭\n\n不解码图片，也不在磁盘生成任何临时预览文件。\n位置信息仍在下方显示，可继续复制路径或在访达中显示。\n\n需要看图时勾选右上角「显示图片预览」，\n或使用菜单「显示 → 显示图片预览」（⌘⇧P）。",
    "offSuffix": "\n图片预览已关闭（不读取图像内容）",
    "btnPrev": "← 上一张", "btnNext": "下一张 →", "btnCopyPath": "复制路径", "btnReveal": "在访达中显示",
    "pdfPassLabel": "PDF 密码", "pdfPassPlaceholder": "生成的 PDF 打开密码", "pdfPassHint": "留空表示不加密",
    "targetLabel": "目标体积", "mbLabel": "MB", "edgeLabel": "长边", "pxLabel": "px",
    "qualityLabel": "画质",
    "outLabel": "输出文件", "outPlaceholder": "", "btnChooseOut": "选择保存位置…",
    "btnStart": "开始生成 PDF", "btnStop": "停止",
    "btnShowResult": "在访达中显示成品", "btnOpenResult": "用「预览」打开",
    "statusReady": "准备就绪", "statusReading": "正在读取压缩包清单…",
    "statusGenerating": "正在生成…", "statusCopied": "已复制路径到剪贴板", "statusStopped": "已停止",
    "appSystem": "跟随系统", "appLight": "浅色", "appDark": "深色",
    "menuAbout": "关于 图片合集转加密PDF", "menuQuit": "退出",
    "menuEdit": "编辑", "menuUndo": "撤销", "menuRedo": "重做", "menuCut": "剪切",
    "menuCopy": "拷贝", "menuPaste": "粘贴", "menuSelectAll": "全选", "menuView": "显示",
    "menuPreview": "显示图片预览",
    "ctxTop": "置顶（设为第 1 页）", "ctxUp": "上移一页", "ctxDown": "下移一页",
    "ctxBottom": "置底（设为最后一页）", "ctxCopy": "复制路径", "ctxReveal": "在访达中显示",
    "ctxRemove": "从清单移除（不生成这一页）", "ctxRestore": "恢复默认顺序与全部图片",
    "ctxReverse": "倒序排列",
    "qPoor": "较差", "qFair": "一般", "qMedium": "中等", "qGood": "良好",
    "qFine": "优良", "qBest": "极佳",
    "infoSelect": "点击「读取图片清单」查看图片，然后选中任意一行。",
    "infoSelectOff": "图片预览已关闭。读取清单后选中任意一行，仍可查看它的位置信息。",
    "infoReading": "正在读取第 %d 张…",
    "infoArchive": "包内路径", "infoDisk": "磁盘路径",
    "infoPage": "第 %d / %d 张 · ", "infoSize": "原图大小：",
    "infoDimensions": "原始尺寸 %d × %d · %.1f MB", "infoRotation": "，EXIF 方向已自动转正（%d）",
    "infoFailed": "预览失败：",
    "logReady": "就绪。所有处理均在本机完成，不联网、不上传文件。",
    "logSelected": "已选择：", "logListOk": "清单读取成功：%d 张图片，来源类型 ",
    "logStart": "—— 开始生成：%d 张图片，目标 %d MB ——",
    "logNoPass": "提示：未设置 PDF 密码，成品为明文文件",
    "logOver20": "提示：成品超过 20MB，可把「目标体积」调小或降低长边后再试。",
    "logStop": "已由用户停止生成。",
    "logAppearance": "外观已切换：",
    "logPreviewOn": "已开启图片预览",
    "logPreviewOff": "已关闭图片预览：不解码图片、不生成临时文件；位置信息仍可查看",
    "logTop": "已把第 %d 张置顶", "logBottom": "已把第 %d 张置底",
    "logMove": "已把第 %d 张移到第 %d 页", "logRemove": "已移除第 %d 张，剩余 %d 张",
    "logRestore": "已恢复默认顺序与全部图片", "logReverse": "已倒序排列",
    "logDrag": "清单顺序已更新，PDF 将按此顺序生成",
    "errNoSource": "请先选择来源并读取图片清单", "errNoOut": "请填写输出文件路径",
    "errTarget": "目标体积请填 1–500 MB", "errEdge": "长边请填 400–6000 px",
    "errQuality": "画质请填 25–95", "errNoSrcShort": "请先选择压缩包或文件夹",
    "pickArchive": "选择加密压缩包", "pickArchiveMsg": "支持 .7z / .zip / .rar（含 RAR5）加密压缩包",
    "pickFolder": "选择存放图片的文件夹", "pickOut": "保存 PDF 到",
    "aboutTitle": "关于 图片合集转加密 PDF", "aboutVersion": "版本 Version",
    "aboutDeveloper": "开发者：aibanana", "aboutLicense": "MIT 开源许可 · 完全离线运行 · 不上传任何文件",
    "aboutDesc": "把加密压缩包 / 文件夹里的图片，按你的顺序合成适合微信分享的加密 PDF。",
    "aboutClose": "关闭", "menuWindow": "窗口", "menuQueue": "任务队列",
    "btnAddQueue": "加入队列", "btnQueue": "任务队列…",
    "writeLogCheck": "失败时输出报告", "tipLogCheck": "生成失败或有图片被跳过时，在 PDF 所在文件夹自动写出一份 .log 报告；全部成功则不生成。",
    "tipEdge": "长边 = 每张图片缩放后最长一边的像素数。\n\n调大：文字更清晰、画质更好，但文件更大、处理更慢。\n调小：文件更小、微信更好发，但小字可能发糊。\n\n照片/风景建议 1600；单据、截图、带小字的扫描件建议 2000–3000 并调大目标体积。\n目标体积和长边共同决定最终清晰度：软件会先按长边缩放，再在不超目标体积的前提下挑最高画质。",
    "queueTitle": "任务队列 · 多任务并行", "queueColNo": "#", "queueColName": "任务",
    "queueColOut": "输出文件", "queueColStatus": "状态", "queueColProgress": "进度",
    "queueStart": "开始队列", "queueStop": "全部停止", "queueRemove": "移除选中",
    "queueClear": "清空已完成", "queueConcurrency": "同时运行",
    "queueWaiting": "等待中", "queueRunning": "运行中", "queueDone": "完成",
    "queueFailed": "失败", "queueStopped": "已停止",
    "queueAdded": "已加入队列：", "queueAllDone": "队列全部完成",
    "logAddedQueue": "已把当前配置加入任务队列：",
    "logReport": "已生成错误报告：", "logSkipped": "有 %d 张图片被跳过，成品仍已生成",
    "logRepaired": "已自动补齐 %d 张不完整的 JPEG", "logNeedPass": "如压缩包已加密，请先填写密码，再点「读取图片清单」。",
    "statusNeedPass": "请填写压缩包密码后点「读取图片清单」",
    "statusDone": "完成：%d 页 · %@ · 耗时 %@",
    "statusDoneWarn": "完成（有 %d 张跳过）：%d 页 · %@",
    "tipVersion": "当前版本 2.3.1 · 点击菜单栏「关于」查看完整信息",

    // --- Generated file names (follow the interface language) -------------
    "outSuffix": "_压缩加密", "reportSuffix": "_错误报告.log",
    "aboutAppName": "图片合集转加密 PDF",

    // --- Status line & result rows ----------------------------------------
    "statusListOk": "已读取 %d 张图片 · %@",
    "statusInterrupted": "生成已中断（退出码 %d）",
    "logSuccess": "✓ %d 页，%@，轮次 %d，耗时 %@",
    "errReadFailed": "读取失败", "errBuildFailed": "生成失败",
    "bridgeHelperMissing": "找不到内置处理引擎（imgtopdf-helper），请重新解压完整的 App",
    "bridgeLaunchFailed": "启动处理引擎失败：{0}",

    // --- Source kinds (sent as keys by the helper) ------------------------
    "kind.folder": "文件夹", "kind.zip": "ZIP 压缩包", "kind.7z": "7z 压缩包",
    "kind.rar": "RAR 压缩包", "kind.unknown": "未知",

    // --- Engine progress log ----------------------------------------------
    "engine.reading": "正在读取输入…",
    "engine.ordered": "已按清单顺序排列 {0} 张图片",
    "engine.found": "找到 {0} 张图片",
    "engine.workers": "并行处理：{0} 个工作线程",
    "engine.progress": "已处理 {0} / {1} 张",
    "engine.processed": "已处理 {0} / {1} 张，累计约 {2} MB",
    "engine.recompress": "当前 {0} MB，超过目标，自动再压缩一轮（系数 {1}）",
    "engine.repaired": "已自动补齐并保留 {0} 张尾部数据不完整的 JPEG",
    "engine.assembling": "正在合成 PDF…",
    "engine.writing": "正在写出文件…",
    "engine.done": "完成：{0} 页，{1} MB，耗时 {2}",
    "engine.encrypted": "PDF 已使用 AES-256 打开密码加密",
    "engine.plain": "未设置 PDF 密码（明文文件）",
    "engine.skipped": "第 {0} 张「{1}」已跳过：{2}",

    // --- Engine errors -----------------------------------------------------
    "err.outRequired": "请指定输出文件路径",
    "err.orderInvalid": "自定义图片顺序无效：没有可用图片",
    "err.noImages": "没有找到可用图片（支持 JPG/PNG/GIF/BMP/TIFF/WebP）",
    "err.allFailed": "所有图片都无法处理，未生成 PDF（详见错误报告）",
    "err.writeOut": "写入输出文件失败：{0}",
    "err.readImage": "读取「{0}」失败：{1}",
    "err.readImageBody": "读取「{0}」内容失败：{1}",
    "err.inputPath": "找不到输入路径：{0}",
    "err.format": "不支持的压缩格式 {0}；支持 .zip / .7z / .rar 加密压缩包，或直接用图片文件夹",
    "err.zipOpen": "无法打开 ZIP：{0}",
    "err.zipEncrypted": "压缩包已加密，请填写压缩包密码",
    "err.extract": "解压失败（压缩包密码可能不正确）：{0}",
    "err.7zOpen": "无法打开 7z（密码可能不正确）：{0}",
    "err.rarPass": "RAR 压缩包密码不正确",
    "err.rarOpen": "无法打开 RAR（密码可能不正确，或 RAR 使用了不支持的加密方式/分卷缺失）：{0}",
    "err.listImages": "无法读取压缩包内的图片，通常是压缩包密码不正确或文件损坏：{0}",
    "err.pageRange": "图片序号超出范围",
    "err.preview": "无法预览此图片：{0}",
    "err.heic": "HEIC/HEIF 格式不受支持，请先转换成 JPG 或 PNG（原始错误：{0}）",
    "err.avif": "AVIF 格式不受支持，请先转换成 JPG 或 PNG（原始错误：{0}）",
    "err.jpegTruncated": "JPEG 压缩数据不完整（文件尾部缺少少量图像数据），已尝试自动补齐但仍无法解码；建议重新下载该图或先用系统预览另存一次（原始错误：{0}）",
    "err.jpegBroken": "JPEG 文件损坏或使用了不支持的编码方式（原始错误：{0}）",
    "err.webpBroken": "WebP 文件损坏或使用了不支持的编码方式（原始错误：{0}）",
    "err.pngBroken": "PNG 文件损坏（原始错误：{0}）",
    "err.unknownImage": "无法识别的图片格式，或文件已损坏（原始错误：{0}）",
    "err.imageDims": "图片尺寸异常", "err.encode": "图片压缩失败",
    "msg.thumbRepaired": "提示：此图尾部数据不完整，已自动补齐后预览",
    "msg.reportWriteFailed": "无法写入错误报告：{0}",

    // --- Queue: always-available entry points ------------------------------
    "btnStartAsQueue": "加入队列", "queueAddCurrent": "添加当前配置",
    "logAddedQueueBusy": "当前任务运行中，已把新配置加入队列：",
    "logQueueAutoStarted": "队列已自动开始处理新加入的任务",
    "statusQueued": "已加入队列，可继续配置下一个任务",
    "queueHint": "主界面配置好来源与输出后点「加入队列」或「添加当前配置」即可排队；即使已有任务在生成、或队列已开始运行，也能随时补加，新任务会自动接着跑。每个任务独立，失败不影响其他任务。",
    "queueEmpty": "队列为空。先在主界面配置好来源与输出，再点「加入队列」或「添加当前配置」。",
    "logLang": "界面语言已切换：{0}",
    "lang.zh": "中文", "lang.en": "English",
    "demoJobA": "样片合集 A · 8 张", "demoJobB": "客户资料 B · 24 张",
    "demoOutPrefix": "示例任务",
    "logOutRenamed": "输出文件与已有任务重名，已自动改为：",
]

private let EN: [String: String] = [
    "appTitle": "Images → Encrypted PDF",
    "subtitle": "Pick an encrypted archive or a folder · reorder pages · export a WeChat-friendly encrypted PDF",
    "srcLabel": "Source", "srcPlaceholder": "Use “Choose Archive” or “Choose Folder”",
    "btnArchive": "Archive…", "btnFolder": "Folder…", "btnLoad": "Read List",
    "passLabel": "Archive Pass", "passPlaceholder": "7z / ZIP / RAR password (blank if none)",
    "passHintArchive": "Encrypted 7z / ZIP / RAR (incl. RAR5); password stays local, never saved",
    "passHintFolder": "No password needed for folders; JPG / PNG / GIF / BMP / TIFF / WebP",
    "showPass": "Show",
    "listHeader": "Images (drag to reorder = PDF page order)",
    "listHeaderEdited": "Images (custom order = PDF page order)",
    "btnTop": "Top", "btnUp": "Up", "btnDown": "Dn", "btnBottom": "End",
    "colNo": "#", "colName": "File", "colPath": "Location / path in archive", "colSize": "Size",
    "previewHeader": "Preview & location", "previewToggle": "Show preview",
    "previewOff": "Image preview is off\n\nNo image is decoded and no temporary preview file is written.\nLocation details below still work, including copy path and reveal.\n\nTick “Show preview” above, or use the menu\nView → Show Image Preview (⌘⇧P).",
    "offSuffix": "\nPreview off (image content not read)",
    "btnPrev": "← Prev", "btnNext": "Next →", "btnCopyPath": "Copy Path", "btnReveal": "Reveal",
    "pdfPassLabel": "PDF Pass", "pdfPassPlaceholder": "PDF password", "pdfPassHint": "Blank = plain",
    "targetLabel": "Target", "mbLabel": "MB", "edgeLabel": "Edge", "pxLabel": "px",
    "qualityLabel": "Quality",
    "outLabel": "Output", "outPlaceholder": "", "btnChooseOut": "Choose Location…",
    "btnStart": "Generate PDF", "btnStop": "Stop",
    "btnShowResult": "Show in Finder", "btnOpenResult": "Open in Preview",
    "statusReady": "Ready", "statusReading": "Reading archive contents…",
    "statusGenerating": "Generating…", "statusCopied": "Path copied to clipboard", "statusStopped": "Stopped",
    "appSystem": "System", "appLight": "Light", "appDark": "Dark",
    "menuAbout": "About Image to Encrypted PDF", "menuQuit": "Quit",
    "menuEdit": "Edit", "menuUndo": "Undo", "menuRedo": "Redo", "menuCut": "Cut",
    "menuCopy": "Copy", "menuPaste": "Paste", "menuSelectAll": "Select All", "menuView": "View",
    "menuPreview": "Show Image Preview",
    "ctxTop": "Move to Top (page 1)", "ctxUp": "Move Up One Page", "ctxDown": "Move Down One Page",
    "ctxBottom": "Move to Bottom (last page)", "ctxCopy": "Copy Path", "ctxReveal": "Reveal in Finder",
    "ctxRemove": "Remove from List (skip this page)", "ctxRestore": "Restore Default Order & All Images",
    "ctxReverse": "Reverse Order",
    "qPoor": "Poor", "qFair": "Fair", "qMedium": "Medium", "qGood": "Good",
    "qFine": "Excellent", "qBest": "Superb",
    "infoSelect": "Click “Read Image List”, then select a row to preview it.",
    "infoSelectOff": "Preview is off. After reading the list, select a row to see its location.",
    "infoReading": "Reading image %d…",
    "infoArchive": "In archive", "infoDisk": "On disk",
    "infoPage": "%d / %d · ", "infoSize": "File size: ",
    "infoDimensions": "%d × %d · %.1f MB", "infoRotation": ", EXIF orientation fixed (%d)",
    "infoFailed": "Preview failed: ",
    "logReady": "Ready. Everything runs locally; no network, no uploads.",
    "logSelected": "Selected: ", "logListOk": "List loaded: %d images, source type ",
    "logStart": "— Generating: %d images, target %d MB —",
    "logNoPass": "Note: no PDF password set, output is not encrypted",
    "logOver20": "Note: output exceeds 20MB; lower the target size or long edge.",
    "logStop": "Generation stopped by user.",
    "logAppearance": "Appearance changed: ",
    "logPreviewOn": "Image preview enabled",
    "logPreviewOff": "Image preview disabled: no decoding, no temp files; location info still available",
    "logTop": "Moved image %d to the top", "logBottom": "Moved image %d to the bottom",
    "logMove": "Moved image %d to page %d", "logRemove": "Removed image %d, %d remaining",
    "logRestore": "Restored default order and all images", "logReverse": "Order reversed",
    "logDrag": "List order updated; the PDF will follow it",
    "errNoSource": "Choose a source and read the image list first", "errNoOut": "Enter an output file path",
    "errTarget": "Target size must be 1–500 MB", "errEdge": "Long edge must be 400–6000 px",
    "errQuality": "Quality must be 25–95", "errNoSrcShort": "Choose an archive or folder first",
    "pickArchive": "Choose Encrypted Archive", "pickArchiveMsg": "Encrypted .7z / .zip / .rar (incl. RAR5)",
    "pickFolder": "Choose an Image Folder", "pickOut": "Save PDF As",
    "aboutTitle": "About Image to Encrypted PDF", "aboutVersion": "Version",
    "aboutDeveloper": "Developer: aibanana", "aboutLicense": "MIT license · fully offline · nothing is uploaded",
    "aboutDesc": "Turn images in encrypted archives or folders into a WeChat-friendly, password-protected PDF in the order you choose.",
    "aboutClose": "Close", "menuWindow": "Window", "menuQueue": "Task Queue",
    "btnAddQueue": "Add to Queue", "btnQueue": "Task Queue…",
    "writeLogCheck": "Write report on failure", "tipLogCheck": "When a job fails or images are skipped, a .log diagnostic file is written next to the PDF. Nothing is written on a clean run.",
    "tipEdge": "Long edge = the pixel length of the longest side after scaling each image.\n\nLarger: sharper text and better quality, but a bigger file and slower processing.\nSmaller: smaller file, easier to send on WeChat, but small text may blur.\n\nUse 1600 for photos; use 2000–3000 plus a larger target size for receipts, screenshots and scans with fine print.\nTogether with the target size, this decides final sharpness: images are scaled first, then encoded at the highest quality that fits the budget.",
    "queueTitle": "Task Queue · Parallel Jobs", "queueColNo": "#", "queueColName": "Job",
    "queueColOut": "Output", "queueColStatus": "Status", "queueColProgress": "Progress",
    "queueStart": "Start Queue", "queueStop": "Stop All", "queueRemove": "Remove Selected",
    "queueClear": "Clear Finished", "queueConcurrency": "Run at once",
    "queueWaiting": "Waiting", "queueRunning": "Running", "queueDone": "Done",
    "queueFailed": "Failed", "queueStopped": "Stopped",
    "queueAdded": "Added to queue: ", "queueAllDone": "All queued jobs finished",
    "logAddedQueue": "Current job added to the queue: ",
    "logReport": "Error report written: ", "logSkipped": "%d image(s) were skipped; the PDF was still produced",
    "logRepaired": "Repaired %d truncated JPEG file(s)", "logNeedPass": "If the archive is encrypted, enter its password and click “Read List”.",
    "statusNeedPass": "Enter the archive password, then click “Read List”",
    "statusDone": "Done: %d pages · %@ · %@",
    "statusDoneWarn": "Done (%d skipped): %d pages · %@",
    "tipVersion": "Version 2.3.1 · See the About panel for details",

    // --- Generated file names (follow the interface language) -------------
    "outSuffix": "_encrypted", "reportSuffix": "_error_report.log",
    "aboutAppName": "Image to Encrypted PDF",

    // --- Status line & result rows ----------------------------------------
    "statusListOk": "%d images loaded · %@",
    "statusInterrupted": "Generation interrupted (exit code %d)",
    "logSuccess": "✓ %d pages, %@, %d round(s), %@",
    "errReadFailed": "Read failed", "errBuildFailed": "Generation failed",
    "bridgeHelperMissing": "Bundled engine (imgtopdf-helper) is missing. Re-extract the complete app.",
    "bridgeLaunchFailed": "Could not start the engine: {0}",

    // --- Source kinds (sent as keys by the helper) ------------------------
    "kind.folder": "Folder", "kind.zip": "ZIP archive", "kind.7z": "7z archive",
    "kind.rar": "RAR archive", "kind.unknown": "Unknown",

    // --- Engine progress log ----------------------------------------------
    "engine.reading": "Reading input…",
    "engine.ordered": "{0} images arranged in list order",
    "engine.found": "{0} images found",
    "engine.workers": "Parallel processing with {0} workers",
    "engine.progress": "Processed {0} / {1}",
    "engine.processed": "Processed {0} / {1} images, about {2} MB so far",
    "engine.recompress": "{0} MB exceeds the target; recompressing (factor {1})",
    "engine.repaired": "Repaired and kept {0} truncated JPEG file(s)",
    "engine.assembling": "Assembling PDF…",
    "engine.writing": "Writing output file…",
    "engine.done": "Done: {0} pages, {1} MB, in {2}",
    "engine.encrypted": "PDF encrypted with an AES-256 open password",
    "engine.plain": "No PDF password set (plain output)",
    "engine.skipped": "Image {0} “{1}” skipped: {2}",

    // --- Engine errors -----------------------------------------------------
    "err.outRequired": "Specify an output file path",
    "err.orderInvalid": "Custom image order is invalid: no usable images",
    "err.noImages": "No supported images found (JPG/PNG/GIF/BMP/TIFF/WebP)",
    "err.allFailed": "Every image failed; no PDF was produced (see the error report)",
    "err.writeOut": "Could not write the output file: {0}",
    "err.readImage": "Could not read “{0}”: {1}",
    "err.readImageBody": "Could not decode “{0}”: {1}",
    "err.inputPath": "Input path not found: {0}",
    "err.format": "Unsupported archive format {0}; use an encrypted .zip / .7z / .rar or an image folder",
    "err.zipOpen": "Could not open ZIP: {0}",
    "err.zipEncrypted": "This archive is encrypted; enter its password",
    "err.extract": "Extraction failed (the archive password may be wrong): {0}",
    "err.7zOpen": "Could not open 7z (the password may be wrong): {0}",
    "err.rarPass": "Incorrect RAR archive password",
    "err.rarOpen": "Could not open RAR (wrong password, unsupported encryption, or missing volumes): {0}",
    "err.listImages": "Could not read images from the archive (usually a wrong password or a corrupt file): {0}",
    "err.pageRange": "Image index out of range",
    "err.preview": "Could not preview this image: {0}",
    "err.heic": "HEIC/HEIF is not supported; convert to JPG or PNG first (original error: {0})",
    "err.avif": "AVIF is not supported; convert to JPG or PNG first (original error: {0})",
    "err.jpegTruncated": "Incomplete JPEG data (trailing image data is missing); automatic repair was attempted but decoding still failed. Re-download the image or re-save it with Preview (original error: {0})",
    "err.jpegBroken": "Corrupt JPEG or an unsupported encoding (original error: {0})",
    "err.webpBroken": "Corrupt WebP or an unsupported encoding (original error: {0})",
    "err.pngBroken": "Corrupt PNG (original error: {0})",
    "err.unknownImage": "Unrecognised image format, or the file is corrupt (original error: {0})",
    "err.imageDims": "Invalid image dimensions", "err.encode": "Image encoding failed",
    "msg.thumbRepaired": "Note: this image had truncated trailing data; repaired for preview",
    "msg.reportWriteFailed": "Could not write the error report: {0}",

    // --- Queue: always-available entry points ------------------------------
    "btnStartAsQueue": "Add to Queue", "queueAddCurrent": "Add Current Job",
    "logAddedQueueBusy": "A job is already running; added the new configuration to the queue: ",
    "logQueueAutoStarted": "Queue automatically started the newly added job",
    "statusQueued": "Added to the queue; you can configure the next job now",
    "queueHint": "Configure a source and output in the main window, then click “Add to Queue” or “Add Current Job”. You can keep adding jobs even while a conversion is running or the queue has already started; new jobs are picked up automatically. Jobs are independent; one failure does not stop the others.",
    "queueEmpty": "Queue is empty. Configure a source and output in the main window, then click “Add to Queue” or “Add Current Job”.",
    "logLang": "Interface language changed: {0}",
    "lang.zh": "Chinese (Simplified)", "lang.en": "English",
    "demoJobA": "Sample Set A · 8 images", "demoJobB": "Client Files B · 24 images",
    "demoOutPrefix": "demo-job-",
    "logOutRenamed": "Output name clashes with an existing job; renamed to: ",
]

private let STRINGS: [Lang: [String: String]] = [.zh: ZH, .en: EN]

/// One localized string for the active language, falling back to English.
private func L(_ key: String) -> String {
    STRINGS[currentLang]?[key] ?? STRINGS[.en]?[key] ?? key
}

/// Localize a template containing numbered placeholders: {0}, {1}, ...
/// Numbered (rather than positional printf) placeholders let any future
/// language reorder the arguments without touching the code that emits them.
/// Used for structured events sent by the Go helper.
private func LF(_ key: String, _ args: [String] = []) -> String {
    var t = L(key)
    for (i, a) in args.enumerated() {
        t = t.replacingOccurrences(of: "{\(i)}", with: a)
    }
    return t
}

/// Turn a JSON `args` array coming from the helper into plain strings.
private func eventArgs(_ obj: [String: Any]) -> [String] {
    (obj["args"] as? [Any] ?? []).map { "\($0)" }
}

/// Resolve either a structured, localizable event or a legacy plain-text one.
private func eventText(_ obj: [String: Any], fallbackKey: String = "") -> String {
    if let key = obj["key"] as? String, !key.isEmpty {
        return LF(key, eventArgs(obj))
    }
    if let s = obj["message"] as? String, !s.isEmpty { return s }
    return fallbackKey.isEmpty ? "" : L(fallbackKey)
}

// MARK: - Data model

struct ImageItem {
    let index: Int
    let name: String
    let path: String
    let size: Int64
    let sizeText: String
}

// MARK: - Bridge to the Go engine (child process, stdout JSON lines)

final class Bridge {
    static let shared = Bridge()

    let helperURL: URL = {
        if let u = Bundle.main.url(forAuxiliaryExecutable: "imgtopdf-helper") { return u }
        return Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("imgtopdf-helper")
    }()

    @discardableResult
    func run(_ args: [String],
             onEvent: @escaping ([String: Any]) -> Void,
             onExit: @escaping (Int32) -> Void) -> Process? {
        let dbg = ProcessInfo.processInfo.environment["IMGTOPDF_DEBUG"] != nil
        func d(_ s: String) { if dbg { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) } }
        d("BRIDGE start helper=\(helperURL.path) args=\(args)")
        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            onEvent(["type": "error", "key": "bridgeHelperMissing"])
            onExit(-1)
            return nil
        }
        let proc = Process()
        proc.executableURL = helperURL
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        var pending = Data()
        let lock = NSLock()

        func parse(line: String) {
            d("BRIDGE line=\(line.prefix(150))")
            if let data = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                onEvent(obj)
            } else if !line.isEmpty {
                onEvent(["type": "log", "message": line])
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { fh in
            let chunk = fh.availableData
            if chunk.isEmpty { return }
            var lines: [String] = []
            lock.lock()
            pending.append(chunk)
            while let idx = pending.firstIndex(of: 10) {
                let piece = pending.prefix(upTo: idx)
                pending = Data(pending.suffix(from: pending.index(after: idx)))
                if let s = String(data: piece, encoding: .utf8), !s.isEmpty { lines.append(s) }
            }
            lock.unlock()
            for s in lines { parse(line: s) }
        }

        proc.terminationHandler = { p in
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = pipe.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            pending.append(rest)
            let tail = String(data: pending, encoding: .utf8) ?? ""
            pending = Data()
            lock.unlock()
            for s in tail.split(separator: "\n") where !s.isEmpty { parse(line: String(s)) }
            onExit(p.terminationStatus)
        }

        do {
            try proc.run()
            d("BRIDGE launched pid=\(proc.processIdentifier)")
        } catch {
            d("BRIDGE launch FAILED \(error)")
            onEvent(["type": "error", "key": "bridgeLaunchFailed", "args": [error.localizedDescription]])
            onExit(-1)
            return nil
        }
        return proc
    }
}

// MARK: - Views

final class RootView: NSView {
    weak var controller: AppController?
    override func layout() {
        super.layout()
        controller?.layoutAll(bounds)
    }
}

/// A draggable divider between the image list and the preview pane.
final class SplitHandle: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onReset: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let x = bounds.midX - 0.5
        NSRect(x: x, y: 8, width: 1, height: max(0, bounds.height - 16)).fill()
        NSColor.tertiaryLabelColor.setFill()
        let cy = bounds.midY
        for dy in [-6, 0, 6] as [CGFloat] {
            NSRect(x: bounds.midX - 1.5, y: cy + dy - 1.5, width: 3, height: 3).fill()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onReset?(); return }
        guard let win = window else { return }
        var lastX = event.locationInWindow.x
        while true {
            guard let e = win.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if e.type == .leftMouseUp { break }
            let x = e.locationInWindow.x
            onDrag?(x - lastX)
            lastX = x
        }
    }
}

/// A small pill showing the running version right next to the window title.
final class BadgeView: NSView {
    var text: String = UIAppVersionShort { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7)
        NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
        path.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.40).setStroke()
        path.lineWidth = 1
        path.stroke()
        let s = NSAttributedString(string: text, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.controlAccentColor
        ])
        let sz = s.size()
        s.draw(at: NSPoint(x: bounds.midX - sz.width / 2, y: bounds.midY - sz.height / 2))
    }
}

/// Horizontal grip above the log pane; drag vertically to resize the log area.
final class LogResizeHandle: NSView {
    var onDrag: ((CGFloat) -> Void)?
    var onReset: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let y = bounds.midY - 0.5
        NSRect(x: bounds.midX - 26, y: y, width: 52, height: 1).fill()
        NSColor.tertiaryLabelColor.setFill()
        NSRect(x: bounds.midX - 18, y: y + 3, width: 36, height: 1).fill()
        NSRect(x: bounds.midX - 18, y: y - 4, width: 36, height: 1).fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onReset?(); return }
        guard let win = window else { return }
        var lastY = event.locationInWindow.y
        while true {
            guard let e = win.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if e.type == .leftMouseUp { break }
            let y = e.locationInWindow.y
            onDrag?(y - lastY)
            lastY = y
        }
    }
}

// MARK: - Application controller

final class AppController: NSObject, NSApplicationDelegate, NSTableViewDataSource,
                           NSTableViewDelegate, NSMenuDelegate, NSTextFieldDelegate {

    private var window: NSWindow!
    private var root: RootView!

    // Top bar
    private let titleLabel = AppController.label("", size: 19, bold: true)
    private let versionBadge = BadgeView()
    private let subtitle = AppController.label("", size: 12, color: .secondaryLabelColor)
    private let langPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let appearancePopup = NSPopUpButton(frame: .zero, pullsDown: false)

    // Source
    private let srcLabel = AppController.label("", size: 12, bold: true)
    private let srcField = AppController.input("")
    private let btnArchive = AppController.button("")
    private let btnFolder = AppController.button("")
    private let btnLoad = AppController.button("")
    private let passLabel = AppController.label("", size: 12)
    private let archivePass = NSSecureTextField()
    private let archivePassPlain = AppController.input("")
    private let showArchivePass = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let passHint = AppController.label("", size: 11, color: .secondaryLabelColor)
    private let separator = NSBox()

    // List
    private let listHeader = AppController.label("", size: 12, bold: true)
    private let btnTop = AppController.button("")
    private let btnUp = AppController.button("")
    private let btnDown = AppController.button("")
    private let btnBottom = AppController.button("")
    private let tableView = NSTableView()
    private let listScroll = NSScrollView()
    private let splitHandle = SplitHandle()

    // Preview
    private let previewHeader = AppController.label("", size: 12, bold: true)
    private let previewToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let imageView = NSImageView()
    private let previewOffLabel = AppController.wrappingLabel("", size: 12)
    private let infoLabel = AppController.wrappingLabel("", size: 11)
    private let btnPrev = AppController.button("")
    private let btnNext = AppController.button("")
    private let btnCopyPath = AppController.button("")
    private let btnReveal = AppController.button("")

    // Settings
    private let pdfPassLabel = AppController.label("", size: 12)
    private let pdfPass = NSSecureTextField()
    private let pdfPassPlain = AppController.input("")
    private let showPdfPass = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let pdfPassHint = AppController.label("", size: 11, color: .secondaryLabelColor)
    private let targetLabel = AppController.label("", size: 12)
    private let targetField = AppController.input("")
    private let mbLabel = AppController.label("", size: 12)
    private let edgeLabel = AppController.label("", size: 12)
    private let edgeField = AppController.input("")
    private let pxLabel = AppController.label("", size: 12)
    private let qualityLabel = AppController.label("", size: 12)
    private let qualitySlider = NSSlider(frame: .zero)
    private let qualityInfo = AppController.label("", size: 12)
    private let outLabel = AppController.label("", size: 12)
    private let outField = AppController.input("")
    private let btnChooseOut = AppController.button("")

    // Progress / result
    private let progress = NSProgressIndicator()
    private let statusLabel = AppController.label("", size: 12, color: .secondaryLabelColor)
    private let logView = NSTextView()
    private let logScroll = NSScrollView()
    private let logResizeHandle = LogResizeHandle()
    private let writeLogCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let btnStart = AppController.button("")
    private let btnStop = AppController.button("")
    private let btnShowResult = AppController.button("")
    private let btnOpenResult = AppController.button("")
    private let btnAddQueue = AppController.button("")
    private let btnQueue = AppController.button("")

    // State
    private var items: [ImageItem] = []
    private var originalItems: [ImageItem] = []
    private var orderModified = false
    private var sourcePath = ""
    private var sourceIsFolder = false
    private var resultPath: String?
    private var listProc: Process?
    private var thumbProc: Process?
    private var buildProc: Process?
    private var thumbToken = 0
    private var isBuilding = false
    private var activeBuildOut: String?
    private var gotTerminalEvent = false
    private var previewEnabled = true
    private var previewMenuItem: NSMenuItem?
    private var splitRatio: CGFloat = 0.55
    private var appearanceMode = 0   // 0 system, 1 light, 2 dark
    private var logHeight: CGFloat = 96
    private var writeReport = true
    private var aboutWindow: NSWindow?
    private var queueWindow: QueueWindowController?

    // A log line is stored as a renderer, not as rendered text. Switching the
    // interface language re-runs every renderer against the new dictionary,
    // so the whole history changes language with no Chinese left behind.
    private var logEvents: [(text: () -> String, color: NSColor?)] = []
    private var statusRenderer: (() -> String)?
    private var statusColor: NSColor?

    // The output name is generated from the source name plus a localized
    // suffix. We remember what we generated so a language switch can refresh
    // it, but never overwrite a name the user typed or chose by hand.
    private var outNameAuto = false
    private var outNameDir = ""
    private var outNameStem = ""

    private let previewDefaultsKey = "imgtopdf.showImagePreview"
    private let langDefaultsKey = "imgtopdf.language"
    private let appearanceDefaultsKey = "imgtopdf.appearance"
    private let splitDefaultsKey = "imgtopdf.splitRatio"
    private let logHeightDefaultsKey = "imgtopdf.logHeight"
    private let writeReportDefaultsKey = "imgtopdf.writeReport"
    private let rowPasteboardType = NSPasteboard.PasteboardType("local.imgtopdf.imagerow")

    // Localization bindings
    private var labelBindings: [(NSTextField, String)] = []
    private var buttonBindings: [(NSButton, String)] = []
    private var placeholderBindings: [(NSTextField, String)] = []
    private var menuBindings: [(NSMenuItem, String)] = []
    private var contextMenu: NSMenu!

    // Self test
    private var selfTest = false
    private var selfTestStage = 0
    private var selfTestDone = false

    private lazy var tempDir: URL = {
        let u = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("imgtopdf-preview-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    private var isTestRun: Bool {
        let e = ProcessInfo.processInfo.environment
        return e["IMGTOPDF_SELFTEST_SRC"] != nil || e["IMGTOPDF_DEMO_SRC"] != nil
            || e["IMGTOPDF_SELFTEST_NOPREVIEW"] != nil
            || e["IMGTOPDF_I18NTEST"] != nil || e["IMGTOPDF_QUEUETEST"] != nil
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadPreferences()
        buildUI()
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["IMGTOPDF_DEBUG"] != nil {
            let msg = "DEBUG window=\(window.frame) visible=\(window.isVisible) views=\(root.subviews.count) helper=\(Bridge.shared.helperURL.path)\n"
            FileHandle.standardError.write(msg.data(using: .utf8)!)
        }
        let env = ProcessInfo.processInfo.environment
        if let src = env["IMGTOPDF_I18NTEST"] {
            runI18NSelfTest(src)
            return
        }
        if let src = env["IMGTOPDF_QUEUETEST"] {
            runQueueAppendSelfTest(src)
            return
        }
        if let src = env["IMGTOPDF_SELFTEST_SRC"] {
            selfTest = true
            archivePass.stringValue = env["IMGTOPDF_SELFTEST_PASS"] ?? ""
            pdfPass.stringValue = env["IMGTOPDF_SELFTEST_PDFPASS"] ?? ""
            if env["IMGTOPDF_SELFTEST_SHOWPASS"] != nil {
                showArchivePass.state = .on
                archivePassPlain.stringValue = archivePass.stringValue
                archivePass.isHidden = true
                archivePassPlain.isHidden = false
                showPdfPass.state = .on
                pdfPassPlain.stringValue = pdfPass.stringValue
                pdfPass.isHidden = true
                pdfPassPlain.isHidden = false
            }
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: src, isDirectory: &isDir)
            applySource(src, isFolder: exists && isDir.boolValue)
            if let out = env["IMGTOPDF_SELFTEST_OUT"] {
                outNameAuto = false
                outField.stringValue = out
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self, !self.selfTestDone else { return }
                self.selfTestFinish(false, "timeout")
            }
        } else if let src = env["IMGTOPDF_DEMO_SRC"] {
            archivePass.stringValue = env["IMGTOPDF_DEMO_PASS"] ?? ""
            applySource(src, isFolder: false)
            if env["IMGTOPDF_DEMO_ABOUT"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.showAbout() }
            }
            if env["IMGTOPDF_DEMO_QUEUE"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.showDemoQueue() }
            }
            if env["IMGTOPDF_DEMO_I18N"] != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self else { return }
                    currentLang = .en
                    self.applyLanguage()
                    let name = L(currentLang.nameKey)
                    self.log { LF("logLang", [name]) }
                    self.setStatus { L("statusReady") }
                }
            }
        }
    }

    private func loadPreferences() {
        let d = UserDefaults.standard
        if !isTestRun {
            if let s = d.string(forKey: langDefaultsKey) { currentLang = Lang(rawValue: s) ?? .zh }
            if d.object(forKey: appearanceDefaultsKey) != nil { appearanceMode = d.integer(forKey: appearanceDefaultsKey) }
            if d.object(forKey: previewDefaultsKey) != nil { previewEnabled = d.bool(forKey: previewDefaultsKey) }
            if d.object(forKey: splitDefaultsKey) != nil {
                let r = d.double(forKey: splitDefaultsKey)
                if r > 0.25 && r < 0.8 { splitRatio = CGFloat(r) }
            }
            if d.object(forKey: logHeightDefaultsKey) != nil {
                let h = d.double(forKey: logHeightDefaultsKey)
                if h >= 48 && h <= 320 { logHeight = CGFloat(h) }
            }
            if d.object(forKey: writeReportDefaultsKey) != nil {
                writeReport = d.bool(forKey: writeReportDefaultsKey)
            }
        }
        let e = ProcessInfo.processInfo.environment
        if e["IMGTOPDF_SELFTEST_NOPREVIEW"] != nil { previewEnabled = false }
        if e["IMGTOPDF_SELFTEST_LANG"] == "en" { currentLang = .en }
        if let a = e["IMGTOPDF_SELFTEST_APPEARANCE"] {
            appearanceMode = a == "light" ? 1 : (a == "dark" ? 2 : 0)
        }
        if let s = e["IMGTOPDF_SELFTEST_SPLIT"], let v = Double(s), v > 0.28, v < 0.78 {
            splitRatio = CGFloat(v)
        }
        // Demo-only: start with a taller log pane so screenshots can show the
        // draggable log area without synthesising any fake log content.
        if let s = e["IMGTOPDF_DEMO_LOGHEIGHT"], let v = Double(s), v >= 48, v <= 320 {
            logHeight = CGFloat(v)
        }
    }

    private func selfTestFinish(_ ok: Bool, _ detail: String) {
        guard selfTest, !selfTestDone else { return }
        selfTestDone = true
        let state = "SELFTEST state lang=\(currentLang.rawValue) appearance=\(appearanceMode) preview=\(previewEnabled) showpass=\(showPdfPass.state == .on) archivepasslen=\(archivePassword.count) quality=\(Int(qualitySlider.doubleValue.rounded())) split=\(String(format: "%.2f", splitRatio)) items=\(items.count) order=\(items.map { String($0.index) }.joined(separator: "-")) version=\(UIAppVersion) badge=\(versionBadge.text) logHeight=\(Int(logHeight)) writeReport=\(writeReport) edgeTipLen=\(edgeField.toolTip?.count ?? 0) queueJobs=\(queueWindow?.jobCount ?? 0)\n"
        FileHandle.standardError.write(state.data(using: .utf8)!)
        FileHandle.standardError.write("SELFTEST \(ok ? "PASS" : "FAIL"): \(detail)\n".data(using: .utf8)!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        buildProc?.terminate()
        thumbProc?.terminate()
        listProc?.terminate()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Localization / appearance

    private func bind(_ v: NSTextField, _ key: String) { labelBindings.append((v, key)) }
    private func bindButton(_ v: NSButton, _ key: String) { buttonBindings.append((v, key)) }
    private func bindPlaceholder(_ v: NSTextField, _ key: String) { placeholderBindings.append((v, key)) }
    private func bindMenu(_ v: NSMenuItem, _ key: String) { menuBindings.append((v, key)) }

    private func applyLanguage() {
        for (v, k) in labelBindings { v.stringValue = L(k) }
        for (v, k) in buttonBindings { v.title = L(k) }
        for (v, k) in placeholderBindings { v.placeholderString = L(k) }
        for (v, k) in menuBindings { v.title = L(k) }
        let titles = [L("colNo"), L("colName"), L("colPath"), L("colSize")]
        for (i, t) in titles.enumerated() where i < tableView.tableColumns.count {
            let col = tableView.tableColumns[i]
            col.title = t
            col.headerCell.stringValue = t
        }
        tableView.headerView?.needsDisplay = true
        langPopup.removeAllItems()
        langPopup.addItems(withTitles: Lang.allCases.map { L($0.nameKey) })
        langPopup.selectItem(at: Lang.allCases.firstIndex(of: currentLang) ?? 0)
        appearancePopup.removeAllItems()
        appearancePopup.addItems(withTitles: [L("appSystem"), L("appLight"), L("appDark")])
        appearancePopup.selectItem(at: appearanceMode)
        updatePassHint()
        updateListHeader()
        refreshPreviewOffText()
        updateQualityInfo()
        btnTop.toolTip = L("ctxTop"); btnUp.toolTip = L("ctxUp")
        btnDown.toolTip = L("ctxDown"); btnBottom.toolTip = L("ctxBottom")
        for v in [edgeLabel, edgeField, pxLabel] as [NSView] { v.toolTip = L("tipEdge") }
        writeLogCheck.toolTip = L("tipLogCheck")
        versionBadge.toolTip = L("tipVersion")
        window.title = L("appTitle")
        if let w = aboutWindow { w.orderOut(nil); aboutWindow = nil }
        queueWindow?.applyLanguage()
        btnStart.title = L(isBuilding ? "btnStartAsQueue" : "btnStart")
        buildMainMenu()
        refreshDefaultOut()
        renderLog()
        applyStatus()
        if items.isEmpty {
            infoLabel.stringValue = L(previewEnabled ? "infoSelect" : "infoSelectOff")
        } else {
            previewSelected()
        }
    }

    private func refreshPreviewOffText() {
        previewOffLabel.stringValue = L("previewOff")
    }

    private func updatePassHint() {
        passHint.stringValue = L(sourceIsFolder ? "passHintFolder" : "passHintArchive")
    }

    private func updateListHeader() {
        listHeader.stringValue = L(orderModified ? "listHeaderEdited" : "listHeader")
    }

    private func applyAppearance() {
        switch appearanceMode {
        case 1: window.appearance = NSAppearance(named: .aqua)
        case 2: window.appearance = NSAppearance(named: .darkAqua)
        default: window.appearance = nil
        }
        refreshDynamicColors()
    }

    private func refreshDynamicColors() {
        imageView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        previewOffLabel.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.18).cgColor
        root.needsDisplay = true
        splitHandle.needsDisplay = true
    }

    @objc private func langChanged(_ sender: NSPopUpButton) {
        let all = Lang.allCases
        guard sender.indexOfSelectedItem >= 0, sender.indexOfSelectedItem < all.count else { return }
        let next = all[sender.indexOfSelectedItem]
        if next == currentLang { return }
        currentLang = next
        if !isTestRun { UserDefaults.standard.set(currentLang.rawValue, forKey: langDefaultsKey) }
        applyLanguage()
        let switchedTo = L(currentLang.nameKey)
        log { LF("logLang", [switchedTo]) }
    }

    @objc private func appearanceChanged(_ sender: NSPopUpButton) {
        appearanceMode = sender.indexOfSelectedItem
        if !isTestRun { UserDefaults.standard.set(appearanceMode, forKey: appearanceDefaultsKey) }
        applyAppearance()
        let aKey = appearanceMode == 0 ? "appSystem" : (appearanceMode == 1 ? "appLight" : "appDark")
        log { L("logAppearance") + L(aKey) }
    }

    // MARK: - Menu

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        let about = NSMenuItem(title: L("menuAbout"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L("menuQuit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: L("menuEdit"))
        for (title, sel, key) in [
            (L("menuUndo"), Selector(("undo:")), "z"), (L("menuRedo"), Selector(("redo:")), "Z"),
            (L("menuCut"), Selector(("cut:")), "x"), (L("menuCopy"), Selector(("copy:")), "c"),
            (L("menuPaste"), Selector(("paste:")), "v"), (L("menuSelectAll"), Selector(("selectAll:")), "a")
        ] as [(String, Selector, String)] {
            if key == "x" { edit.addItem(NSMenuItem.separator()) }
            edit.addItem(withTitle: title, action: sel, keyEquivalent: key)
        }
        editItem.submenu = edit

        let viewItem = NSMenuItem()
        main.addItem(viewItem)
        let viewMenu = NSMenu(title: L("menuView"))
        let item = NSMenuItem(title: L("menuPreview"), action: #selector(togglePreviewMenu), keyEquivalent: "p")
        item.keyEquivalentModifierMask = [.command, .shift]
        item.target = self
        viewMenu.addItem(item)
        previewMenuItem = item
        viewItem.submenu = viewMenu

        let winItem = NSMenuItem()
        main.addItem(winItem)
        let winMenu = NSMenu(title: L("menuWindow"))
        let q = NSMenuItem(title: L("menuQueue"), action: #selector(showQueue), keyEquivalent: "q")
        q.keyEquivalentModifierMask = [.command, .option]
        q.target = self
        winMenu.addItem(q)
        winItem.submenu = winMenu

        NSApp.mainMenu = main
        syncPreviewMenu()
    }

    // MARK: - About

    @objc private func showAbout() {
        if let w = aboutWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 286),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("aboutTitle")
        w.isReleasedWhenClosed = false
        w.center()
        let root = NSView(frame: w.contentLayoutRect)
        w.contentView = root
        let bw = root.bounds.width
        func line(_ text: String, _ y: CGFloat, _ size: CGFloat, _ bold: Bool = false,
                  _ color: NSColor = .labelColor) {
            let t = AppController.label(text, size: size, bold: bold, color: color)
            t.frame = NSRect(x: 20, y: y, width: bw - 40, height: size + 8)
            t.alignment = .center
            root.addSubview(t)
        }
        line(L("aboutAppName"), 214, 19, true)
        line(UIAppVersionShort + "  ·  " + L("aboutVersion") + " " + UIAppVersion, 184, 12, false, .secondaryLabelColor)
        line(L("aboutDeveloper"), 154, 13, true)
        let desc = AppController.wrappingLabel(L("aboutDesc"), size: 11)
        desc.alignment = .center
        desc.frame = NSRect(x: 28, y: 88, width: bw - 56, height: 38)
        root.addSubview(desc)
        line(L("aboutLicense"), 64, 11, false, .secondaryLabelColor)
        let btn = AppController.button(L("aboutClose"))
        btn.frame = NSRect(x: bw / 2 - 62, y: 18, width: 124, height: 28)
        btn.target = self
        btn.action = #selector(closeAbout)
        root.addSubview(btn)
        aboutWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeAbout() { aboutWindow?.orderOut(nil) }

    @objc private func toggleWriteReport(_ sender: NSButton) {
        writeReport = sender.state == .on
        if !isTestRun { UserDefaults.standard.set(writeReport, forKey: writeReportDefaultsKey) }
    }

    @objc private func passEntered() {
        if !sourcePath.isEmpty && !archivePassword.isEmpty { loadList() }
    }

    // MARK: - Queue actions

    // MARK: - Hidden self-tests for v2.3.1

    /// Prove that switching to English re-localizes every visible surface,
    /// including the whole log history written while the UI was in Chinese.
    private func runI18NSelfTest(_ src: String) {
        currentLang = .zh
        applyLanguage()
        // Open the queue window in Chinese first, so the switch also has to
        // re-localize a window that was already on screen.
        let q = ensureQueueWindow()
        applySource(src, isFolder: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            let before = self.outField.stringValue
            let beforeOK = before.hasSuffix("_压缩加密.pdf")
            currentLang = .en
            self.applyLanguage()
            let switchedTo = L(currentLang.nameKey)
            self.log { LF("logLang", [switchedTo]) }
            let after = self.outField.stringValue
            let afterOK = after.hasSuffix("_encrypted.pdf")

            var dump = "OUT_BEFORE=\(before)\nOUT_AFTER=\(after)\n"
            dump += "WINDOW=\(self.window.title)\nSTATUS=\(self.statusLabel.stringValue)\n"
            dump += "LANGPICK=\(self.langPopup.itemTitles.joined(separator: "|"))\n"
            dump += "PREVIEWOFF=\(self.previewOffLabel.stringValue)\n"
            dump += "INFOLABEL=\(self.infoLabel.stringValue)\n"
            dump += "QUALITYINFO=\(self.qualityInfo.stringValue)\n"
            for (v, _) in self.labelBindings { dump += "LABEL=\(v.stringValue)\n" }
            for (v, _) in self.buttonBindings { dump += "BUTTON=\(v.title)\n" }
            for (v, _) in self.placeholderBindings { dump += "PLACEHOLDER=\(v.placeholderString ?? "")\n" }
            for c in self.tableView.tableColumns {
                dump += "COL=\(c.headerCell.stringValue)\n"
            }
            dump += "QUEUE=\(q.visibleStrings())\n"
            for item in NSApp.mainMenu?.items ?? [] { dump += "MENU=\(item.title)\n" }
            for e in self.logEvents { dump += "LOG=\(e.text())\n" }
            FileHandle.standardError.write(("I18NDUMP\n" + dump + "I18NEND\n").data(using: .utf8)!)

            let visible = dump.components(separatedBy: "\n")
                .filter { !$0.hasPrefix("OUT_BEFORE=") }.joined(separator: "\n")
            let cjk = visible.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
            let ok = beforeOK && afterOK && !cjk
            FileHandle.standardError.write("I18NTEST \(ok ? "PASS" : "FAIL"): before=\(beforeOK) after=\(afterOK) cjkAfterSwitch=\(cjk)\n".data(using: .utf8)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
        }
    }

    /// Append a job after the queue has started and verify it is scheduled
    /// automatically. The old code left such jobs in "Waiting" forever.
    private func runQueueAppendSelfTest(_ src: String) {
        let base = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("imgtopdf-qappend-\(Int(Date().timeIntervalSince1970 * 1000))")
        try? FileManager.default.createDirectory(atPath: base, withIntermediateDirectories: true)
        func jobArgs(_ out: String) -> [String] {
            ["build", "--src", src, "--out", out, "--target-mb", "20",
             "--max-edge", "1200", "--quality", "75", "--lang", "en"]
        }
        let q = ensureQueueWindow()
        let a = (base as NSString).appendingPathComponent("a.pdf")
        q.addJob(name: "A", out: a, args: jobArgs(a))
        q.startQueue()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let b = (base as NSString).appendingPathComponent("b.pdf")
            let statesBefore = q.statusLines()
            q.addJob(name: "B", out: b, args: jobArgs(b))
            FileHandle.standardError.write("QAPPEND added B while queue active: before=\(statesBefore) after=\(q.statusLines())\n".data(using: .utf8)!)
        }
        let deadline = Date().addingTimeInterval(45)
        func poll() {
            let states = q.statusLines()
            let b = (base as NSString).appendingPathComponent("b.pdf")
            let done = states.count == 2 && states.allSatisfy { $0 == "done" }
            let failed = states.count == 2 && states.allSatisfy { $0 == "done" || $0 == "failed" }
            if done {
                let okA = FileManager.default.fileExists(atPath: a)
                let okB = FileManager.default.fileExists(atPath: b)
                FileHandle.standardError.write("QAPPENDTEST \(okA && okB ? "PASS" : "FAIL"): A=\(okA) B=\(okB) states=\(states)\n".data(using: .utf8)!)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            } else if failed || Date() > deadline {
                FileHandle.standardError.write("QAPPENDTEST FAIL: states=\(states) timedOut=\(Date() > deadline)\n".data(using: .utf8)!)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: poll)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: poll)
    }

    private func ensureQueueWindow() -> QueueWindowController {
        if let q = queueWindow { return q }
        let q = QueueWindowController()
        q.onAddCurrent = { [weak self] in self?.addToQueue() }
        q.setLogSink { [weak self] render in
            self?.log(render)
            if self?.selfTest == true {
                FileHandle.standardError.write("SELFTEST QUEUELOG \(render())\n".data(using: .utf8)!)
            }
        }
        q.onAllDone = { [weak self] ok in
            guard let self, self.selfTest else { return }
            self.selfTestFinish(ok, "parallel queue jobs")
        }
        queueWindow = q
        return q
    }

    /// Hidden self-test: enqueue two independent jobs and run them in parallel.
    private func runQueueSelfTest() {
        guard let spec = currentBuildArgs() else {
            selfTestFinish(false, "queue: invalid form")
            return
        }
        let q = ensureQueueWindow()
        let base = (spec.out as NSString).deletingPathExtension
        for n in 1...2 {
            let out = "\(base)_q\(n).pdf"
            var args = spec.args
            if let i = args.firstIndex(of: "--out") { args[i + 1] = out }
            if let i = args.firstIndex(of: "--error-log") {
                args[i + 1] = (out as NSString).deletingPathExtension + L("reportSuffix")
            }
            q.addJob(name: "selftest-job-\(n)", out: out, args: args)
        }
        logRaw("SELFTEST queue: 2 jobs added, starting parallel run")
        q.startQueue()
    }

    @objc private func showQueue() { ensureQueueWindow().show() }

    /// Demo-only: prefill the queue with two pending jobs so documentation
    /// screenshots show real rows instead of an empty table. Nothing is run.
    private func showDemoQueue() {
        let q = ensureQueueWindow()
        q.show()
        let dir = (sourcePath as NSString).deletingLastPathComponent
        for (n, label) in [(1, L("demoJobA")), (2, L("demoJobB"))] {
            let out = (dir as NSString).appendingPathComponent(L("demoOutPrefix") + "\(n).pdf")
            q.addJob(name: label, out: out, args: ["build", "--src", sourcePath, "--out", out])
        }
    }

    /// Enqueue whatever is currently configured. Available at any time:
    /// from the small button, from the queue window, and — while a conversion
    /// is running — from the primary button, which becomes "Add to Queue".
    @objc private func addToQueue() {
        guard var spec = currentBuildArgs(reportStatus: !isBuilding) else { return }
        let q = ensureQueueWindow()
        var reserved = Set<String>()
        if isBuilding, let running = activeBuildOut { reserved.insert(running) }
        let fixed = q.uniqueOutput(spec.out, extra: reserved)
        if fixed != spec.out {
            var args = spec.args
            if let i = args.firstIndex(of: "--out") { args[i + 1] = fixed }
            if let i = args.firstIndex(of: "--error-log") {
                args[i + 1] = (fixed as NSString).deletingPathExtension + L("reportSuffix")
            }
            spec = BuildSpec(args: args, out: fixed)
            log { L("logOutRenamed") + (fixed as NSString).lastPathComponent }
        }
        let name = (sourcePath as NSString).lastPathComponent
        q.addJob(name: name, out: spec.out, args: spec.args)
        if isBuilding {
            log { L("logAddedQueueBusy") + name }
        } else {
            log { L("logAddedQueue") + name }
        }
        q.show()
    }

    // MARK: - Widget factories

    static func label(_ text: String, size: CGFloat, bold: Bool = false,
                              color: NSColor = .labelColor) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        t.textColor = color
        t.lineBreakMode = .byTruncatingTail
        return t
    }

    static func wrappingLabel(_ text: String, size: CGFloat) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: text)
        t.font = .systemFont(ofSize: size)
        t.textColor = .secondaryLabelColor
        t.lineBreakMode = .byWordWrapping
        return t
    }

    static func input(_ placeholder: String) -> NSTextField {
        let t = NSTextField()
        t.placeholderString = placeholder
        t.font = .systemFont(ofSize: 12)
        t.bezelStyle = .roundedBezel
        t.isEditable = true
        t.isSelectable = true
        t.lineBreakMode = .byTruncatingHead
        return t
    }

    static func button(_ title: String) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .rounded
        b.font = .systemFont(ofSize: 12)
        return b
    }

    private func styleSecure(_ f: NSSecureTextField) {
        f.font = .systemFont(ofSize: 12)
        f.bezelStyle = .roundedBezel
        f.isEditable = true
        f.isSelectable = true
    }

    // MARK: - UI construction

    private func buildUI() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 880),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = L("aboutAppName")
        window.minSize = NSSize(width: 1080, height: 820)
        window.center()
        root = RootView(frame: window.contentLayoutRect)
        root.controller = self
        window.contentView = root

        let all: [NSView] = [
            titleLabel, versionBadge, subtitle, langPopup, appearancePopup,
            srcLabel, srcField, btnArchive, btnFolder, btnLoad,
            passLabel, archivePass, archivePassPlain, showArchivePass, passHint, separator,
            listHeader, btnTop, btnUp, btnDown, btnBottom, listScroll, splitHandle,
            previewHeader, previewToggle, imageView, previewOffLabel, infoLabel,
            btnPrev, btnNext, btnCopyPath, btnReveal,
            pdfPassLabel, pdfPass, pdfPassPlain, showPdfPass, pdfPassHint,
            targetLabel, targetField, mbLabel, edgeLabel, edgeField, pxLabel,
            qualityLabel, qualitySlider, qualityInfo,
            outLabel, outField, btnChooseOut,
            progress, statusLabel, logScroll, logResizeHandle, writeLogCheck,
            btnStart, btnStop, btnShowResult, btnOpenResult, btnAddQueue, btnQueue
        ]
        for v in all { v.translatesAutoresizingMaskIntoConstraints = true; root.addSubview(v) }

        // Bindings (applied by applyLanguage below)
        bind(titleLabel, "appTitle"); bind(subtitle, "subtitle")
        bind(srcLabel, "srcLabel"); bind(passLabel, "passLabel")
        bind(previewHeader, "previewHeader")
        bind(pdfPassLabel, "pdfPassLabel"); bind(pdfPassHint, "pdfPassHint")
        bind(targetLabel, "targetLabel"); bind(mbLabel, "mbLabel")
        bind(edgeLabel, "edgeLabel"); bind(pxLabel, "pxLabel")
        bind(qualityLabel, "qualityLabel"); bind(outLabel, "outLabel")
        for (b, k) in [(btnArchive, "btnArchive"), (btnFolder, "btnFolder"), (btnLoad, "btnLoad"),
                       (btnTop, "btnTop"), (btnUp, "btnUp"), (btnDown, "btnDown"), (btnBottom, "btnBottom"),
                       (btnPrev, "btnPrev"), (btnNext, "btnNext"), (btnCopyPath, "btnCopyPath"),
                       (btnReveal, "btnReveal"), (btnChooseOut, "btnChooseOut"),
                       (btnStart, "btnStart"), (btnStop, "btnStop"),
                       (btnShowResult, "btnShowResult"), (btnOpenResult, "btnOpenResult"),
                       (btnAddQueue, "btnAddQueue"), (btnQueue, "btnQueue"),
                       (writeLogCheck, "writeLogCheck"),
                       (previewToggle, "previewToggle"), (showArchivePass, "showPass"),
                       (showPdfPass, "showPass")] { bindButton(b, k) }
        bindPlaceholder(srcField, "srcPlaceholder")
        bindPlaceholder(archivePass, "passPlaceholder")
        bindPlaceholder(pdfPass, "pdfPassPlaceholder")
        bindPlaceholder(outField, "outPlaceholder")

        srcField.isEditable = false
        srcField.isSelectable = true
        outField.isEditable = true
        outField.delegate = self
        styleSecure(archivePass)
        styleSecure(pdfPass)
        targetField.stringValue = "20"
        edgeField.stringValue = "1600"
        statusLabel.stringValue = L("statusReady")

        versionBadge.toolTip = L("tipVersion")
        versionBadge.text = UIAppVersionShort
        writeLogCheck.state = writeReport ? .on : .off
        writeLogCheck.font = .systemFont(ofSize: 11)
        writeLogCheck.toolTip = L("tipLogCheck")
        writeLogCheck.target = self
        writeLogCheck.action = #selector(toggleWriteReport(_:))
        for v in [edgeLabel, edgeField, pxLabel] as [NSView] { v.toolTip = L("tipEdge") }
        archivePass.target = self; archivePass.action = #selector(passEntered)
        archivePassPlain.target = self; archivePassPlain.action = #selector(passEntered)

        // Top bar
        langPopup.target = self; langPopup.action = #selector(langChanged(_:))
        langPopup.font = .systemFont(ofSize: 12)
        appearancePopup.target = self; appearancePopup.action = #selector(appearanceChanged(_:))
        appearancePopup.font = .systemFont(ofSize: 12)

        // Buttons
        let actions: [(NSButton, Selector)] = [
            (btnArchive, #selector(pickArchive)), (btnFolder, #selector(pickFolder)),
            (btnLoad, #selector(loadList)), (btnTop, #selector(moveTop)),
            (btnUp, #selector(moveUp)), (btnDown, #selector(moveDown)),
            (btnBottom, #selector(moveBottom)), (btnPrev, #selector(prevImage)),
            (btnNext, #selector(nextImage)), (btnCopyPath, #selector(copyPath)),
            (btnReveal, #selector(revealSource)), (btnChooseOut, #selector(chooseOut)),
            (btnStart, #selector(startBuild)), (btnStop, #selector(stopBuild)),
            (btnShowResult, #selector(showResult)), (btnOpenResult, #selector(openResult)),
            (btnAddQueue, #selector(addToQueue)), (btnQueue, #selector(showQueue))
        ]
        for (b, a) in actions { b.target = self; b.action = a }
        btnStart.keyEquivalent = "\r"
        btnStart.contentTintColor = .controlAccentColor
        for b in [btnTop, btnUp, btnDown, btnBottom] { b.font = .systemFont(ofSize: 11) }
        btnTop.toolTip = L("ctxTop"); btnUp.toolTip = L("ctxUp")
        btnDown.toolTip = L("ctxDown"); btnBottom.toolTip = L("ctxBottom")

        showArchivePass.target = self; showArchivePass.action = #selector(toggleArchivePass(_:))
        showPdfPass.target = self; showPdfPass.action = #selector(togglePdfPass(_:))
        showArchivePass.font = .systemFont(ofSize: 11)
        showPdfPass.font = .systemFont(ofSize: 11)
        archivePassPlain.isHidden = true
        pdfPassPlain.isHidden = true

        previewToggle.target = self; previewToggle.action = #selector(togglePreviewButton(_:))
        previewToggle.font = .systemFont(ofSize: 11)
        previewToggle.state = previewEnabled ? .on : .off

        // Table
        tableView.rowHeight = 24
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = false
        tableView.dataSource = self
        tableView.delegate = self
        for (id, name, width) in [("no", "colNo", 36), ("name", "colName", 148),
                                  ("path", "colPath", 240), ("size", "colSize", 74)] {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            c.title = L(name)
            c.width = CGFloat(width)
            c.minWidth = 38
            c.resizingMask = [.autoresizingMask, .userResizingMask]
            tableView.addTableColumn(c)
        }
        tableView.registerForDraggedTypes([rowPasteboardType])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        buildContextMenu()
        listScroll.documentView = tableView
        listScroll.hasVerticalScroller = true
        listScroll.borderType = .bezelBorder

        // Split handle
        splitHandle.onDrag = { [weak self] dx in
            guard let self else { return }
            let w = self.root.bounds.width - 44
            self.splitRatio = min(max(self.splitRatio + dx / max(1, w), 0.28), 0.78)
            self.layoutAll(self.root.bounds)
        }
        splitHandle.onReset = { [weak self] in
            guard let self else { return }
            self.splitRatio = 0.55
            self.layoutAll(self.root.bounds)
            if !self.isTestRun {
                UserDefaults.standard.set(0.55, forKey: self.splitDefaultsKey)
            }
        }

        // Preview
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.image = nil
        previewOffLabel.alignment = .center
        previewOffLabel.textColor = .secondaryLabelColor
        previewOffLabel.font = .systemFont(ofSize: 12, weight: .medium)
        previewOffLabel.wantsLayer = true
        previewOffLabel.layer?.cornerRadius = 6

        // Quality slider
        qualitySlider.minValue = 25
        qualitySlider.maxValue = 95
        qualitySlider.doubleValue = 82
        qualitySlider.isContinuous = true
        qualitySlider.target = self
        qualitySlider.action = #selector(qualityChanged(_:))
        if let q = ProcessInfo.processInfo.environment["IMGTOPDF_SELFTEST_QUALITY"],
           let v = Double(q), v >= 25, v <= 95 { qualitySlider.doubleValue = v }
        updateQualityInfo()

        // Progress + log
        progress.style = .bar
        progress.minValue = 0
        progress.maxValue = 100
        progress.doubleValue = 0
        progress.isIndeterminate = false
        logView.frame = NSRect(x: 0, y: 0, width: 800, height: 56)
        logView.isEditable = false
        logView.isSelectable = true
        logView.isVerticallyResizable = true
        logView.autoresizingMask = [.width]
        logView.textContainer?.containerSize = NSSize(width: 800, height: 1.0e7)
        logView.textContainer?.widthTracksTextView = true
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.textColor = .labelColor
        logView.backgroundColor = .textBackgroundColor
        logScroll.documentView = logView
        logScroll.hasVerticalScroller = true
        logScroll.borderType = .bezelBorder
        logResizeHandle.onDrag = { [weak self] dy in
            guard let self else { return }
            self.logHeight = min(max(self.logHeight + dy, 48), 320)
            self.layoutAll(self.root.bounds)
            if !self.isTestRun {
                UserDefaults.standard.set(Double(self.logHeight), forKey: self.logHeightDefaultsKey)
            }
        }
        logResizeHandle.onReset = { [weak self] in
            guard let self else { return }
            self.logHeight = 96
            self.layoutAll(self.root.bounds)
            if !self.isTestRun { UserDefaults.standard.set(96.0, forKey: self.logHeightDefaultsKey) }
        }

        separator.boxType = .separator
        btnStop.isEnabled = false
        btnShowResult.isEnabled = false
        btnOpenResult.isEnabled = false
        setEnabledPreviewButtons(false)

        applyLanguage()
        applyAppearance()
        applyPreviewVisibility()
        window.makeKeyAndOrderFront(nil)
        layoutAll(root.bounds)
        log { L("logReady") }
    }

    private func buildContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let entries: [(String, Selector)] = [
            ("ctxTop", #selector(moveTop)), ("ctxUp", #selector(moveUp)),
            ("ctxDown", #selector(moveDown)), ("ctxBottom", #selector(moveBottom)),
            ("ctxCopy", #selector(copyPath)), ("ctxReveal", #selector(revealSource)),
            ("ctxRemove", #selector(removeSelected)), ("ctxReverse", #selector(reverseOrder)),
            ("ctxRestore", #selector(restoreOrder))
        ]
        var bindings: [(NSMenuItem, String)] = []
        for (i, e) in entries.enumerated() {
            if i == 4 || i == 6 || i == 8 { menu.addItem(NSMenuItem.separator()) }
            let item = NSMenuItem(title: L(e.0), action: e.1, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            bindings.append((item, e.0))
        }
        menuBindings = bindings
        contextMenu = menu
        tableView.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let row = tableView.clickedRow
        if row >= 0 && row != selectedRow {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        let valid = row >= 0 && row < items.count
        let n = items.count
        for item in menu.items {
            guard let key = menuBindings.first(where: { $0.0 === item })?.1 else { continue }
            switch key {
            case "ctxTop", "ctxUp": item.isEnabled = valid && row > 0
            case "ctxDown", "ctxBottom": item.isEnabled = valid && row < n - 1
            case "ctxCopy", "ctxRemove", "ctxReveal": item.isEnabled = valid
            case "ctxRestore": item.isEnabled = !originalItems.isEmpty
            default: item.isEnabled = valid
            }
        }
    }

    // MARK: - Layout

    func layoutAll(_ b: NSRect) {
        let pad: CGFloat = 22
        let cw = b.width - pad * 2
        var y = b.height - pad

        func put(_ v: NSView, _ x: CGFloat, _ yy: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            v.frame = NSRect(x: x, y: yy, width: max(1, w), height: h)
        }

        put(titleLabel, pad, y - 26, 300, 24)
        put(versionBadge, pad + 306, y - 25, 52, 22)
        put(langPopup, b.width - pad - 226, y - 27, 100, 25)
        put(appearancePopup, b.width - pad - 118, y - 27, 118, 25)
        y -= 32
        put(subtitle, pad, y - 17, cw, 17); y -= 30
        put(srcLabel, pad, y - 17, 100, 17); y -= 21

        let rowH: CGFloat = 28
        let gap: CGFloat = 8
        let bw: CGFloat = 116
        let fieldW = cw - 3 * (bw + gap)
        put(srcField, pad, y - rowH, fieldW, rowH)
        put(btnArchive, pad + fieldW + gap, y - rowH, bw, rowH)
        put(btnFolder, pad + fieldW + gap * 2 + bw, y - rowH, bw, rowH)
        put(btnLoad, pad + fieldW + gap * 3 + bw * 2, y - rowH, bw, rowH)
        y -= rowH + 12

        put(passLabel, pad, y - 21, 92, 18)
        put(archivePass, pad + 96, y - 26, 250, 26)
        put(archivePassPlain, pad + 96, y - 26, 250, 26)
        put(showArchivePass, pad + 352, y - 24, 78, 22)
        put(passHint, pad + 436, y - 20, cw - 436, 18)
        y -= 34
        put(separator, pad, y - 2, cw, 5); y -= 14

        // Main area: list | draggable handle | preview
        let bottomBlock: CGFloat = 168 + logHeight
        let mainH = max(190, y - bottomBlock - pad)
        let mainY = y - mainH
        let handleW: CGFloat = 10
        let sideGap: CGFloat = 7
        let usable = cw - handleW - 2 * sideGap
        let leftW = max(300, usable * splitRatio)
        let rightW = max(220, usable - leftW)
        let rightX = pad + leftW + handleW + 2 * sideGap

        let moveW: CGFloat = 50
        put(listHeader, pad, mainY + mainH - 18, max(120, leftW - 4 * (moveW + 4) - 8), 18)
        for (i, btn) in [btnTop, btnUp, btnDown, btnBottom].enumerated() {
            let offset: CGFloat = CGFloat(4 - i) * (moveW + 4)
            put(btn, pad + leftW - offset + 4, mainY + mainH - 21, moveW, 22)
        }
        put(listScroll, pad, mainY, leftW, mainH - 24)
        put(splitHandle, pad + leftW + sideGap, mainY, handleW, mainH - 24)

        put(previewHeader, rightX, mainY + mainH - 18, max(120, rightW - 142), 18)
        put(previewToggle, rightX + rightW - 136, mainY + mainH - 21, 136, 22)
        let infoH: CGFloat = 52
        let btnRowH: CGFloat = 26
        let previewH = max(60, mainH - 24 - infoH - btnRowH - 12)
        put(imageView, rightX, mainY + infoH + btnRowH + 8, rightW, previewH)
        put(previewOffLabel, rightX, mainY + infoH + btnRowH + 8, rightW, previewH)
        put(infoLabel, rightX, mainY + btnRowH + 4, rightW, infoH - 4)
        let pbtnW = (rightW - 3 * 6) / 4
        put(btnPrev, rightX, mainY, pbtnW, btnRowH)
        put(btnNext, rightX + pbtnW + 6, mainY, pbtnW, btnRowH)
        put(btnCopyPath, rightX + (pbtnW + 6) * 2, mainY, pbtnW, btnRowH)
        put(btnReveal, rightX + (pbtnW + 6) * 3, mainY, pbtnW, btnRowH)

        y = mainY - 16

        // Settings row A
        put(pdfPassLabel, pad, y - 21, 96, 18)
        put(pdfPass, pad + 100, y - 26, 168, 26)
        put(pdfPassPlain, pad + 100, y - 26, 168, 26)
        put(showPdfPass, pad + 274, y - 24, 68, 22)
        put(pdfPassHint, pad + 348, y - 21, 96, 18)
        put(targetLabel, pad + 452, y - 21, 52, 18)
        put(targetField, pad + 508, y - 26, 48, 26)
        put(mbLabel, pad + 560, y - 21, 24, 18)
        put(edgeLabel, pad + 590, y - 21, 40, 18)
        put(edgeField, pad + 634, y - 26, 58, 26)
        put(pxLabel, pad + 696, y - 21, 22, 18)
        put(qualityLabel, pad + 728, y - 21, 48, 18)
        put(qualitySlider, pad + 780, y - 26, 134, 26)
        put(qualityInfo, pad + 920, y - 21, 156, 18)
        y -= 38

        // Settings row B
        put(outLabel, pad, y - 21, 66, 18)
        put(outField, pad + 70, y - 26, cw - 70 - 140, 26)
        put(btnChooseOut, b.width - pad - 132, y - 26, 132, 26)
        y -= 38

        put(progress, pad, y - 12, cw * 0.36, 14)
        put(statusLabel, pad + cw * 0.36 + 12, y - 15, cw * 0.40 - 12, 18)
        put(writeLogCheck, b.width - pad - 190, y - 16, 190, 20)
        y -= 24
        put(logResizeHandle, pad, y + 4, cw, 8)
        put(logScroll, pad, y - logHeight, cw, logHeight)
        y -= logHeight + 10

        let rbw: CGFloat = 150
        put(btnStart, pad, y - 28, rbw, 28)
        put(btnStop, pad + rbw + 8, y - 28, 76, 28)
        put(btnShowResult, pad + rbw + 92, y - 28, 150, 28)
        put(btnOpenResult, pad + rbw + 250, y - 28, 140, 28)
        put(btnAddQueue, pad + rbw + 400, y - 28, 120, 28)
        put(btnQueue, pad + rbw + 528, y - 28, 120, 28)
    }

    // MARK: - File pickers

    @objc private func pickArchive() {
        let panel = NSOpenPanel()
        panel.title = L("pickArchive")
        panel.message = L("pickArchiveMsg")
        panel.allowedFileTypes = ["7z", "zip", "rar", "ZIP", "7Z", "RAR"]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let u = panel.url else { return }
        applySource(u.path, isFolder: false)
    }

    @objc private func pickFolder() {
        let panel = NSOpenPanel()
        panel.title = L("pickFolder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let u = panel.url else { return }
        applySource(u.path, isFolder: true)
    }

    private func applySource(_ path: String, isFolder: Bool) {
        sourcePath = path
        sourceIsFolder = isFolder
        srcField.stringValue = path
        archivePass.isEnabled = !isFolder
        archivePassPlain.isEnabled = !isFolder
        showArchivePass.isEnabled = !isFolder
        updatePassHint()
        generateDefaultOut(for: path)
        items = []
        originalItems = []
        orderModified = false
        updateListHeader()
        tableView.reloadData()
        imageView.image = nil
        infoLabel.stringValue = L(previewEnabled ? "infoSelect" : "infoSelectOff")
        setEnabledPreviewButtons(false)
        log { L("logSelected") + path }
        // Do not fire an empty-password read on an encrypted archive: that
        // produced a misleading "password required" error in the log right
        // after choosing a file, before the user had time to type anything.
        if sourceIsFolder || !archivePassword.isEmpty || isTestRun {
            loadList()
        } else {
            setStatus { L("statusNeedPass") }
            log { L("logNeedPass") }
        }
    }

    @objc private func chooseOut() {
        let panel = NSSavePanel()
        panel.title = L("pickOut")
        panel.nameFieldStringValue = (outField.stringValue as NSString).lastPathComponent
        panel.allowedFileTypes = ["pdf"]
        guard panel.runModal() == .OK, let u = panel.url else { return }
        outNameAuto = false
        outField.stringValue = u.path
    }

    // MARK: - Localized default output name

    /// Refresh the suggested output name from the source name. Only runs while
    /// the field still holds a generated value, never one the user typed.
    private func refreshDefaultOut() {
        guard outNameAuto, !outNameStem.isEmpty else { return }
        outField.stringValue = (outNameDir as NSString)
            .appendingPathComponent(outNameStem + L("outSuffix") + ".pdf")
    }

    private func generateDefaultOut(for path: String) {
        outNameDir = (path as NSString).deletingLastPathComponent
        outNameStem = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        outNameAuto = true
        refreshDefaultOut()
    }

    /// Programmatic `stringValue` assignments do not fire this delegate
    /// callback, so it marks only genuine user edits as "keep my name".
    func controlTextDidChange(_ obj: Notification) {
        guard let f = obj.object as? NSTextField, f === outField else { return }
        outNameAuto = false
    }

    // MARK: - List

    private var archivePassword: String {
        showArchivePass.state == .on ? archivePassPlain.stringValue : archivePass.stringValue
    }

    private var pdfPassword: String {
        showPdfPass.state == .on ? pdfPassPlain.stringValue : pdfPass.stringValue
    }

    @objc private func toggleArchivePass(_ sender: NSButton) {
        if sender.state == .on {
            archivePassPlain.stringValue = archivePass.stringValue
        } else {
            archivePass.stringValue = archivePassPlain.stringValue
        }
        archivePass.isHidden = sender.state == .on
        archivePassPlain.isHidden = sender.state == .off
    }

    @objc private func togglePdfPass(_ sender: NSButton) {
        if sender.state == .on {
            pdfPassPlain.stringValue = pdfPass.stringValue
        } else {
            pdfPass.stringValue = pdfPassPlain.stringValue
        }
        pdfPass.isHidden = sender.state == .on
        pdfPassPlain.isHidden = sender.state == .off
    }

    @objc private func loadList() {
        guard !sourcePath.isEmpty else { setStatus({ L("errNoSrcShort") }, color: .systemRed); return }
        listProc?.terminate()
        if selfTest {
            FileHandle.standardError.write("SELFTEST loadList src=\(sourcePath) passLen=\(archivePassword.count) ext=\((sourcePath as NSString).pathExtension)\n".data(using: .utf8)!)
        }
        setStatus { L("statusReading") }
        btnLoad.isEnabled = false
        let src = sourcePath
        let pass = archivePassword
        listProc = Bridge.shared.run(["list", "--src", src, "--archive-pass", pass],
                                     onEvent: { [weak self] obj in
                                         DispatchQueue.main.async { self?.handleListEvent(obj) }
                                     },
                                     onExit: { [weak self] _ in
                                         DispatchQueue.main.async { self?.btnLoad.isEnabled = true }
                                     })
    }

    private func handleListEvent(_ obj: [String: Any]) {
        let type = obj["type"] as? String ?? ""
        if type == "list" {
            let raw = obj["items"] as? [[String: Any]] ?? []
            items = raw.compactMap { d in
                guard let idx = d["index"] as? Int,
                      let name = d["name"] as? String,
                      let path = d["path"] as? String else { return nil }
                return ImageItem(index: idx, name: name, path: path,
                                 size: (d["size"] as? Int64) ?? 0,
                                 sizeText: d["sizeText"] as? String ?? "")
            }
            originalItems = items
            orderModified = false
            updateListHeader()
            tableView.reloadData()
            let kindKey = obj["kind"] as? String ?? "kind.unknown"
            let count = items.count
            setStatus { String(format: L("statusListOk"), count, L(kindKey)) }
            log { String(format: L("logListOk"), count) + L(kindKey) }
            if !items.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
            setEnabledPreviewButtons(!items.isEmpty)
            if selfTest && selfTestStage == 0 {
                if ProcessInfo.processInfo.environment["IMGTOPDF_SELFTEST_CONTEXT"] != nil {
                    applySelfTestContextOps()
                }
                selfTestStage = 1
                logRaw("SELFTEST list OK: \(items.count) images")
                if ProcessInfo.processInfo.environment["IMGTOPDF_SELFTEST_QUEUE"] != nil {
                    runQueueSelfTest()
                    return
                }
                if ProcessInfo.processInfo.environment["IMGTOPDF_SELFTEST_REORDER"] != nil {
                    applySelfTestReorder()
                }
                let pick = min(1, items.count - 1)
                tableView.selectRowIndexes(IndexSet(integer: pick), byExtendingSelection: false)
                previewSelected()
            } else if !items.isEmpty {
                previewSelected()
            }
        } else if type == "error" {
            let m = eventText(obj, fallbackKey: "errReadFailed")
            statusFromEvent(obj, fallbackKey: "errReadFailed")
            logEvent(obj, prefix: "✗ ", color: .systemRed)
            items = []; originalItems = []
            tableView.reloadData()
            setEnabledPreviewButtons(false)
            if selfTest { selfTestFinish(false, "list: " + m) }
        } else if type == "log" {
            logEvent(obj)
        }
    }

    /// Drives the real button / context-menu action selectors (not just array edits).
    private func applySelfTestContextOps() {
        guard items.count > 4 else { return }
        let before = items.map { $0.index }
        select(row: 2)
        moveBottom()
        select(row: 2)
        moveTop()
        select(row: 1)
        removeSelected()
        logRaw("SELFTEST reorder: \(before) -> \(items.map { $0.index })")
    }

    private func applySelfTestReorder() {
        guard items.count > 3 else { return }
        let last = items.removeLast()
        items.insert(last, at: 0)          // move last image to page 1
        _ = items.popLast()                // drop one image entirely
        orderModified = true
        updateListHeader()
        tableView.reloadData()
        logRaw("SELFTEST reorder+remove done, \(items.count) left, order=\(items.map { String($0.index) }.joined(separator: ","))")
    }

    // MARK: - Table data source / delegate

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < items.count, let id = column?.identifier.rawValue else { return nil }
        let it = items[row]
        let text: String
        switch id {
        case "no": text = "\(row + 1)"
        case "name": text = it.name
        case "path": text = it.path
        case "size": text = it.sizeText
        default: text = ""
        }
        let cell = NSTextField(labelWithString: text)
        cell.font = .systemFont(ofSize: 11)
        cell.textColor = .labelColor
        cell.lineBreakMode = .byTruncatingTail
        cell.toolTip = it.path
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        previewSelected()
        setEnabledPreviewButtons(!items.isEmpty && selectedRow >= 0)
    }

    // Drag to reorder
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: rowPasteboardType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        dropOperation == .above ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let s = info.draggingPasteboard.string(forType: rowPasteboardType),
              let from = Int(s), from >= 0, from < items.count else { return false }
        moveItem(from: from, to: row, logIt: true)
        return true
    }

    private var selectedRow: Int { tableView.selectedRow }

    private func setEnabledPreviewButtons(_ has: Bool) {
        let n = items.count
        btnTop.isEnabled = has && selectedRow > 0
        btnUp.isEnabled = has && selectedRow > 0
        btnDown.isEnabled = has && selectedRow < n - 1 && selectedRow >= 0
        btnBottom.isEnabled = has && selectedRow < n - 1 && selectedRow >= 0
        btnPrev.isEnabled = has && selectedRow > 0
        btnNext.isEnabled = has && selectedRow < n - 1 && selectedRow >= 0
        btnCopyPath.isEnabled = has
        btnReveal.isEnabled = !sourcePath.isEmpty
    }

    @objc private func prevImage() {
        let r = selectedRow
        if r > 0 { select(row: r - 1) }
    }

    @objc private func nextImage() {
        let r = selectedRow
        if r < items.count - 1 { select(row: r + 1) }
    }

    private func select(row: Int) {
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    // MARK: - Reordering actions

    private func contextRow() -> Int {
        if selfTest { return selectedRow }
        let c = tableView.clickedRow
        return c >= 0 ? c : selectedRow
    }

    /// `to` is an insertion slot in the pre-removal array (0...count).
    private func moveItem(from: Int, to insertion: Int, logIt: Bool) {
        guard from >= 0, from < items.count else { return }
        guard insertion >= 0, insertion <= items.count else { return }
        var target = insertion
        if target > from { target -= 1 }
        guard target != from else { return }
        let it = items.remove(at: from)
        target = max(0, min(target, items.count))
        items.insert(it, at: target)
        orderModified = true
        updateListHeader()
        tableView.reloadData()
        select(row: target)
        if logIt { log { L("logDrag") } }
    }

    @objc private func moveTop() {
        let r = contextRow(); guard r > 0 else { return }
        moveItem(from: r, to: 0, logIt: false)
        log { String(format: L("logTop"), r + 1) }
    }

    @objc private func moveUp() {
        let r = contextRow(); guard r > 0 else { return }
        moveItem(from: r, to: r - 1, logIt: false)
        log { String(format: L("logMove"), r + 1, r) }
    }

    @objc private func moveDown() {
        let r = contextRow(); guard r >= 0, r < items.count - 1 else { return }
        moveItem(from: r, to: r + 2, logIt: false)
        log { String(format: L("logMove"), r + 1, r + 2) }
    }

    @objc private func moveBottom() {
        let r = contextRow(); guard r >= 0, r < items.count - 1 else { return }
        moveItem(from: r, to: items.count, logIt: false)
        log { String(format: L("logBottom"), r + 1) }
    }

    @objc private func removeSelected() {
        let r = contextRow(); guard r >= 0, r < items.count else { return }
        items.remove(at: r)
        orderModified = true
        updateListHeader()
        tableView.reloadData()
        if !items.isEmpty { select(row: min(r, items.count - 1)) }
        let remaining = items.count
        log { String(format: L("logRemove"), r + 1, remaining) }
    }

    @objc private func restoreOrder() {
        guard !originalItems.isEmpty else { return }
        items = originalItems
        orderModified = false
        updateListHeader()
        tableView.reloadData()
        if !items.isEmpty { select(row: 0) }
        log { L("logRestore") }
    }

    @objc private func reverseOrder() {
        items.reverse()
        orderModified = true
        updateListHeader()
        tableView.reloadData()
        if !items.isEmpty { select(row: 0) }
        log { L("logReverse") }
    }

    // MARK: - Preview switch

    private func syncPreviewMenu() { previewMenuItem?.state = previewEnabled ? .on : .off }

    private func applyPreviewVisibility() {
        imageView.isHidden = !previewEnabled
        previewOffLabel.isHidden = previewEnabled
    }

    private func setPreviewEnabled(_ on: Bool, persist: Bool) {
        previewEnabled = on
        previewToggle.state = on ? .on : .off
        syncPreviewMenu()
        applyPreviewVisibility()
        if persist { UserDefaults.standard.set(on, forKey: previewDefaultsKey) }
        thumbProc?.terminate()
        thumbToken += 1
        imageView.image = nil
        layoutAll(root.bounds)
        previewSelected()
        log { L(on ? "logPreviewOn" : "logPreviewOff") }
    }

    @objc private func togglePreviewButton(_ sender: NSButton) {
        setPreviewEnabled(sender.state == .on, persist: !isTestRun)
    }

    @objc private func togglePreviewMenu() {
        setPreviewEnabled(!previewEnabled, persist: !isTestRun)
    }

    // MARK: - Quality slider

    private func qualityGrade(_ q: Int) -> String {
        switch q {
        case ..<40: return L("qPoor")
        case ..<55: return L("qFair")
        case ..<70: return L("qMedium")
        case ..<83: return L("qGood")
        case ..<93: return L("qFine")
        default: return L("qBest")
        }
    }

    private func updateQualityInfo() {
        let q = Int(qualitySlider.doubleValue.rounded())
        qualityInfo.stringValue = "\(q) · \(qualityGrade(q))"
    }

    @objc private func qualityChanged(_ sender: NSSlider) { updateQualityInfo() }

    // MARK: - Preview

    private func advanceSelfTestAfterPreview(_ detail: String) {
        guard selfTest, selfTestStage == 1 else { return }
        selfTestStage = 2
        FileHandle.standardError.write("SELFTEST preview-stage=\(detail) enabled=\(previewEnabled)\n".data(using: .utf8)!)
        logRaw("SELFTEST preview OK: \(detail)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.startBuild() }
    }

    private func previewSelected() {
        let r = selectedRow
        guard r >= 0, r < items.count else { return }
        let item = items[r]
        thumbToken += 1
        let token = thumbToken
        thumbProc?.terminate()
        imageView.image = nil
        let location = L(sourceIsFolder ? "infoDisk" : "infoArchive")
        let baseInfo = String(format: L("infoPage"), r + 1, items.count) + item.name + "\n" +
                       location + "：" + item.path + "\n" +
                       L("infoSize") + item.sizeText
        applyPreviewVisibility()

        if !previewEnabled {
            infoLabel.stringValue = baseInfo + L("offSuffix")
            advanceSelfTestAfterPreview("preview off, location only")
            return
        }
        infoLabel.stringValue = String(format: L("infoReading"), r + 1)
        let dest = tempDir.appendingPathComponent("preview_\(item.index).jpg").path
        thumbProc = Bridge.shared.run(["thumb", "--src", sourcePath,
                                       "--archive-pass", archivePassword,
                                       "--index", String(item.index),
                                       "--out", dest, "--max-edge", "1200"],
                                      onEvent: { [weak self] obj in
                                          DispatchQueue.main.async {
                                              guard let self, self.thumbToken == token else { return }
                                              self.handleThumbEvent(obj, row: r, item: item)
                                          }
                                      },
                                      onExit: { _ in })
    }

    private func handleThumbEvent(_ obj: [String: Any], row: Int, item: ImageItem) {
        let type = obj["type"] as? String ?? ""
        if type == "thumb" {
            let file = obj["file"] as? String ?? ""
            if let img = NSImage(contentsOfFile: file) { imageView.image = img }
            let w = obj["width"] as? Int ?? 0
            let h = obj["height"] as? Int ?? 0
            let rot = obj["rotation"] as? Int ?? 1
            let bytes = obj["bytes"] as? Int ?? 0
            let location = L(sourceIsFolder ? "infoDisk" : "infoArchive")
            let rotText = rot > 1 ? String(format: L("infoRotation"), rot) : ""
            infoLabel.stringValue =
                String(format: L("infoPage"), row + 1, items.count) + item.name + "\n" +
                location + "：" + item.path + "\n" +
                String(format: L("infoDimensions"), w, h, Double(bytes) / 1048576.0) + rotText
            if selfTest {
                FileHandle.standardError.write("SELFTEST thumb event stage=\(selfTestStage) token=\(thumbToken)\n".data(using: .utf8)!)
            }
            advanceSelfTestAfterPreview("\(w) × \(h)")
        } else if type == "error" {
            let m = obj["message"] as? String ?? ""
            infoLabel.stringValue = L("infoFailed") + m
            if selfTest { selfTestFinish(false, "preview: " + m) }
        }
    }

    @objc private func copyPath() {
        guard selectedRow >= 0, selectedRow < items.count else { return }
        let it = items[selectedRow]
        let text = sourceIsFolder ? it.path : "\(sourcePath) → \(it.path)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        setStatus { L("statusCopied") }
    }

    @objc private func revealSource() {
        let r = selectedRow
        var target = sourcePath
        if sourceIsFolder, r >= 0, r < items.count, FileManager.default.fileExists(atPath: items[r].path) {
            target = items[r].path
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: target)])
    }

    // MARK: - Build

    private struct BuildSpec {
        let args: [String]
        let out: String
    }

    /// Validates the current form and produces the exact helper arguments.
    /// Shared by "Generate PDF" and "Add to Queue" so both behave identically.
    private func currentBuildArgs(reportStatus: Bool = true) -> BuildSpec? {
        func reject(_ key: String) -> BuildSpec? {
            if reportStatus { setStatus({ L(key) }, color: .systemRed) }
            if selfTest { selfTestFinish(false, L(key)) }
            return nil
        }
        guard !sourcePath.isEmpty, !items.isEmpty else { return reject("errNoSource") }
        let out = outField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty else { return reject("errNoOut") }
        let targetMB = Int(targetField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0
        let edge = Int(edgeField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0
        let quality = Int(qualitySlider.doubleValue.rounded())
        guard targetMB >= 1, targetMB <= 500 else { return reject("errTarget") }
        guard edge >= 400, edge <= 6000 else { return reject("errEdge") }
        guard quality >= 25, quality <= 95 else { return reject("errQuality") }

        let order = items.map { String($0.index) }.joined(separator: ",")
        var args = ["build", "--src", sourcePath,
                    "--archive-pass", archivePassword,
                    "--pdf-pass", pdfPassword,
                    "--out", out,
                    "--target-mb", String(targetMB),
                    "--max-edge", String(edge),
                    "--quality", String(quality),
                    "--page", "fit",
                    "--lang", currentLang.rawValue,
                    "--order", order]
        if writeReport {
            let report = (out as NSString).deletingPathExtension + L("reportSuffix")
            args += ["--error-log", report]
        }
        if selfTest {
            FileHandle.standardError.write("SELFTEST args order=\(order) quality=\(quality) page=fit report=\(writeReport)\n".data(using: .utf8)!)
        }
        return BuildSpec(args: args, out: out)
    }

    @objc private func startBuild() {
        if selfTest {
            FileHandle.standardError.write("SELFTEST startBuild out=\(outField.stringValue) items=\(items.count) building=\(isBuilding)\n".data(using: .utf8)!)
        }
        if isBuilding {
            addToQueue()
            return
        }
        guard let spec = currentBuildArgs() else { return }
        let targetMB = Int(targetField.stringValue.trimmingCharacters(in: .whitespaces)) ?? 20

        isBuilding = true
        activeBuildOut = spec.out
        gotTerminalEvent = false
        progress.doubleValue = 0
        resultPath = nil
        btnStart.title = L("btnStartAsQueue")
        btnStart.isEnabled = true
        btnStop.isEnabled = true
        btnShowResult.isEnabled = false
        btnOpenResult.isEnabled = false
        setStatus { L("statusGenerating") }
        let n = items.count
        log { String(format: L("logStart"), n, targetMB) }
        if pdfPassword.isEmpty { log { L("logNoPass") } }

        buildProc = Bridge.shared.run(spec.args,
                                      onEvent: { [weak self] obj in
                                          DispatchQueue.main.async { self?.handleBuildEvent(obj) }
                                      },
                                      onExit: { [weak self] code in
                                          DispatchQueue.main.async {
                                              guard let self else { return }
                                              self.isBuilding = false
                                              self.activeBuildOut = nil
                                              self.btnStart.title = L("btnStart")
                                              self.btnStart.isEnabled = true
                                              self.btnStop.isEnabled = false
                                              if !self.gotTerminalEvent && code != 0 {
                                                  self.setStatus({ String(format: L("statusInterrupted"), Int(code)) }, color: .systemRed)
                                              }
                                          }
                                      })
    }

    private func handleBuildEvent(_ obj: [String: Any]) {
        let type = obj["type"] as? String ?? ""
        switch type {
        case "progress":
            let pct = obj["percent"] as? Int ?? 0
            progress.doubleValue = Double(pct)
            setStatus { L("statusGenerating") + " \(pct)%" }
        case "log":
            logEvent(obj)
        case "report":
            let p = obj["path"] as? String ?? ""
            log({ L("logReport") + p }, color: .systemOrange)
        case "result":
            gotTerminalEvent = true
            progress.doubleValue = 100
            let path = obj["path"] as? String ?? ""
            resultPath = path
            let sizeText = obj["sizeText"] as? String ?? ""
            let pages = obj["pages"] as? Int ?? 0
            let elapsed = obj["elapsed"] as? String ?? ""
            let rounds = obj["rounds"] as? Int ?? 1
            let warnings = obj["warnings"] as? [Any] ?? []
            let repaired = obj["repaired"] as? Int ?? 0
            if selfTest && pages != items.count - warnings.count {
                selfTestFinish(false, "pages \(pages) != list \(items.count) - skipped \(warnings.count)")
                return
            }
            if warnings.isEmpty {
                setStatus({ String(format: L("statusDone"), pages, sizeText, elapsed) }, color: .systemGreen)
            } else {
                setStatus({ String(format: L("statusDoneWarn"), warnings.count, pages, sizeText) }, color: .systemOrange)
            }
            log({ String(format: L("logSuccess"), pages, sizeText, rounds, elapsed) }, color: .systemGreen)
            if repaired > 0 {
                log({ String(format: L("logRepaired"), repaired) }, color: .systemOrange)
            }
            if !warnings.isEmpty {
                log({ String(format: L("logSkipped"), warnings.count) }, color: .systemOrange)
                for w in warnings {
                    if let d = w as? [String: Any] {
                        logEvent(d, prefix: "  ⚠ ", color: .systemOrange)
                    } else if let text = w as? String {
                        logRaw("  ⚠ " + text, color: .systemOrange)
                    }
                }
            }
            if let sz = obj["size"] as? Int64, sz > Int64(20 * 1024 * 1024) {
                log { L("logOver20") }
            }
            btnShowResult.isEnabled = true
            btnOpenResult.isEnabled = true
            if selfTest { selfTestFinish(true, "\(pages) pages / \(sizeText) / \(elapsed)") }
        case "error":
            gotTerminalEvent = true
            let m = eventText(obj, fallbackKey: "errBuildFailed")
            statusFromEvent(obj, fallbackKey: "errBuildFailed")
            logEvent(obj, prefix: "✗ ", color: .systemRed)
            if selfTest { selfTestFinish(false, "build: " + m) }
        default: break
        }
    }

    @objc private func stopBuild() {
        buildProc?.terminate()
        log { L("logStop") }
        setStatus { L("statusStopped") }
    }

    @objc private func showResult() {
        guard let p = resultPath, FileManager.default.fileExists(atPath: p) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)])
    }

    @objc private func openResult() {
        guard let p = resultPath, FileManager.default.fileExists(atPath: p) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: p))
    }

    // MARK: - Small helpers

    /// The status line is stored as a renderer too, so completing a job and
    /// then switching language keeps the result, expressed in the new language.
    private func setStatus(_ text: @escaping () -> String, color: NSColor? = nil) {
        statusRenderer = text
        statusColor = color
        applyStatus()
    }

    private func applyStatus() {
        statusLabel.stringValue = statusRenderer?() ?? L("statusReady")
        statusLabel.textColor = statusColor ?? .secondaryLabelColor
    }

    /// Append a localizable line. The closure is re-run on every language
    /// switch, so it must capture plain values rather than `self`.
    private func log(_ text: @escaping () -> String, color: NSColor? = nil) {
        logEvents.append((text, color))
        renderLog()
    }

    /// Append a language-neutral data line: paths, filenames, diagnostics.
    private func logRaw(_ s: String, color: NSColor? = nil) {
        guard !s.isEmpty else { return }
        logEvents.append(({ s }, color))
        renderLog()
    }

    private func renderLog() {
        let out = NSMutableAttributedString()
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        for e in logEvents {
            out.append(NSAttributedString(string: e.text() + "\n", attributes: [
                .font: font,
                .foregroundColor: e.color ?? NSColor.labelColor
            ]))
        }
        logView.textStorage?.setAttributedString(out)
        logView.scrollToEndOfDocument(nil)
    }

    /// Record a structured event from the Go helper. The helper sends a
    /// language-neutral key plus arguments; the actual wording is chosen here,
    /// so switching language later re-translates even past engine messages.
    private func logEvent(_ obj: [String: Any], prefix: String = "", color: NSColor? = nil) {
        let key = obj["key"] as? String
        let args = eventArgs(obj)
        let fallback = obj["message"] as? String ?? ""
        let ts = obj["ts"] as? String ?? ""
        let stamp = ts.isEmpty ? "" : ts + "  "
        log({
            let text = (key?.isEmpty == false) ? LF(key!, args) : fallback
            return stamp + prefix + text
        }, color: color)
    }

    private func statusFromEvent(_ obj: [String: Any], fallbackKey: String) {
        setStatus({ eventText(obj, fallbackKey: fallbackKey) }, color: .systemRed)
    }
}

// MARK: - Task queue (independent jobs running in parallel)

private struct QueueJob {
    let name: String
    let out: String
    let args: [String]
    var status: String = "waiting" // waiting | running | done | failed | stopped
    var percent: Int = 0
    var detail: String = ""
    var proc: Process?
}

private final class QueueRootView: NSView {
    weak var owner: QueueWindowController?
    override func layout() { super.layout(); owner?.layoutAll(bounds) }
}

/// A standalone window holding several independent conversions. Each job gets
/// its own helper process, so one failure never stops the others.
final class QueueWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow!
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let btnStart = AppController.button("")
    private let btnStop = AppController.button("")
    private let btnRemove = AppController.button("")
    private let btnClear = AppController.button("")
    private let btnAddCurrent = AppController.button("")
    private let concurrencyLabel = AppController.label("", size: 11)
    private let concurrencyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hintLabel = AppController.wrappingLabel("", size: 11)
    private var jobs: [QueueJob] = []
    private var running = false
    private var allDoneFired = false
    private var onLog: ((@escaping () -> String) -> Void)?
    var onAllDone: ((Bool) -> Void)?
    var onAddCurrent: (() -> Void)?

    override init() {
        super.init()
        buildUI()
    }

    func setLogSink(_ f: @escaping (@escaping () -> String) -> Void) { onLog = f }

    private func buildUI() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 420),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 320)
        window.center()
        let root = QueueRootView(frame: window.contentLayoutRect)
        root.owner = self
        window.contentView = root

        for v in [scroll, btnStart, btnStop, btnRemove, btnClear, btnAddCurrent,
                  concurrencyLabel, concurrencyPopup, hintLabel] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = true
            root.addSubview(v)
        }

        table.rowHeight = 24
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.dataSource = self
        table.delegate = self
        for (id, key, width) in [("qno", "queueColNo", 40), ("qname", "queueColName", 230),
                                 ("qout", "queueColOut", 280), ("qstatus", "queueColStatus", 110),
                                 ("qprogress", "queueColProgress", 130)] {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            c.title = L(key)
            c.width = CGFloat(width)
            c.minWidth = 36
            table.addTableColumn(c)
        }
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        for (b, sel) in [(btnStart, #selector(startQueue)), (btnStop, #selector(stopQueue)),
                         (btnRemove, #selector(removeSelected)), (btnClear, #selector(clearFinished))] {
            b.target = self; b.action = sel; b.font = .systemFont(ofSize: 11)
        }
        btnAddCurrent.target = self
        btnAddCurrent.action = #selector(addCurrentJob)
        btnAddCurrent.font = .systemFont(ofSize: 11)
        btnAddCurrent.contentTintColor = .controlAccentColor
        btnStart.keyEquivalent = "\r"
        btnStart.contentTintColor = .controlAccentColor
        concurrencyPopup.addItems(withTitles: ["1", "2", "3", "4"])
        concurrencyPopup.selectItem(at: 1)
        concurrencyPopup.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        applyLanguage()
        layoutAll(root.bounds)
    }

    func layoutAll(_ b: NSRect) {
        scroll.frame = NSRect(x: 16, y: 100, width: b.width - 32, height: max(80, b.height - 116))
        hintLabel.frame = NSRect(x: 16, y: 48, width: b.width - 32, height: 40)
        btnStart.frame = NSRect(x: 16, y: 14, width: 110, height: 28)
        btnStop.frame = NSRect(x: 132, y: 14, width: 100, height: 28)
        btnRemove.frame = NSRect(x: 238, y: 14, width: 100, height: 28)
        btnClear.frame = NSRect(x: 344, y: 14, width: 100, height: 28)
        btnAddCurrent.frame = NSRect(x: 452, y: 14, width: 150, height: 28)
        concurrencyLabel.frame = NSRect(x: b.width - 232, y: 20, width: 100, height: 18)
        concurrencyPopup.frame = NSRect(x: b.width - 128, y: 15, width: 64, height: 26)
    }

    func applyLanguage() {
        window?.title = L("queueTitle")
        btnStart.title = L("queueStart"); btnStop.title = L("queueStop")
        btnRemove.title = L("queueRemove"); btnClear.title = L("queueClear")
        btnAddCurrent.title = L("queueAddCurrent")
        concurrencyLabel.stringValue = L("queueConcurrency")
        hintLabel.stringValue = L("queueHint")
        let titles = [L("queueColNo"), L("queueColName"), L("queueColOut"),
                      L("queueColStatus"), L("queueColProgress")]
        for (i, t) in titles.enumerated() where i < table.tableColumns.count {
            let col = table.tableColumns[i]
            col.title = t
            col.headerCell.stringValue = t
        }
        table.headerView?.needsDisplay = true
        table.reloadData()
    }

    func show() {
        applyLanguage()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func addJob(name: String, out: String, args: [String]) {
        jobs.append(QueueJob(name: name, out: out, args: args))
        table.reloadData()
        onLog? { L("queueAdded") + name }
        // Without this, any job appended after "Start Queue" stayed in
        // "Waiting" forever until the user pressed Start Queue again.
        if running { pump() }
    }

    /// Visible job states, used by the hidden queue self-test.
    func statusLines() -> [String] { jobs.map { $0.status } }

    /// Every visible string in this window, for the localization self-test.
    func visibleStrings() -> String {
        var parts = [window?.title ?? "", hintLabel.stringValue,
                     btnStart.title, btnStop.title, btnRemove.title,
                     btnClear.title, btnAddCurrent.title, concurrencyLabel.stringValue]
        parts += table.tableColumns.map { $0.headerCell.stringValue }
        return parts.joined(separator: " | ")
    }

    @objc private func addCurrentJob() { onAddCurrent?() }

    /// Two processes must never write the same PDF. Return a free variant of
    /// `out` if it is already used by a queued job or by the main-window job.
    func uniqueOutput(_ out: String, extra: Set<String> = []) -> String {
        var used = Set(jobs.map { $0.out })
        used.formUnion(extra)
        if !used.contains(out) { return out }
        let base = (out as NSString).deletingPathExtension
        let ext = (out as NSString).pathExtension
        var i = 2
        var candidate = "\(base)_\(i).\(ext)"
        while used.contains(candidate) {
            i += 1
            candidate = "\(base)_\(i).\(ext)"
        }
        return candidate
    }

    var jobCount: Int { jobs.count }

    // MARK: queue execution

    @objc func startQueue() {
        if jobs.isEmpty { onLog? { L("queueEmpty") }; return }
        for i in jobs.indices where jobs[i].status == "stopped" { jobs[i].status = "waiting" }
        running = true
        allDoneFired = false
        table.reloadData()
        pump()
    }

    @objc private func stopQueue() {
        running = false
        for i in jobs.indices {
            if jobs[i].status == "running" {
                jobs[i].proc?.terminate()
                jobs[i].status = "stopped"
                jobs[i].detail = ""
            } else if jobs[i].status == "waiting" {
                jobs[i].status = "stopped"
            }
        }
        table.reloadData()
    }

    @objc private func removeSelected() {
        let r = table.selectedRow
        guard r >= 0, r < jobs.count, jobs[r].status != "running" else { return }
        jobs.remove(at: r)
        table.reloadData()
    }

    @objc private func clearFinished() {
        jobs.removeAll { $0.status == "done" || $0.status == "failed" || $0.status == "stopped" }
        table.reloadData()
    }

    private func activeCount() -> Int {
        jobs.filter { $0.status == "running" }.count
    }

    private func pump() {
        guard running else { return }
        let limit = concurrencyPopup.indexOfSelectedItem + 1
        while activeCount() < limit {
            guard let i = jobs.firstIndex(where: { $0.status == "waiting" }) else { break }
            launch(i)
        }
        if jobs.contains(where: { $0.status == "waiting" || $0.status == "running" }) {
            allDoneFired = false
        } else if !allDoneFired {
            // Stay in "started" mode: a job appended later is picked up
            // immediately instead of sitting in Waiting forever.
            allDoneFired = true
            onLog? { L("queueAllDone") }
            let ok = jobs.allSatisfy { $0.status == "done" }
            onAllDone?(ok)
        }
    }

    private func launch(_ i: Int) {
        guard i < jobs.count else { return }
        jobs[i].status = "running"
        jobs[i].percent = 0
        jobs[i].detail = ""
        table.reloadData()
        let args = jobs[i].args
        jobs[i].proc = Bridge.shared.run(args, onEvent: { [weak self] obj in
            DispatchQueue.main.async { self?.handle(i, obj) }
        }, onExit: { [weak self] code in
            DispatchQueue.main.async {
                guard let self, i < self.jobs.count else { return }
                if self.jobs[i].status == "running" {
                    self.jobs[i].status = code == 0 ? "done" : "failed"
                    if code != 0 { self.jobs[i].detail = "exit \(code)" }
                }
                self.table.reloadData()
                self.pump()
            }
        })
    }

    private func handle(_ i: Int, _ obj: [String: Any]) {
        guard i < jobs.count else { return }
        switch obj["type"] as? String ?? "" {
        case "progress":
            jobs[i].percent = obj["percent"] as? Int ?? 0
        case "result":
            jobs[i].status = "done"
            jobs[i].percent = 100
            jobs[i].detail = "\(obj["pages"] as? Int ?? 0) pages"
        case "error":
            jobs[i].status = "failed"
            jobs[i].detail = obj["message"] as? String ?? ""
        default:
            return
        }
        table.reloadData()
    }

    // MARK: table data

    func numberOfRows(in tableView: NSTableView) -> Int { jobs.count }

    func tableView(_ tv: NSTableView, viewFor col: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < jobs.count else { return nil }
        let id = NSUserInterfaceItemIdentifier("qcell")
        let cell: NSTextField
        if let c = tv.makeView(withIdentifier: id, owner: self) as? NSTextField {
            cell = c
        } else {
            let t = NSTextField(labelWithString: "")
            t.identifier = id
            t.font = .systemFont(ofSize: 11)
            t.lineBreakMode = .byTruncatingTail
            cell = t
        }
        let j = jobs[row]
        switch col?.identifier.rawValue ?? "" {
        case "qno": cell.stringValue = "\(row + 1)"
        case "qname": cell.stringValue = j.name
        case "qout": cell.stringValue = (j.out as NSString).lastPathComponent
        case "qstatus": cell.stringValue = statusText(j.status)
        case "qprogress": cell.stringValue = j.status == "running" ? "\(j.percent)%" : j.detail
        default: cell.stringValue = ""
        }
        cell.textColor = statusColor(j.status)
        cell.toolTip = j.out
        return cell
    }

    private func statusText(_ s: String) -> String {
        switch s {
        case "waiting": return L("queueWaiting")
        case "running": return L("queueRunning")
        case "done": return L("queueDone")
        case "failed": return L("queueFailed")
        default: return L("queueStopped")
        }
    }

    private func statusColor(_ s: String) -> NSColor {
        switch s {
        case "done": return .systemGreen
        case "failed": return .systemRed
        case "running": return .controlAccentColor
        case "stopped": return .systemOrange
        default: return .secondaryLabelColor
        }
    }
}

// MARK: - Bootstrap (classic AppKit: no @MainActor, callbacks must stay deliverable)

private var appDelegateHolder: AppController?

@main
struct Bootstrap {
    static func main() {
        let app = NSApplication.shared
        let controller = AppController()
        appDelegateHolder = controller
        app.delegate = controller
        app.setActivationPolicy(.regular)
        app.run()
    }
}
