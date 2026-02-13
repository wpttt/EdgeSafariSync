import Foundation

/// Parses Safari's Bookmarks.plist file and maps it to the BookmarkNode model.
///
/// Safari stores bookmarks in a binary plist file at ~/Library/Safari/Bookmarks.plist.
/// The plist structure uses WebBookmarkUUID, Title, URLString, Children, and WebBookmarkType keys.
func parseSafariBookmarks(fileURL: URL) throws -> [BookmarkNode] {
    // Read the plist file as data
    let data = try Data(contentsOf: fileURL)
    
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
    
    var errorDescription: String? {
        switch self {
        case .invalidPlistStructure(let message):
            return "Invalid plist structure: \(message)"
        case .missingRequiredKey(let key):
            return "Missing required key in bookmark node: \(key)"
        }
    }
}
