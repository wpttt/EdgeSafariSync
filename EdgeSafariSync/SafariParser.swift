import Foundation

/// Parses Safari's Bookmarks.plist file and maps it to the BookmarkNode model.
///
/// Safari stores bookmarks in a binary plist file at ~/Library/Safari/Bookmarks.plist.
/// The plist structure uses WebBookmarkUUID, Title, URLString, Children, and WebBookmarkType keys.
///
/// Modern Safari (macOS 14+) may use NSKeyedArchiver format, which is **not** a plain dictionary
/// and cannot be parsed by this function. Callers should detect this via
/// `isSafariPlistKeyedArchive(data:)` and present an actionable error to the user.
func parseSafariBookmarks(fileURL: URL) throws -> [BookmarkNode] {
    // Read the plist file as data
    let data = try Data(contentsOf: fileURL)

    // Detect NSKeyedArchiver format used by modern Safari. Plain plists do not have these keys.
    if isSafariPlistKeyedArchive(data: data) {
        throw SafariParserError.keyedArchiveNotSupported
    }

    // Parse the binary plist format
    var format: PropertyListSerialization.PropertyListFormat = .binary
    guard let plist = try PropertyListSerialization.propertyList(
        from: data,
        options: .mutableContainers,
        format: &format
    ) as? [String: Any] else {
        throw SafariParserError.invalidPlistStructure("Root plist is not a dictionary")
    }

    // Extract the Children array from the root
    guard let childrenArray = plist["Children"] as? [[String: Any]] else {
        throw SafariParserError.invalidPlistStructure("Root plist missing 'Children' key")
    }

    // Convert plist dictionaries to BookmarkNode objects
    let bookmarks = try childrenArray.map { dict -> BookmarkNode in
        return try convertPlistDictToBookmarkNode(dict)
    }

    return bookmarks
}

/// Detects whether the given plist data is in NSKeyedArchiver format
/// (used by Safari on macOS 14+ / iCloud-synced Safari).
///
/// NSKeyedArchiver plists always contain a `$archiver` key at the root.
/// Plain Safari plists (macOS 13 and earlier) start with `Children`, `WebBookmarkType`, etc.
func isSafariPlistKeyedArchive(data: Data) -> Bool {
    // Fast path: check for the literal "$archiver" string in the first 4096 bytes
    // (NSKeyedArchiver plist root objects always contain this key).
    let probeRange = 0..<min(data.count, 4096)
    guard let probeString = String(data: data.subdata(in: probeRange), encoding: .utf8) else {
        return false
    }
    return probeString.contains("$archiver") || probeString.contains("$objects")
}

/// Ensures the given plist dictionary has all top-level keys required by Safari.
///
/// Safari expects at minimum:
/// - `WebBookmarkType` = "WebBookmarkTypeList"
/// - `WebBookmarkUUID` = stable UUID string
/// - `WebBookmarkFileVersion` = 1
/// - `Children` = array
///
/// Missing keys cause Safari to rebuild the file from scratch on next launch,
/// which destroys all bookmarks. This function fills in any missing required keys.
func ensureSafariPlistTopLevel(_ plist: inout [String: Any]) {
    if plist["WebBookmarkType"] as? String == nil {
        plist["WebBookmarkType"] = "WebBookmarkTypeList"
    }
    if plist["WebBookmarkUUID"] as? String == nil {
        plist["WebBookmarkUUID"] = UUID().uuidString
    }
    if plist["WebBookmarkFileVersion"] as? Int == nil,
       let asNumber = plist["WebBookmarkFileVersion"] as? NSNumber {
        plist["WebBookmarkFileVersion"] = asNumber.intValue
    } else if plist["WebBookmarkFileVersion"] == nil {
        plist["WebBookmarkFileVersion"] = 1
    }
    if plist["Children"] == nil {
        plist["Children"] = [] as [Any]
    }
    if plist["Title"] == nil {
        plist["Title"] = "Bookmarks"
    }
}

/// Converts a Safari plist dictionary to a BookmarkNode.
///
/// Recursively processes Children arrays for folder nodes.
private func convertPlistDictToBookmarkNode(_ dict: [String: Any]) throws -> BookmarkNode {
    // Extract required fields
    guard let uuid = dict["WebBookmarkUUID"] as? String else {
        throw SafariParserError.missingRequiredKey("WebBookmarkUUID")
    }
    
    guard let title = dict["Title"] as? String else {
        throw SafariParserError.missingRequiredKey("Title")
    }
    
    // Extract optional URL (only present for leaf nodes)
    let url = dict["URLString"] as? String
    
    // Extract optional Children array (only present for folder nodes)
    var children: [BookmarkNode]? = nil
    if let childrenArray = dict["Children"] as? [[String: Any]] {
        children = try childrenArray.map { childDict -> BookmarkNode in
            return try convertPlistDictToBookmarkNode(childDict)
        }
    }
    
    return BookmarkNode(id: uuid, title: title, url: url, children: children)
}

/// Errors that can occur during Safari plist parsing.
enum SafariParserError: LocalizedError {
    case invalidPlistStructure(String)
    case missingRequiredKey(String)
    case keyedArchiveNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidPlistStructure(let message):
            return "Invalid plist structure: \(message)"
        case .missingRequiredKey(let key):
            return "Missing required key in bookmark node: \(key)"
        case .keyedArchiveNotSupported:
            return "Safari's Bookmarks.plist uses NSKeyedArchiver format (introduced in Safari on macOS 14 with iCloud sync). "
                 + "This format cannot be safely edited by external tools. "
                 + "Workarounds: (1) Disable iCloud Safari bookmark sync in System Settings > Apple ID > iCloud > Show All > Safari Bookmarks (sync via iCloud disabled locally); "
                 + "(2) Export bookmarks from Safari via File > Export Bookmarks, then re-import manually. "
                 + "Tip: 在 macOS 14+/Tahoe 上, Safari 默认使用 iCloud 同步, 其 Bookmarks.plist 是 NSKeyedArchiver 加密归档格式, 外部工具无法安全修改。"
        }
    }
}
