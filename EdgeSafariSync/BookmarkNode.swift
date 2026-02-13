import Foundation

/// A hierarchical bookmark model supporting both Safari and Edge bookmark formats.
///
/// `BookmarkNode` represents a single node in a bookmark tree that can be either:
/// - A folder (with `children` array, `url` is nil)
/// - A URL bookmark (with `url` string, `children` is nil)
///
/// The model conforms to `Codable` for seamless serialization/deserialization
/// with JSON (Edge format) and Plist (Safari format) formats.
struct BookmarkNode: Codable, Identifiable {
    
    /// Unique identifier for the bookmark node
    let id: String
    
    /// Display name for the bookmark or folder
    let title: String
    
    /// Optional URL address. Present for URL bookmarks, nil for folders.
    /// - Note: Folders should have `nil` value; URL bookmarks should have a valid string.
    let url: String?
    
    /// Optional array of child bookmark nodes. Present for folders, nil for URL bookmarks.
    /// - Note: Folders should have a non-nil array (may be empty); URL bookmarks should have `nil`.
    let children: [BookmarkNode]?
    
    /// Initializes a new BookmarkNode.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the node
    ///   - title: Display name for the bookmark or folder
    ///   - url: Optional URL (nil for folders)
    ///   - children: Optional array of child nodes (nil for URL bookmarks)
    init(id: String, title: String, url: String? = nil, children: [BookmarkNode]? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.children = children
    }
}
