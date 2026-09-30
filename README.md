# EdgeSafariSync

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift) ![UI](https://img.shields.io/badge/UI-SwiftUI-0A84FF) ![License](https://img.shields.io/badge/License-GPLv3-blue.svg) [![Release](https://img.shields.io/badge/release-v1.1.0-green)](../../releases/tag/v1.1.0)

一个原生 macOS 菜单栏应用，用于在 Microsoft Edge 和 Safari 浏览器之间同步书签。

## 特性

- 🔄 **双向同步**: Edge ↔ Safari（可切换方向）
- 🎯 **菜单栏应用**: 轻量级，无 Dock 图标
- 💾 **自动备份**: 同步前自动创建备份，失败时自动恢复
- 🔒 **安全检测**: 同步前检测浏览器是否运行，避免数据损坏
- 📝 **详细反馈**: 彩色状态消息、错误详情、时间戳显示
- 🚫 **零依赖**: 纯 Swift + SwiftUI + Foundation，无第三方库
- 🛡️ **NSKeyedArchiver 检测**: 识别 macOS 14+/Tahoe 上 Safari 因 iCloud 同步产生的加密归档格式，避免写入失败
- 🆔 **稳定 UUID**: 重复同步不会改变书签 UUID，保留 Safari 排序/分组信息

## 下载与安装

请前往 [Releases 页面](../../releases) 下载最新版本的 DMG 安装包。

1. **下载**: 在 [Releases](../../releases) 页面下载 `EdgeSafariSync_Installer.dmg`（v1.1.0 及以上）。
2. **安装**: 双击 DMG 文件，将 `EdgeSafariSync` 图标拖入 `Applications` 文件夹。
3. **运行**: 在应用程序中启动 `EdgeSafariSync`。应用将驻留在菜单栏右上角（↔️ 图标）。

## 系统要求

- macOS 13.0 或更高版本（macOS 14+/Tahoe 用户请参阅 [同步前提](#同步前提)）
- Microsoft Edge（用于 Edge → Safari 同步）
- Safari（macOS 自带）
- **完全磁盘访问权限**: 首次运行时，请在【系统设置 > 隐私与安全性 > 完全磁盘访问权限】中授予 EdgeSafariSync 权限，以便读取书签文件。

## 使用指南

1. **点击菜单栏图标** (↔️) 打开控制面板。
2. **切换同步方向**（可选）- 点击 "Toggle Direction" 按钮。
3. **执行同步**:
   - **确保 Edge 和 Safari 都已退出**（Cmd+Q，不是关窗口）。
   - **确保 Safari 书签的 iCloud 同步已临时关闭**（详见下文 [同步前提](#同步前提)）。
   - 点击 "Sync Now" 按钮。
   - 等待同步完成（绿色成功消息）。
4. **验证结果** - 打开目标浏览器检查书签。
5. **重新开启 Safari 的 iCloud 同步**（可选）让书签推送到其他 Apple 设备。

### 同步前提

Safari 在开启 iCloud 书签同步时（macOS 14+/Tahoe 默认开启），其 `Bookmarks.plist` 会被 iCloud 守护进程改写为 **NSKeyedArchiver 加密归档格式**，这是 Apple 的私有序列化格式，外部工具无法安全修改。EdgeSafariSync 会自动检测这种格式并给出清晰的错误提示。

**临时关闭 iCloud Safari 同步的方法：**
1. 打开 **系统设置** → 你的 **Apple ID** → **iCloud** → **显示全部**。
2. 找到 **Safari 书签**（或 "Safari Bookmarks"），关闭。
3. 弹出对话框选 **"保留在我的 Mac 上"**。
4. 等待 1–5 分钟让 iCloud 守护进程把 `Bookmarks.plist` 重新写入为普通 plist。
5. 终端验证：`file ~/Library/Safari/Bookmarks.plist` 应输出 `Apple binary property list` 或 `XML 1.0 document`（不是 `typed stream data`）。
6. 同步完成后，可重新开启 iCloud Safari 同步，让书签推送到 iPhone/iPad。

## 同步逻辑说明

### Edge → Safari（默认）
- **行为**: 将 Edge 的"收藏夹栏"同步到 Safari 的"收藏夹栏"。
- **备份**: 自动备份到 `~/Library/Application Support/EdgeSafariSync/backups/Bookmarks.plist.bak[.timestamp]`（避开 SIP/TCC 保护的 `~/Library/Safari/`）。
- **写入格式**: 保留原 `Bookmarks.plist` 的 plist 格式（binary 或 XML），并补齐 `WebBookmarkFileVersion` 等必填字段，防止 Safari 重建文件导致书签丢失。

### Safari → Edge
- **行为**: **非破坏性导入** —— 在 Edge 收藏夹栏末尾追加一个 "Imported from Safari" 文件夹，保留 Edge 原有的所有书签；多次同步会自动合并去重（按 URL）。
- **备份**: 自动备份到 `~/Library/Application Support/EdgeSafariSync/backups/Bookmarks.bak[.timestamp]`。
- **时间戳**: 使用 Chrome/Edge 的 WebKit 时间戳（1601 纪元起的微秒数），避免 Edge 因 `date_added=0` 静默忽略书签。

## 故障排除

### 1. 同步失败："Permission denied. Please grant Full Disk Access."
**原因**: 应用没有读取书签文件的权限。
**解决方案**:
1. 打开 **系统设置** > **隐私与安全性** > **完全磁盘访问权限**。
2. 点击 "+" 号，选择 `/Applications/EdgeSafariSync.app`。
3. 确保勾选框已选中。
4. 完全退出应用（Cmd+Q）后重新启动。
5. 如果是从 Xcode 运行的，需要同时给 **Xcode** 授权。

### 2. 同步失败："Cannot sync: [浏览器] is currently running"
**原因**: 浏览器正在运行，文件被锁定。
**解决方案**: 完全退出浏览器（Cmd+Q，不是关窗口），然后重试。

### 3. 同步失败："Safari Bookmarks.plist uses NSKeyedArchiver format..."
**原因**: Safari 书签的 iCloud 同步已开启。`Bookmarks.plist` 会被 iCloud 守护进程改写为 NSKeyedArchiver 加密归档格式，外部工具无法安全修改。
**解决方案**: 参见 [同步前提](#同步前提)。

### 4. 同步失败：状态显示绿色但 Safari 里看不到书签
**原因**: 旧版 Bug，BookmarkNode.id 被强制替换为随机 UUID 导致 Safari 视为全新书签并保留旧条目。
**解决方案**: 已修复（v1.1.0）。使用稳定 UUID，重复同步不会改变 UUID。清理 Safari 多余旧条目：在 Safari 中手动删除旧分组。

### 5. 书签未显示更新
**原因**: Safari 缓存了旧的书签数据。
**解决方案**: 退出 Safari（Cmd+Q）后重新打开即可。

### 6. Safari→Edge 后找不到导入的书签
**原因**: 默认行为是**非破坏性导入**，所有 Safari 书签会出现在 Edge 收藏夹栏末尾的 **"Imported from Safari"** 文件夹中。
**解决方案**: 在 Edge 收藏夹栏底部找到该文件夹。

### 7. 应用启动崩溃或 Xcode 报告权限问题
**解决方案**: 删除 DerivedData 并清理构建缓存：
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/EdgeSafariSync-*
```
然后在 Xcode 中 **Product → Clean Build Folder**（Cmd+Shift+K），重新运行。

## 开发

### 项目结构
```
EdgeSafariSync/
├── EdgeSafariSync.xcodeproj/          # Xcode 项目
├── EdgeSafariSync/                     # 源代码
│   ├── EdgeSafariSyncApp.swift        # 主应用 + SwiftUI UI
│   ├── BookmarkNode.swift             # 数据模型
│   ├── EdgeParser.swift                # Edge JSON 解析器
│   ├── SafariParser.swift             # Safari plist 解析器（含 NSKeyedArchiver 检测）
│   ├── BookmarkSerializer.swift        # 序列化（含稳定 UUID 生成）
│   ├── BackupManager.swift             # 备份/恢复（避开 SIP 目录）
│   ├── FileValidator.swift             # 文件验证（含 errno 精确分类）
│   ├── SyncEngine.swift                # 同步引擎
│   ├── BrowserProcessDetector.swift    # 浏览器运行检测（含 Edge 全家桶）
│   └── Info.plist
└── README.md
```

### 构建

**命令行构建（生成 Release .app）**
```bash
cd /Users/wpt/opt/EdgeSafariSync
xcodebuild -project EdgeSafariSync.xcodeproj \
           -scheme EdgeSafariSync \
           -configuration Release \
           -derivedDataPath build \
           clean build
```

构建产物路径：`build/Build/Products/Release/EdgeSafariSync.app`

**打包成 DMG（使用 create-dmg 或手工）**

如果已安装 [`create-dmg`](https://github.com/create-dmg/create-dmg)：
```bash
create-dmg --volname "EdgeSafariSync" \
           --window-pos 200 120 \
           --window-size 600 400 \
           --icon-size 100 \
           --icon "EdgeSafariSync.app" 175 190 \
           --app-drop-link 425 190 \
           --no-internet-enable \
           "build/EdgeSafariSync_Installer.dmg" \
           "build/Build/Products/Release/"
```

如果没有 `create-dmg`，可使用 Finder 手工制作：
1. 在 Finder 中打开 `build/Build/Products/Release/`
2. 新建一个文件夹叫 `EdgeSafariSync_Installer`
3. 把 `EdgeSafariSync.app` 拖进去，并在旁边创建到 `/Applications` 的快捷方式
4. 用 **磁盘工具 → 文件 → 新建映像 → 来自文件夹的映像** 输出 DMG

### 本地验证脚本
```bash
cd /Users/wpt/opt/EdgeSafariSync
./verify-project.sh
```
该脚本检查：
- 源文件完整性（9 个 Swift 文件 + Info.plist）
- LSUIElement 配置
- Swift 工具链版本
- 编译零错误
- 浏览器书签文件可访问性

## 变更历史

详见 [Releases 页面](../../releases)。摘要：

- **v1.1.0** (2026-09-30) - 修复 macOS 14+/Tahoe 同步失败、NSKeyedArchiver 检测、稳定 UUID、非破坏性 Safari→Edge 导入、改进错误诊断（errno 分类）。
- **v1.0.0** (2026-02-13) - 首版发布：双向同步、自动备份、浏览器检测。

## 许可证

GPLv3 - 详见 [LICENSE](LICENSE) 文件。

---

**注意**: 本应用会修改系统书签文件。建议定期手动备份重要数据。自动备份文件位于 `~/Library/Application Support/EdgeSafariSync/backups/`。