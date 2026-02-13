# EdgeSafari Sync - 手动验证指南

本指南用于完成 M6 验证任务（3个任务）。

---

## 前置准备

### 1. 备份现有书签（强烈建议）

```bash
# 备份 Edge 书签
cp ~/Library/Application\ Support/Microsoft\ Edge/Default/Bookmarks ~/Desktop/edge-bookmarks-backup.json

# 备份 Safari 书签
cp ~/Library/Safari/Bookmarks.plist ~/Desktop/safari-bookmarks-backup.plist
```

### 2. 确认文件完整性

```bash
cd /Users/wpt/opt/EdgeSafariSync
ls -l EdgeSafariSync/*.swift
# 应该看到 9 个 .swift 文件
```

---

## M6 Task 1: 应用启动和菜单栏图标

### 步骤

1. **在 Xcode 中打开项目**
   ```bash
   open /Users/wpt/opt/EdgeSafariSync/EdgeSafariSync.xcodeproj
   ```

2. **选择目标设备**
   - 在 Xcode 顶部工具栏，选择 "My Mac" 作为运行目标

3. **构建并运行**
   - 点击 Run 按钮（▶️）或按 Cmd+R
   - 等待编译完成

### 验证检查点

- [ ] **应用启动成功**（无崩溃）
- [ ] **菜单栏右上角出现同步图标**（双箭头 ↔️ 图标）
- [ ] **Dock 中没有应用图标**（LSUIElement = true 生效）
- [ ] **Xcode 控制台无错误日志**

---

## M6 Task 2: Popover 和方向切换

### 步骤

1. **点击菜单栏图标**
   - 在菜单栏右上角找到同步图标（↔️）
   - 鼠标左键点击图标

2. **检查 Popover 界面**
   - Popover 应从图标下方弹出
   - 尺寸：360x400 像素
   - 内容应包含：
     - 标题："EdgeSafari Sync"
     - 方向显示："Direction: Edge → Safari"（蓝色）
     - 状态消息："Ready to sync"（灰色）
     - 时间戳："Last sync: Never"（小字，灰色）
     - "Sync Now" 按钮（蓝色主按钮）
     - "Toggle Direction" 按钮（普通按钮）

3. **测试方向切换**
   - 点击 "Toggle Direction" 按钮
   - 方向应切换为 "Safari → Edge"
   - 再次点击，应切换回 "Edge → Safari"

### 验证检查点

- [ ] **Popover 正常弹出**（位置在图标下方）
- [ ] **所有 UI 元素正确显示**（标题、方向、状态、按钮）
- [ ] **方向文本在两个状态间正确切换**
- [ ] **UI 布局美观**（间距合理、对齐正确）
- [ ] **点击 Popover 外部可关闭**（transient behavior）

---

## M6 Task 3: 同步按钮和逻辑验证

### ⚠️ 重要警告

**此任务会修改您的浏览器书签文件！**

建议选择以下方式之一：
- **方式 A**：使用测试账户或虚拟机
- **方式 B**：已完成前置准备的书签备份（参见本指南开头）
- **方式 C**：创建测试书签，仅同步测试数据

### 步骤: 测试 Edge → Safari 同步

1. **确保浏览器已退出**
   - 完全退出 Safari（Cmd+Q）
   - 完全退出 Microsoft Edge（Cmd+Q）

2. **执行同步**
   - 在 Popover 中，确认方向为 "Edge → Safari"
   - 点击 "Sync Now" 按钮
   - **观察 UI 变化**：
     - 按钮变为 "Syncing..." + 旋转进度指示器
     - 状态消息变为 "Syncing..."（灰色）

3. **等待同步完成**
   - **成功情况**：
     - 状态消息变为 "Sync completed successfully!"（绿色）
     - 时间戳更新为 "Last sync: 刚刚"
     - 按钮恢复为 "Sync Now"

4. **验证书签导入**
   - 打开 Safari
   - 检查 Safari 书签栏（Cmd+Alt+B）
   - **预期结果**：Edge 的书签已出现在 Safari 中

### 验证检查点

- [ ] **Edge → Safari 同步成功**（书签正确导入）
- [ ] **同步期间 UI 正确更新**（进度指示器、状态消息、颜色变化）
- [ ] **时间戳正确更新**（相对时间格式）
- [ ] **浏览器运行检测正常**（运行时拒绝同步并显示错误）

---

## 验证完成后

### 报告结果

- [ ] M6 Task 1: ✅ 通过 / ❌ 失败
- [ ] M6 Task 2: ✅ 通过 / ❌ 失败
- [ ] M6 Task 3: ✅ 通过 / ❌ 失败

**如果有失败**，请记录：
1. 具体错误消息
2. 重现步骤
3. 截图（如果可能）

---

**验证愉快！如有问题，请查看 Xcode 控制台日志。**
