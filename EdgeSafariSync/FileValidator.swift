import Foundation

// MARK: - Validation Error Enum

/// Errors that can occur during file validation.
enum ValidationError: LocalizedError {
    case fileNotFound(String)
    case fileNotReadable(String)
    case fileEmpty(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            let normalizedPath = normalizePathForDisplay(path)
            return "File not found at path: \(normalizedPath)"
        case .fileNotReadable(let path):
            let normalizedPath = normalizePathForDisplay(path)
            var message = "File is not readable at path: \(normalizedPath)"
            if normalizedPath.contains("/Library/Safari/Bookmarks.plist") {
                message += "\nHint: Grant Full Disk Access to Xcode and EdgeSafariSync in System Settings > Privacy & Security > Full Disk Access."
                message += "\nHint: If launched from Xcode, grant Xcode and EdgeSafariSync.app, then fully quit and relaunch."
                message += "\nCurrent app path: \(Bundle.main.bundlePath)"
                message += "\n提示：请在【系统设置 > 隐私与安全性 > 完全磁盘访问权限】中同时授权 Xcode 与 EdgeSafariSync。"
                message += "\n提示：若从 Xcode 运行，请给 Xcode 和 EdgeSafariSync.app 授权后，完全退出并重新打开。"
            }
            return message
        case .fileEmpty(let path):
            let normalizedPath = normalizePathForDisplay(path)
            return "File is empty (0 bytes) at path: \(normalizedPath)"
        }
    }
}

private func normalizePathForDisplay(_ path: String) -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.replacingOccurrences(of: "/Safari/ ", with: "/Safari/")
}

// MARK: - File Validation Functions

/// Validates that a bookmark file exists, is readable, and is non-empty.
///
/// - Parameter fileURL: The URL of the file to validate
/// - Returns: `true` if all validation checks pass
/// - Throws: `ValidationError` if any check fails
///
/// This function performs three checks:
/// 1. File exists at the given path
/// 2. File is readable by the current process
/// 3. File size is greater than 0 bytes
///
/// Example usage:
/// ```swift
/// do {
///     let isValid = try validateBookmarkFile(fileURL: bookmarksURL)
///     print("File is valid: \(isValid)")
/// } catch let error as ValidationError {
///     print("Validation failed: \(error.localizedDescription)")
/// }
/// ```
func validateBookmarkFile(fileURL: URL) throws -> Bool {
    let fileManager = FileManager.default
    let filePath = fileURL.path
    
    // Check if file exists
    guard fileManager.fileExists(atPath: filePath) else {
        throw ValidationError.fileNotFound(filePath)
    }
    
    // Check if file is readable
    guard fileManager.isReadableFile(atPath: filePath) else {
        throw ValidationError.fileNotReadable(filePath)
    }
    
    // Check if file is non-empty
    do {
        let attributes = try fileManager.attributesOfItem(atPath: filePath)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.intValue > 0 else {
            throw ValidationError.fileEmpty(filePath)
        }
    } catch is ValidationError {
        throw ValidationError.fileEmpty(filePath)
    }
    
    return true
}

/// Validates the Edge browser bookmarks file.
///
/// Uses the standard Edge bookmarks location:
/// `~/Library/Application Support/Microsoft Edge/Default/Bookmarks`
///
/// - Returns: The validated file URL
/// - Throws: `ValidationError` if the file doesn't exist, isn't readable, or is empty
///
/// Example usage:
/// ```swift
/// do {
///     let edgeURL = try validateEdgeBookmarks()
///     // Safe to proceed with parsing
///     let bookmarks = try parseEdgeBookmarks(fileURL: edgeURL)
/// } catch {
///     print("Edge bookmarks unavailable: \(error)")
/// }
/// ```
func validateEdgeBookmarks() throws -> URL {
    let edgeBookmarksPath = "~/Library/Application Support/Microsoft Edge/Default/Bookmarks"
    let trimmedPath = edgeBookmarksPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let expandedPath = (trimmedPath as NSString).expandingTildeInPath
    let defaultURL = URL(fileURLWithPath: expandedPath)

    let selectedURL = selectMostRecentEdgeBookmarksURL(defaultURL: defaultURL)
    _ = try validateBookmarkFile(fileURL: selectedURL)
    return selectedURL
}

/// Validates the Safari browser bookmarks file.
///
/// Uses the standard Safari bookmarks location:
/// `~/Library/Safari/Bookmarks.plist`
///
/// - Returns: The validated file URL
/// - Throws: `ValidationError` if the file doesn't exist, isn't readable, or is empty
///
/// Example usage:
/// ```swift
/// do {
///     let safariURL = try validateSafariBookmarks()
///     // Safe to proceed with parsing
///     let bookmarks = try parseSafariBookmarks(fileURL: safariURL)
/// } catch {
///     print("Safari bookmarks unavailable: \(error)")
/// }
/// ```
func validateSafariBookmarks() throws -> URL {
    let safariBookmarksPath = "~/Library/Safari/Bookmarks.plist"
    let trimmedPath = safariBookmarksPath.trimmingCharacters(in: .whitespacesAndNewlines)
    let expandedPath = (trimmedPath as NSString).expandingTildeInPath
    let fileURL = URL(fileURLWithPath: expandedPath)
    
    _ = try validateBookmarkFile(fileURL: fileURL)
    return fileURL
}

private func selectMostRecentEdgeBookmarksURL(defaultURL: URL) -> URL {
    let fileManager = FileManager.default
    let baseDirectory = defaultURL.deletingLastPathComponent().deletingLastPathComponent()

    guard let directoryContents = try? fileManager.contentsOfDirectory(
        at: baseDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return defaultURL
    }

    var candidates: [URL] = []
    for entry in directoryContents {
        guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey]),
              values.isDirectory == true else {
            continue
        }

        candidates.append(contentsOf: edgeBookmarkCandidates(in: entry))
    }

    guard !candidates.isEmpty else {
        return defaultURL
    }

    var mostRecentURL = defaultURL
    var mostRecentDate: Date? = (try? fileManager.attributesOfItem(atPath: defaultURL.path)[.modificationDate]) as? Date

    for candidate in candidates {
        let attributes = try? fileManager.attributesOfItem(atPath: candidate.path)
        let candidateDate = attributes?[.modificationDate] as? Date
        if mostRecentDate == nil || (candidateDate ?? .distantPast) > (mostRecentDate ?? .distantPast) {
            mostRecentDate = candidateDate
            mostRecentURL = candidate
        }
    }

    return mostRecentURL
}

private func edgeBookmarkCandidates(in profileDirectory: URL) -> [URL] {
    let fileManager = FileManager.default
    let bookmarksFileName = "Bookmarks"

    guard let contents = try? fileManager.contentsOfDirectory(
        at: profileDirectory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return contents.filter { url in
        let fileName = url.lastPathComponent
        guard fileName == bookmarksFileName else {
            return false
        }
        let isRegularFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
        return isRegularFile
    }
}
