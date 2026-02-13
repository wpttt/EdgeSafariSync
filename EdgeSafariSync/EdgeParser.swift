import Foundation

/// Parses bookmarks from Microsoft Edge's JSON bookmark file and converts them to BookmarkNode model.
/// 
/// Edge stores bookmarks in a JSON format with a hierarchical structure containing three root folders:
/// - `bookmark_bar`: Bookmarks bar entries
/// - `other`: Other bookmarks folder
/// - `synced`: Synced bookmarks (if using Edge sync)
///
/// Example Edge JSON structure:
/// ```json
/// {
///   "roots": {
///     "bookmark_bar": {
///       "id": "1",
///       "name": "Bookmarks Bar",
///       "type": "folder",
///       "children": [...]
///     },
///     "other": {...},
///     "synced": {...}
///   }
/// }
/// ```

// MARK: - Intermediate Codable Structures for Edge JSON Format

/// Represents the root structure of Edge's bookmarks JSON file.
private struct EdgeRootsContainer: Codable {
    let roots: EdgeRoots
}

/// Contains the three root folders in Edge's bookmark system.
private struct EdgeRoots: Codable {
    let bookmark_bar: EdgeNode?
    let other: EdgeNode?
    let synced: EdgeNode?
    
    enum CodingKeys: String, CodingKey {
        case bookmark_bar = "bookmark_bar"
        case other = "other"
        case synced = "synced"
    }
}

/// Represents a single node in Edge's bookmark JSON hierarchy.
/// Can be either a folder (with children) or a URL bookmark.
private struct EdgeNode: Codable {
    let id: String
    let name: String
    let type: String  // "folder" or "url"
    let url: String?  // Present only for URL type
    let children: [EdgeNode]?
}

// MARK: - Parser Function

/// Parses bookmarks from an Edge JSON file and maps them to BookmarkNode model.
///
/// - Parameter fileURL: URL pointing to Edge's Bookmarks JSON file
/// - Returns: Array of root-level BookmarkNode objects (one for each root folder: bookmark_bar, other, synced)
/// - Throws: `ParseError.fileNotFound` if file doesn't exist
/// - Throws: `ParseError.invalidJSON` if JSON is malformed
/// - Throws: Any error from file I/O operations
///
/// Example usage:
/// ```swift
/// let edgeBookmarksPath = URL(fileURLWithPath: "~/Library/Application Support/Microsoft Edge/Default/Bookmarks")
/// let bookmarks = try parseEdgeBookmarks(fileURL: edgeBookmarksPath)
/// ```
func parseEdgeBookmarks(fileURL: URL) throws -> [BookmarkNode] {
    // Read file contents
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw ParseError.fileNotFound(fileURL.path)
    }
    
    let data = try Data(contentsOf: fileURL)
    
    // Decode JSON into intermediate Edge structure
    let decoder = JSONDecoder()
    let container: EdgeRootsContainer
    do {
        container = try decoder.decode(EdgeRootsContainer.self, from: data)
    } catch {
        throw ParseError.invalidJSON(error.localizedDescription)
    }
    
    // Convert intermediate structures to BookmarkNode, collecting all roots
    var result: [BookmarkNode] = []
    
    // Process each root folder
    if let bookmarkBar = container.roots.bookmark_bar {
        result.append(convertEdgeNodeToBookmarkNode(bookmarkBar))
    }
    if let other = container.roots.other {
        result.append(convertEdgeNodeToBookmarkNode(other))
    }
    if let synced = container.roots.synced {
        result.append(convertEdgeNodeToBookmarkNode(synced))
    }
    
    return result
}

// MARK: - Conversion Helper

/// Recursively converts an Edge JSON node to a BookmarkNode.
///
/// - Parameter edgeNode: The Edge node to convert
/// - Returns: Corresponding BookmarkNode with all children recursively converted
private func convertEdgeNodeToBookmarkNode(_ edgeNode: EdgeNode) -> BookmarkNode {
    // Recursively convert children if present
    let convertedChildren = edgeNode.children?.map { convertEdgeNodeToBookmarkNode($0) }
    
    return BookmarkNode(
        id: edgeNode.id,
        title: edgeNode.name,
        url: edgeNode.url,
        children: convertedChildren
    )
}

// MARK: - Error Handling

/// Errors that can occur during Edge bookmark parsing.
enum ParseError: Error, LocalizedError {
    /// File not found at the specified path.
    case fileNotFound(String)
    
    /// JSON is invalid or doesn't match expected Edge format.
    case invalidJSON(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Edge bookmarks file not found at: \(path)"
        case .invalidJSON(let details):
            return "Invalid or malformed Edge bookmarks JSON: \(details)"
        }
    }
}
