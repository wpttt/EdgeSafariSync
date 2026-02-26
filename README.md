# EdgeSafariSync

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift) ![UI](https://img.shields.io/badge/UI-SwiftUI-0A84FF) ![License](https://img.shields.io/badge/License-GPLv3-blue.svg) [![Release](https://img.shields.io/badge/release-v1.0.0-green)](../../releases)

一个原生 macOS 菜单栏应用，用于在 Microsoft Edge 和 Safari 浏览器之间同步书签。

## 特性

- 🔄 **双向同步**: Edge ↔ Safari（可切换方向）
- 🎯 **菜单栏应用**: 轻量级，无 Dock 图标
- 💾 **自动备份**: 同步前自动创建备份，失败时自动恢复
- 🔒 **安全检测**: 同步前检测浏览器是否运行，避免数据损坏
- 📝 **详细反馈**: 彩色状态消息、错误详情、时间戳显示
- 🚫 **零依赖**: 纯 Swift + SwiftUI + Foundation，无第三方库

## 下载与安装

请前往 [Releases 页面](../../releases) 下载最新版本的 DMG 安装包。

1. **下载**: 点击下载 `EdgeSafariSync_Installer.dmg`。
2. **安装**: 双击 DMG 文件，将 `EdgeSafariSync` 图标拖入 `Applications` 文件夹。
3. **运行**: 在应用程序中启动 `EdgeSafariSync`。应用将驻留在菜单栏右上角。

## 系统要求

- macOS 13.0 或更高版本
- Microsoft Edge（用于 Edge → Safari 同步）
- Safari（macOS 自带）
- **完全磁盘访问权限**: 首次运行时，请在【系统设置 > 隐私与安全性 > 完全磁盘访问权限】中授予 EdgeSafariSync 权限，以便读取书签文件。

## 使用指南

1. **点击菜单栏图标** (↔️) 打开控制面板。
2. **切换同步方向**（可选）- 点击 "Toggle Direction" 按钮。
3. **执行同步**:
   - **确保 Edge 和 Safari 都已退出**。
   - 点击 "Sync Now" 按钮。
   - 等待同步完成（绿色成功消息）。
4. **验证结果** - 打开目标浏览器检查书签。

## 同步逻辑说明

### Edge → Safari（默认）
- **行为**: 将 Edge 的 "收藏夹栏" 同步到 Safari 的 "收藏夹栏"。
- **备份**: 自动创建 `~/Library/Safari/Bookmarks.plist.bak`。

### Safari → Edge
- **行为**: 将 Safari 的 "收藏夹栏" 同步到 Edge 的 "收藏夹栏"。
- **备份**: 自动创建 `~/Library/Application Support/Microsoft Edge/Default/Bookmarks.bak`。

## 故障排除

### 1. 同步失败："Permission denied. Please grant Full Disk Access."
**原因**: 应用没有读取书签文件的权限。
**解决方案**:
1. 打开 **系统设置** > **隐私与安全性** > **完全磁盘访问权限**。
2. 点击 "+" 号，选择 `/Applications/EdgeSafariSync.app`。
3. 确保勾选框已选中。
4. 重启应用。

### 2. 同步失败："Cannot sync: [浏览器] is currently running"
**原因**: 浏览器正在运行，文件被锁定。
**解决方案**: 完全退出浏览器（Cmd+Q），然后重试。

### 3. 书签未显示更新
**原因**: 浏览器缓存了旧的书签数据。
**解决方案**: 重启目标浏览器以重新加载书签。

---

**注意**: 本应用会修改系统书签文件，建议定期手动备份重要数据。
