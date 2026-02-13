# Issues & Gotchas

## [2026-02-12] M1 Development

### LSP False Positive
- **Issue**: LSP reports "'main' attribute cannot be used in a module that contains top-level code"
- **Reality**: Code compiles successfully with swiftc
- **Action**: Ignore LSP error, trust compiler output
- **Root Cause**: Unknown - possibly LSP cache or Swift 6.2.3 compatibility issue

### Xcode Command-Line Tools
- **Issue**: `xcodebuild` requires full Xcode, not just Command Line Tools
- **Impact**: Cannot run automated Xcode builds from terminal
- **Workaround**: Use `swiftc` for syntax validation, manual Xcode GUI for full builds
- **Future**: User will need to open project in Xcode GUI for testing

### Subagent Reliability
- **Issue**: visual-engineering subagent failed to create any files (twice)
- **Pattern**: Claims success but no actual file operations performed
- **Workaround**: Orchestrator created files directly
- **Recommendation**: Use different category or direct operations for Swift code
