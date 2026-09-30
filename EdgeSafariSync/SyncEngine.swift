import Foundation

// MARK: - Main Sync Function

/// Synchronizes bookmarks from Microsoft Edge to Safari.
///
/// This function performs a complete Edge → Safari sync operation with full error recovery:
/// 1. Validates that both Edge and Safari bookmark files exist and are readable
/// 2. Creates a backup of the Safari bookmarks file (for rollback on failure)
/// 3. Reads bookmarks from Edge's JSON format
/// 4. Serializes the bookmarks to Safari's plist format
/// 5. Writes the new bookmarks to Safari's file location
/// 6. If any step fails, automatically restores from backup
///
/// - Throws: `SyncError` with specific error context (validation, parsing, serialization, file write, or restore)
/// - Returns: Void on success
///
/// # Example Usage
/// ```swift
/// do {
///     try syncEdgeToSafari()
///     print("Sync completed successfully")
/// } catch let error as SyncError {
///     print("Sync failed: \(error.localizedDescription)")
/// }
/// ```
///
/// # Error Recovery
/// If any step after backup creation fails, the function automatically attempts to restore
/// the Safari bookmarks from backup. The original error is re-thrown after restore attempt.
func syncEdgeToSafari() throws {
    // MARK: Validation Phase

    let edgeURL: URL
    let safariURL: URL

    do {
        edgeURL = try validateEdgeBookmarks()
        safariURL = try validateSafariBookmarks()
    } catch let error as ValidationError {
        // Only treat EACCES/EPERM as permission denied. Other errnos (ENOENT, ENOATTR, EBUSY)
        // are reported as validation failures so the user sees the actual problem.
        if case let .fileNotReadable(_, errno) = error, errno == EACCES || errno == EPERM {
            throw SyncError.permissionDenied
        }
        throw SyncError.validationFailed(error.localizedDescription)
    } catch {
        throw SyncError.validationFailed(error.localizedDescription)
    }

    // MARK: Browser Detection

    if BrowserProcessDetector.isSafariRunning() {
        throw SyncError.browserRunning("Safari")
    }

    // MARK: Backup Phase

    let backupURL: URL
    do {
        backupURL = try BackupManager.createBackup(fileURL: safariURL)
    } catch {
        throw SyncError.backupFailed(error.localizedDescription)
    }

    // MARK: Sync Phase with Error Recovery

    do {
        // Step 1: Parse Edge bookmarks and extract 收藏夹栏
        let edgeNodes: [BookmarkNode]
        do {
            edgeNodes = try parseEdgeBookmarks(fileURL: edgeURL)
        } catch {
            throw SyncError.parsingFailed("Edge bookmarks", error.localizedDescription)
        }

        let edgeBar = extractEdgeBookmarksBarFolder(from: edgeNodes)

        // Step 2: Read Safari plist as raw dictionary (preserve ALL original structure).
        // Refuse NSKeyedArchiver-format plists; they cannot be safely re-encoded.
        let safariData = try Data(contentsOf: safariURL)
        if isSafariPlistKeyedArchive(data: safariData) {
            throw SyncError.parsingFailed(
                "Safari bookmarks",
                SafariParserError.keyedArchiveNotSupported.errorDescription
                    ?? "Safari Bookmarks.plist uses NSKeyedArchiver format and cannot be safely modified."
            )
        }
        var format: PropertyListSerialization.PropertyListFormat = .binary
        guard var safariPlist = try PropertyListSerialization.propertyList(
            from: safariData,
            options: .mutableContainersAndLeaves,
            format: &format
        ) as? [String: Any] else {
            throw SyncError.parsingFailed("Safari bookmarks", "Root plist is not a dictionary")
        }

        // Step 2.5: Ensure the top-level plist has every key Safari requires.
        // A missing WebBookmarkFileVersion / WebBookmarkType causes Safari to rebuild the file
        // from scratch on next launch, destroying all bookmarks.
        ensureSafariPlistTopLevel(&safariPlist)

        // Step 3: Convert Edge 收藏夹栏 to Safari plist dict
        let edgeBarDict = convertBookmarkNodeToSafariDict(edgeBar)

        // Step 4: Insert or replace 收藏夹栏 in Safari root Children
        var rootChildren = safariPlist["Children"] as? [[String: Any]] ?? []

        let matchTitles: Set<String> = ["收藏夹栏", "书签栏", "Bookmarks Bar", "Favorites Bar"]
        var didReplace = false
        for i in 0..<rootChildren.count {
            let title = rootChildren[i]["Title"] as? String ?? ""
            let nodeType = rootChildren[i]["WebBookmarkType"] as? String ?? ""
            if matchTitles.contains(title) && nodeType == "WebBookmarkTypeList" {
                rootChildren[i] = edgeBarDict
                didReplace = true
                break
            }
        }

        if !didReplace {
            // Insert after BookmarksBar (个人收藏) if it exists, otherwise at position 0
            var insertIndex = 0
            for i in 0..<rootChildren.count {
                let title = rootChildren[i]["Title"] as? String ?? ""
                if title == "BookmarksBar" {
                    insertIndex = i + 1
                    break
                }
            }
            rootChildren.insert(edgeBarDict, at: insertIndex)
        }

        safariPlist["Children"] = rootChildren

        // Step 5: Write modified plist back to disk using the SAME format we read it with
        // (writing binary would force Safari to re-parse; writing XML would corrupt NSKeyedArchiver refs).
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: safariPlist,
            format: format,
            options: 0
        )
        try plistData.write(to: safariURL, options: .atomic)

    } catch {
        // On any error, attempt to restore from backup
        do {
            try BackupManager.restoreFromBackup(backupURL: backupURL, toOriginalURL: safariURL)
        } catch {
            throw SyncError.restoreFailed(
                "Backup restore failed after sync error. Original error: \(error)"
            )
        }
        throw error
    }
}

