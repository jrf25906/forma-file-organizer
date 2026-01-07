# File Operations Service Audit

**File Reviewed**: `FileOperationsService.swift`
**Date**: 2025-11-18
**Reviewer**: Antigravity

## 🛡 Current State Analysis

The `FileOperationsService` is a solid foundation. It correctly handles:
- **Security Scoped Bookmarks**: Persisting access to folders across app launches.
- **User Permission Prompts**: Using `NSOpenPanel` to request access when needed.
- **Basic Error Mapping**: Converting `NSError` to typed `FileOperationError`.
- **Safety Checks**: Preventing users from selecting system roots (`/`, `/Users`).

## 🚩 Identified Issues & Gaps

### 1. Vague Error Messages
*   **Issue**: `FileOperationError.permissionDenied` returns "Permission denied. Please check file permissions."
*   **Impact**: Non-technical users won't know what to do. They might think the file is locked rather than the app lacking Full Disk Access.
*   **Recommendation**: Distinguish between "App lacks Full Disk Access" and "File is read-only".

### 2. "Operation Failed" Catch-All
*   **Issue**: `FileOperationError.operationFailed(String)` is used for many cases.
*   **Impact**: Hard to localize or provide specific recovery steps in the UI.
*   **Recommendation**: Add specific cases for `bookmarkResolutionFailed` and `userCancelled`.

### 3. User Cancellation Handling
*   **Issue**: If the user clicks "Cancel" in the `NSOpenPanel`, the service throws `permissionDenied`.
*   **Impact**: The UI might show an error alert ("Permission denied") even though the user intentionally cancelled the action.
*   **Recommendation**: Add `FileOperationError.userCancelled` and handle it silently in the UI (no alert).

### 4. Destination Validation
*   **Issue**: The validation `selectedPath.components(separatedBy: "/").count <= 3` is a bit brittle.
*   **Impact**: Might block valid custom setups or allow dangerous ones depending on path structure.
*   **Recommendation**: Use `FileManager` to check if the selected URL is a system directory explicitly.

## 💡 Proposed Improvements

### Enhanced Error Enum
```swift
enum FileOperationError: LocalizedError {
    case userCancelled // New: Don't show error alert
    case systemPermissionDenied // New: Link to System Settings
    case readOnlySource // New: File is locked
    // ... existing cases
}
```

### Improved Recovery Flow
In `requestDestinationAccess`:
```swift
} else {
    // User clicked Cancel
    continuation.resume(throwing: FileOperationError.userCancelled)
}
```

### UI Feedback Strategy
- **User Cancelled**: Do nothing (toast optional).
- **System Permission**: Show alert with "Open System Settings" button.
- **Read Only**: Show alert with "Unlock" option (if possible) or "Skip".
