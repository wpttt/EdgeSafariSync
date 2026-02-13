import Foundation

// MARK: - Edge JSON Serialization

/// Serializes BookmarkNode array to Edge JSON format and writes to file.
///
/// Edge bookmarks are stored in JSON format with a `roots` structure containing
/// different root folders (bookmark_bar, other, synced).
///
/// - Parameters:
///   - nodes: Array of BookmarkNode objects to serialize
///   - toFileURL: File URL where the JSON should be written
/// - Throws: FileManager errors or JSONEncoder errors
func serializeToEdgeJSON(nodes: [BookmarkNode], toFileURL: URL) throws {
    let edgeRoot = convertNodesToEdgeRoot(nodes: nodes)
    let jsonData = try JSONEncoder().encode(edgeRoot)
    try jsonData.write(to: toFileURL, options: .atomic)
}

/// Intermediate structure for Edge JSON format - matches the file structure.
private struct EdgeRoot: Codable {
    let roots: EdgeRoots
    
    enum CodingKeys: String, CodingKey {
        case roots
    }
}

/// Container for Edge bookmark roots.
private struct EdgeRoots: Codable {
    let bookmark_bar: EdgeNode
    let other: EdgeNode
    let synced: EdgeNode?
    
    enum CodingKeys: String, CodingKey {
        case bookmark_bar
        case other
        case synced
    }
}

/// Edge JSON node representation.
private struct EdgeNode: Codable {
    let id: String
    let name: String
    let type: String
    let children: [EdgeNode]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case children
    }
}

/// Converts BookmarkNode array to Edge root structure.
/// Creates default bookmark_bar and other roots, distributing nodes appropriately.
private func convertNodesToEdgeRoot(nodes: [BookmarkNode]) -> EdgeRoot {
    let bookmarkBarNode = EdgeNode(
        id: "1",
        name: "Bookmarks Bar",
        type: "folder",
        children: nodes.map { convertNodeToEdgeNode($0) }
    )
    
    let otherNode = EdgeNode(
        id: "2",
        name: "Other Bookmarks",
        type: "folder",
        children: []
    )
    
    let syncedNode = EdgeNode(
        id: "3",
        name: "Synced",
        type: "folder",
        children: nil
    )
    
    return EdgeRoot(
        roots: EdgeRoots(
            bookmark_bar: bookmarkBarNode,
            other: otherNode,
            synced: syncedNode
        )
    )
}

/// Converts a single BookmarkNode to Edge JSON node format.
private func convertNodeToEdgeNode(_ node: BookmarkNode) -> EdgeNode {
    let type: String
    if let children = node.children, !children.isEmpty {
        type = "folder"
    } else if node.url != nil {
        type = "url"
    } else {
        type = "folder"
    }
    
    let edgeChildren: [EdgeNode]?
    if let children = node.children {
        edgeChildren = children.map { convertNodeToEdgeNode($0) }
    } else {
        edgeChildren = nil
    }
    
    return EdgeNode(
        id: node.id,
        name: node.title,
        type: type,
        children: edgeChildren
    )
}

// MARK: - Safari Plist Serialization

/// Serializes BookmarkNode array to Safari Plist format and writes to file.
///
/// Safari bookmarks are stored in binary Plist format with a root dictionary
/// containing a `Children` array.
///
/// - Parameters:
///   - nodes: Array of BookmarkNode objects to serialize
///   - toFileURL: File URL where the Plist should be written
/// - Throws: FileManager errors or PropertyListSerialization errors
func serializeToSafariPlist(nodes: [BookmarkNode], toFileURL: URL) throws {
    let safariRoot = convertNodesToSafariRoot(nodes: nodes)
    let plistData = try PropertyListSerialization.data(
        fromPropertyList: safariRoot,
        format: .binary,
        options: 0
    )
    try plistData.write(to: toFileURL, options: .atomic)
}

/// Converts BookmarkNode array to Safari Plist root dictionary.
/// Creates a root dictionary with a `Children` array.
private func convertNodesToSafariRoot(nodes: [BookmarkNode]) -> [String: Any] {
    var root: [String: Any] = [:]
    root["Title"] = "Bookmarks"
    root["WebBookmarkUUID"] = UUID().uuidString
    root["WebBookmarkType"] = "WebBookmarkTypeList"
    root["WebBookmarkFileVersion"] = 1
    root["Children"] = nodes.map { convertNodeToSafariDict($0) }
    return root
}

/// Converts a single BookmarkNode to Safari Plist dictionary format.
private func convertNodeToSafariDict(_ node: BookmarkNode) -> [String: Any] {
    var dict: [String: Any] = [:]
    
    dict["WebBookmarkUUID"] = normalizedSafariUUID(node.id)
    dict["Title"] = node.title
    
    let isFolder = node.url == nil
    let webBookmarkType = isFolder ? "WebBookmarkTypeList" : "WebBookmarkTypeLeaf"
    dict["WebBookmarkType"] = webBookmarkType
    
    // Add URL if this is a URL bookmark
    if let url = node.url {
        dict["URLString"] = url
        dict["URIDictionary"] = ["title": node.title]
    }
    
    // Add children if this is a folder
    if let children = node.children {
        dict["Children"] = children.map { convertNodeToSafariDict($0) }
    }
    
    return dict
}

private func normalizedSafariUUID(_ value: String) -> String {
    if UUID(uuidString: value) != nil {
        return value
    }
    return UUID().uuidString
}
