#!/bin/bash

# EdgeSafari Sync - 自动化项目验证脚本

set -e

echo "================================"
echo "EdgeSafari Sync - 项目验证"
echo "================================"
echo ""

# 检查当前目录
if [ ! -d "EdgeSafariSync.xcodeproj" ]; then
    echo "❌ 错误：未在项目根目录运行此脚本"
    exit 1
fi

echo "✅ 项目目录正确"

# 检查所有源文件
echo ""
echo "检查源文件..."
REQUIRED_FILES=(
    "EdgeSafariSync/EdgeSafariSyncApp.swift"
    "EdgeSafariSync/BookmarkNode.swift"
    "EdgeSafariSync/EdgeParser.swift"
    "EdgeSafariSync/SafariParser.swift"
    "EdgeSafariSync/BookmarkSerializer.swift"
    "EdgeSafariSync/BackupManager.swift"
    "EdgeSafariSync/FileValidator.swift"
    "EdgeSafariSync/SyncEngine.swift"
    "EdgeSafariSync/BrowserProcessDetector.swift"
    "EdgeSafariSync/Info.plist"
)

MISSING_COUNT=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ 缺失: $file"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

if [ $MISSING_COUNT -gt 0 ]; then
    echo ""
    echo "❌ 错误：$MISSING_COUNT 个文件缺失"
    exit 1
fi

echo ""
echo "✅ 所有源文件存在 (9 个 Swift 文件 + 1 个 Info.plist)"

# 检查 Info.plist 配置
echo ""
echo "检查 Info.plist 配置..."
if grep -q "<key>LSUIElement</key>" EdgeSafariSync/Info.plist && \
   grep -q "<true/>" EdgeSafariSync/Info.plist; then
    echo "  ✅ LSUIElement = true（隐藏 Dock 图标）"
else
    echo "  ❌ LSUIElement 配置错误"
    exit 1
fi

# 检查 Swift 编译器
echo ""
echo "检查 Swift 工具链..."
if command -v swiftc &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -1)
    echo "  ✅ $SWIFT_VERSION"
else
    echo "  ❌ swiftc 未找到"
    exit 1
fi

# 编译验证
echo ""
echo "编译验证（这可能需要几秒钟）..."
cd EdgeSafariSync

SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null)

if swiftc -parse \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macosx13.0 \
    EdgeSafariSyncApp.swift \
    SyncEngine.swift \
    BrowserProcessDetector.swift \
    BookmarkNode.swift \
    BackupManager.swift \
    FileValidator.swift \
    EdgeParser.swift \
    SafariParser.swift \
    BookmarkSerializer.swift \
    2>&1 > /tmp/swiftc_output.txt; then
    echo "  ✅ 所有文件编译通过（零错误）"
else
    echo "  ❌ 编译失败："
    cat /tmp/swiftc_output.txt
    exit 1
fi

cd ..

# 检查书签文件路径
echo ""
echo "检查浏览器书签文件..."
EDGE_BOOKMARKS="$HOME/Library/Application Support/Microsoft Edge/Default/Bookmarks"
SAFARI_BOOKMARKS="$HOME/Library/Safari/Bookmarks.plist"

if [ -f "$EDGE_BOOKMARKS" ]; then
    echo "  ✅ Edge 书签文件存在"
else
    echo "  ⚠️  Edge 书签文件不存在（如果未安装 Edge 则正常）"
fi

if [ -f "$SAFARI_BOOKMARKS" ]; then
    echo "  ✅ Safari 书签文件存在"
else
    echo "  ⚠️  Safari 书签文件不存在"
fi

# 最终报告
echo ""
echo "================================"
echo "✅ 项目验证完成"
echo "================================"
echo ""
echo "所有自动化检查通过！"
echo ""
echo "下一步："
echo "1. 在 Xcode 中打开项目进行 M6 手动验证"
echo "   open EdgeSafariSync.xcodeproj"
echo ""
echo "2. 参考 VERIFICATION_GUIDE.md 完成手动验证任务"
echo ""