/// Synchronizes bookmarks from Safari to Microsoft Edge.
///
/// Reads Safari's 收藏夹栏 (Favorites Bar) and replaces Edge's bookmark_bar children
/// with the converted content. Preserves all original Edge JSON metadata fields.
func syncSafariToEdge() throws {
    let safariURL: URL
    let edgeURL: URL

    do {
        safariURL = try validateSafariBookmarks()
        edgeURL = try validateEdgeBookmarks()
    } catch let error as ValidationError {
        if case let .fileNotReadable(_, errno) = error, errno == EACCES || errno == EPERM {
            throw SyncError.permissionDenied
        }
        throw SyncError.validationFailed(error.localizedDescription)
    } catch {
        throw SyncError.validationFailed(error.localizedDescription)
    }

    if BrowserProcessDetector.isEdgeRunning() {
        throw SyncError.browserRunning("Microsoft Edge")
    }

    let backupURL: URL
    do {
        backupURL = try BackupManager.createBackup(fileURL: edgeURL)
    } catch {
        throw SyncError.backupFailed(error.localizedDescription)
    }

    do {
        // Step 1: Read Safari plist and extract 收藏夹栏 children
        let safariData = try Data(contentsOf: safariURL)

        // Refuse to touch NSKeyedArchiver-format plists (used by Safari on macOS 14+ with iCloud sync).
        if isSafariPlistKeyedArchive(data: safariData) {
            throw SyncError.parsingFailed(
                "Safari bookmarks",
                SafariParserError.keyedArchiveNotSupported.errorDescription
                    ?? "Safari Bookmarks.plist uses NSKeyedArchiver format and cannot be safely modified."
            )
        }

        var plistFormat: PropertyListSerialization.PropertyListFormat = .binary
        guard let safariPlist = try PropertyListSerialization.propertyList(
            from: safariData,
            options: .mutableContainersAndLeaves,
            format: &plistFormat
        ) as? [String: Any] else {
            throw SyncError.parsingFailed("Safari bookmarks", "Root plist is not a dictionary")
        }

        let safariRootChildren = safariPlist["Children"] as? [[String: Any]] ?? []
        let safariBarChildren = extractSafariFavoritesBarChildren(from: safariRootChildren)

        // Step 2: Read Edge JSON as raw dictionary (preserve ALL original fields)
        let edgeData = try Data(contentsOf: edgeURL)
        guard var edgeDict = try JSONSerialization.jsonObject(with: edgeData) as? [String: Any],
              var roots = edgeDict["roots"] as? [String: Any],
              var bookmarkBar = roots["bookmark_bar"] as? [String: Any] else {
            throw SyncError.parsingFailed("Edge bookmarks", "Invalid Edge JSON structure")
        }

        // Step 3: Non-destructive import. Append an "Imported from Safari" folder to the
        // existing Edge bookmark_bar children instead of replacing them. If such a folder
        // already exists from a previous sync, append to it (deduped by URL).
        var existingChildren = bookmarkBar["children"] as? [[String: Any]] ?? []

        let importFolderTitle = "Imported from Safari"
        let safariNodes = safariBarChildren.map { convertSafariDictToEdgeDict($0) }

        if let existingIndex = existingChildren.firstIndex(where: {
            ($0["name"] as? String) == importFolderTitle && ($0["type"] as? String) == "folder"
        }) {
            // Append into existing import folder (dedupe by URL).
            var folder = existingChildren[existingIndex]
            var folderKids = folder["children"] as? [[String: Any]] ?? []
            let existingURLs = Set(folderKids.compactMap { $0["url"] as? String })
            for node in safariNodes where !(existingURLs.contains(node["url"] as? String ?? "__folder__")) {
                folderKids.append(node)
            }
            folder["children"] = folderKids
            folder["date_modified"] = webkitTimestamp(now: Date())
            existingChildren[existingIndex] = folder
        } else {
            // Create a new top-level import folder.
            let importFolder: [String: Any] = [
                "id": nextEdgeId(),
                "guid": stableSafariUUID(from: "edge-imported-from-safari-\(Int(Date().timeIntervalSince1970))"),
                "name": importFolderTitle,
                "type": "folder",
                "date_added": webkitTimestamp(now: Date()),
                "date_modified": webkitTimestamp(now: Date()),
                "source": "unknown",
                "children": safariNodes
            ]
            existingChildren.append(importFolder)
        }

        bookmarkBar["children"] = existingChildren
        bookmarkBar["date_modified"] = webkitTimestamp(now: Date())
        roots["bookmark_bar"] = bookmarkBar
        edgeDict["roots"] = roots

        // Step 4: Write back with pretty print to match Edge format
        let outputData = try JSONSerialization.data(withJSONObject: edgeDict, options: [.prettyPrinted])
        try outputData.write(to: edgeURL, options: .atomic)

    } catch {
        do {
            try BackupManager.restoreFromBackup(backupURL: backupURL, toOriginalURL: edgeURL)
        } catch {
            throw SyncError.restoreFailed(
                "Backup restore failed after sync error. Original error: \(error)"
            )
        }
        throw error
    }
}

