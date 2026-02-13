import Foundation

// MARK: - Errors

enum BackupError: LocalizedError {
    case sourceFileNotFound(URL)
    case backupCreationFailed(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sourceFileNotFound(let url):
            return "Source file not found: \(url.path)"
        case .backupCreationFailed(let message):
            return "Failed to create backup: \(message)"
        case .restoreFailed(let message):
            return "Failed to restore from backup: \(message)"
        }
    }
}

// MARK: - BackupManager

/// Manages file backups before modifications to ensure data safety.
/// 
/// Provides functions to create and restore file backups with support for
/// multiple backup versions using timestamps to avoid overwriting existing backups.
struct BackupManager {
    
    // MARK: - Public Methods
    
    /// Creates a backup copy of a file before modification.
    /// 
    /// - Parameters:
    ///   - fileURL: The URL of the file to backup
    /// - Returns: The URL of the created backup file
    /// - Throws: `BackupError` if backup creation fails, or Foundation errors from FileManager
    /// 
    /// The backup file is created in the same directory as the original file with a ".bak"
    /// extension. If a ".bak" file already exists, a timestamped backup is created instead
    /// (e.g., "Bookmarks.plist.bak.20260212_181500") to preserve the previous backup.
    /// 
    /// Example:
    /// ```swift
    /// let safariURL = URL(fileURLWithPath: "~/Library/Safari/Bookmarks.plist")
    /// let backupURL = try BackupManager.createBackup(fileURL: safariURL)
    /// // Original file: ~/Library/Safari/Bookmarks.plist
    /// // Backup file:   ~/Library/Safari/Bookmarks.plist.bak (or with timestamp)
    /// ```
    static func createBackup(fileURL: URL) throws -> URL {
        let fileManager = FileManager.default
        
        // Verify source file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw BackupError.sourceFileNotFound(fileURL)
        }
        
        // Build backup URL with .bak extension
        var backupURL = fileURL.appendingPathExtension("bak")
        
        // If .bak already exists, create timestamped backup to preserve it
        if fileManager.fileExists(atPath: backupURL.path) {
            let timestamp = createTimestamp()
            backupURL = fileURL.appendingPathExtension("bak.\(timestamp)")
        }
        
        do {
            try fileManager.copyItem(at: fileURL, to: backupURL)
            return backupURL
        } catch {
            throw BackupError.backupCreationFailed(error.localizedDescription)
        }
    }
    
    /// Restores a file from its backup copy.
    /// 
    /// - Parameters:
    ///   - backupURL: The URL of the backup file to restore from
    ///   - toOriginalURL: The URL where the file should be restored to
    /// - Throws: `BackupError` if restoration fails, or Foundation errors from FileManager
    /// 
    /// Overwrites the file at `toOriginalURL` with the contents of the backup file.
    /// Use this function if the sync process fails and you need to revert to the
    /// previously backed-up version.
    /// 
    /// Example:
    /// ```swift
    /// let safariURL = URL(fileURLWithPath: "~/Library/Safari/Bookmarks.plist")
    /// let backupURL = try BackupManager.createBackup(fileURL: safariURL)
    /// 
    /// do {
    ///     // Attempt sync operation
    ///     try performSync()
    /// } catch {
    ///     // If sync fails, restore from backup
    ///     try BackupManager.restoreFromBackup(backupURL: backupURL, toOriginalURL: safariURL)
    /// }
    /// ```
    static func restoreFromBackup(backupURL: URL, toOriginalURL: URL) throws {
        let fileManager = FileManager.default
        
        // Verify backup file exists
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw BackupError.sourceFileNotFound(backupURL)
        }
        
        do {
            // Remove the current file if it exists
            if fileManager.fileExists(atPath: toOriginalURL.path) {
                try fileManager.removeItem(at: toOriginalURL)
            }
            
            // Copy backup to original location
            try fileManager.copyItem(at: backupURL, to: toOriginalURL)
        } catch {
            throw BackupError.restoreFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Creates a timestamp string for uniquely naming versioned backups.
    /// 
    /// - Returns: A timestamp string in format "yyyyMMdd_HHmmss"
    private static func createTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
