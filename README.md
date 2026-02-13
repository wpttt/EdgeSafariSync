# EdgeSafari Sync

一个原生 macOS 菜单栏应用，用于在 Microsoft Edge 和 Safari 浏览器之间同步书签。

## 特性

- 🔄 **双向同步**: Edge ↔ Safari（可切换方向）
- 🎯 **菜单栏应用**: 轻量级，无 Dock 图标
- 💾 **自动备份**: 同步前自动创建备份，失败时自动恢复
- 🔒 **安全检测**: 同步前检测浏览器是否运行，避免数据损坏
- 📝 **详细反馈**: 彩色状态消息、错误详情、时间戳显示
- 🚫 **零依赖**: 纯 Swift + SwiftUI + Foundation，无第三方库

## 系统要求

- macOS 13.0 或更高版本
- Xcode 14.0 或更高版本（仅构建需要）
- Microsoft Edge（用于 Edge → Safari 同步）
- Safari（macOS 自带）

## 快速开始

### 1. 验证项目

```bash
cd /Users/wpt/opt/EdgeSafariSync
./verify-project.sh
```

预期输出：所有检查通过 ✅

### 2. 在 Xcode 中打开项目

```bash
open EdgeSafariSync.xcodeproj
```

### 3. 构建并运行

- 选择 "My Mac" 作为运行目标
- 点击 Run 按钮（▶️）或按 `Cmd+R`
- 应用启动后，菜单栏右上角出现同步图标（↔️）

### 4. 使用应用

1. **点击菜单栏图标** - 打开控制面板
2. **切换同步方向**（可选）- 点击 "Toggle Direction" 按钮
3. **执行同步**:
   - 确保 Edge 和 Safari 都已退出
   - 点击 "Sync Now" 按钮
   - 等待同步完成（绿色成功消息）
4. **验证结果** - 打开目标浏览器检查书签

## 项目结构

```
EdgeSafariSync/
├── EdgeSafariSync.xcodeproj/     # Xcode 项目文件
├── EdgeSafariSync/                # 源代码目录
│   ├── EdgeSafariSyncApp.swift   # 主应用 + UI
│   ├── BookmarkNode.swift         # 数据模型
│   ├── EdgeParser.swift           # Edge 书签解析器
│   ├── SafariParser.swift         # Safari 书签解析器
│   ├── BookmarkSerializer.swift   # 双向序列化器
│   ├── BackupManager.swift        # 备份/恢复管理
│   ├── FileValidator.swift        # 文件验证器
│   ├── SyncEngine.swift           # 同步引擎
│   ├── BrowserProcessDetector.swift  # 浏览器检测
│   ├── Info.plist                 # 应用配置
│   └── Assets.xcassets/           # 资源文件
├── README.md                      # 本文件
├── VERIFICATION_GUIDE.md          # 详细验证指南
└── verify-project.sh              # 自动化验证脚本
```

## 同步逻辑

### Edge → Safari（默认）

- **行为**: 破坏性同步（Safari 书签被完全替换为 Edge 书签）
- **备份**: 自动创建 `Bookmarks.plist.bak`
- **恢复**: 失败时自动从备份恢复

### Safari → Edge

- **行为**: 非破坏性同步（Safari 书签导入到新文件夹）
- **文件夹**: "Imported from Safari"（插入到书签栏开头）
- **备份**: 自动创建 `Bookmarks.bak`
- **恢复**: 失败时自动从备份恢复

## 书签文件位置

- **Edge**: `~/Library/Application Support/Microsoft Edge/Default/Bookmarks`
- **Safari**: `~/Library/Safari/Bookmarks.plist`

## 故障排除

### 同步失败："Cannot sync: [浏览器] is currently running"

**解决方案**: 完全退出浏览器（Cmd+Q），然后重试。

### 同步失败："Validation failed"

**原因**: 书签文件不存在或不可读。

**解决方案**:
1. 确认浏览器已安装
2. 至少打开过一次浏览器（创建书签文件）
3. 检查文件权限

### 应用未在菜单栏显示

**原因**: LSUIElement 配置问题或构建错误。

**解决方案**:
1. 检查 `Info.plist` 中 `LSUIElement = true`
2. 清理构建：Xcode → Product → Clean Build Folder
3. 重新构建并运行

### 书签未导入

**解决方案**:
1. 重启目标浏览器（强制重新加载书签）
2. 检查目标浏览器的书签管理器
3. 恢复备份文件（`.bak` 后缀）

## 开发状态

- ✅ **M1-M5 完成**: 所有核心功能已实现
- ⏳ **M6 待验证**: 需要手动 QA（参见 VERIFICATION_GUIDE.md）

## 验证指南

详细的手动验证步骤，请参阅 [VERIFICATION_GUIDE.md](./VERIFICATION_GUIDE.md)。

## 安全建议

1. **首次使用前备份书签**:
   ```bash
   cp ~/Library/Application\ Support/Microsoft\ Edge/Default/Bookmarks ~/Desktop/edge-backup.json
   cp ~/Library/Safari/Bookmarks.plist ~/Desktop/safari-backup.plist
   ```

2. **使用测试账户**: 首次测试时使用测试账户或虚拟机

3. **检查备份文件**: 同步后验证 `.bak` 文件已创建

## 许可证

本项目为个人使用，未指定许可证。

## 作者

由 OhMyOpenCode 的 Atlas（协调器）和 Sisyphus-Junior（执行者）共同开发。

---

**注意**: 本应用修改系统书签文件。建议首次使用前备份数据。