private func extractEdgeBookmarksBarFolder(from edgeNodes: [BookmarkNode]) -> BookmarkNode {
    let candidates = ["Bookmarks Bar", "收藏夹栏", "书签栏", "Favorites Bar"]
    if let match = edgeNodes.first(where: { candidates.contains($0.title) }) {
        return BookmarkNode(
            id: match.id,
            title: "收藏夹栏",
            url: nil,
            children: match.children
        )
    }
    return BookmarkNode(
        id: UUID().uuidString,
        title: "收藏夹栏",
        url: nil,
        children: edgeNodes
    )
}

private func convertBookmarkNodeToSafariDict(_ node: BookmarkNode) -> [String: Any] {
    var dict: [String: Any] = [:]
    dict["WebBookmarkUUID"] = normalizedSafariUUID(node.id)

    let isFolder = node.url == nil
    dict["WebBookmarkType"] = isFolder ? "WebBookmarkTypeList" : "WebBookmarkTypeLeaf"

    if isFolder {
        dict["Title"] = node.title
        let children = node.children ?? []
        dict["Children"] = children.map { convertBookmarkNodeToSafariDict($0) }
    } else {
        dict["URLString"] = node.url
        dict["URIDictionary"] = ["title": node.title]
    }

    return dict
}

private func normalizedSafariUUID(_ value: String) -> String {
    return stableSafariUUID(from: value)
}

// MARK: - Safari → Edge Helpers

private func extractSafariFavoritesBarChildren(from rootChildren: [[String: Any]]) -> [[String: Any]] {
    let barTitles: Set<String> = ["BookmarksBar", "收藏夹栏", "书签栏", "Bookmarks Bar", "Favorites Bar"]
    var bestChildren: [[String: Any]] = []
    for child in rootChildren {
        let title = child["Title"] as? String ?? ""
        let nodeType = child["WebBookmarkType"] as? String ?? ""
        if barTitles.contains(title) && nodeType == "WebBookmarkTypeList" {
            let children = child["Children"] as? [[String: Any]] ?? []
            if children.count > bestChildren.count {
                bestChildren = children
            }
        }
    }
    return bestChildren
}

private var edgeIdCounter: Int = 1000

private func nextEdgeId() -> String {
    edgeIdCounter += 1
    return String(edgeIdCounter)
}

private func convertSafariDictToEdgeDict(_ safariNode: [String: Any]) -> [String: Any] {
    let nodeType = safariNode["WebBookmarkType"] as? String ?? ""
    let isFolder = nodeType == "WebBookmarkTypeList"

    var edgeNode: [String: Any] = [:]
    edgeNode["id"] = nextEdgeId()
    let sourceUUIDString = (safariNode["WebBookmarkUUID"] as? String) ?? UUID().uuidString
    edgeNode["guid"] = stableSafariUUID(from: sourceUUIDString)
    edgeNode["date_added"] = webkitTimestamp(now: Date())
    edgeNode["date_last_used"] = webkitTimestamp(now: Date())
    edgeNode["source"] = "unknown"

    if isFolder {
        let title = safariNode["Title"] as? String ?? ""
        edgeNode["name"] = title
        edgeNode["type"] = "folder"
        edgeNode["date_modified"] = webkitTimestamp(now: Date())
        let children = safariNode["Children"] as? [[String: Any]] ?? []
        edgeNode["children"] = children.map { convertSafariDictToEdgeDict($0) }
    } else {
        let uriDict = safariNode["URIDictionary"] as? [String: Any]
        let title = uriDict?["title"] as? String ?? safariNode["Title"] as? String ?? ""
        edgeNode["name"] = title
        edgeNode["type"] = "url"
        edgeNode["url"] = safariNode["URLString"] as? String ?? ""
    }

    return edgeNode
}

/// Converts a Date to Chrome/Edge's WebKit timestamp format (microseconds since 1601-01-01 UTC).
///
/// Chrome/Edge use Windows FILETIME-style 64-bit integer timestamps measured in microseconds
/// since the Windows epoch (1601-01-01 00:00:00 UTC). Using "0" causes Edge to silently drop the
/// bookmark or display it incorrectly.
func webkitTimestamp(now: Date) -> String {
    // Reference epoch: 1601-01-01 00:00:00 UTC
    let unixToWebkit: Double = 11644473600.0
    let micros = (now.timeIntervalSince1970 + unixToWebkit) * 1_000_000
    return String(Int64(micros))
}

/// Errors that can occur during Edge → Safari synchronization.
enum SyncError: LocalizedError {
    /// Validation of file existence/readability failed
    case validationFailed(String)
    
    /// Backup creation failed
    case backupFailed(String)
    
    /// Parsing bookmarks from source format failed
    case parsingFailed(String, String)
    
    /// Serializing bookmarks to target format failed
    case serializationFailed(String, String)
    
    /// Restoring from backup failed (indicates critical failure)
    case restoreFailed(String)
    
    /// A browser (Edge or Safari) is currently running and blocking the sync
    case browserRunning(String)
    
    /// Permission denied (Full Disk Access required)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .validationFailed(let details):
            return "Validation failed: \(details)"
        case .backupFailed(let details):
            return "Backup creation failed: \(details)"
        case .parsingFailed(let source, let details):
            return "Failed to parse \(source): \(details)"
        case .serializationFailed(let target, let details):
            return "Failed to serialize to \(target): \(details)"
        case .restoreFailed(let details):
            return "Critical error - backup restore failed: \(details)"
        case .browserRunning(let browserName):
            return "Cannot sync: \(browserName) is currently running. Please quit \(browserName) and try again."
        case .permissionDenied:
            return "Access denied. Please grant Full Disk Access in System Settings."
        }
    }
}
