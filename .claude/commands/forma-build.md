Build, test, and validate the Forma macOS app.

## Arguments
- `$ARGUMENTS` - Optional: `test`, `clean`, `full`, or empty for default build

## Workflow

### 1. Parse Mode
Determine build mode from arguments:
- (empty) → Build only (fast feedback)
- `test` → Build + run tests
- `clean` → Clean DerivedData + build
- `full` → Clean + build + test

### 2. Pre-Build Check
- If mode includes `clean`: Remove stale DerivedData directories
  - Pattern: `DerivedData*` folders in project root (there are many legacy ones)
  - Use: `rm -rf DerivedData*` in project root
- Check for uncommitted changes that might affect build (informational only)

### 3. Build
Run the Debug build:
```bash
xcodebuild -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -configuration Debug \
  build 2>&1
```

Report:
- Build success/failure
- Warning count (Swift warnings are important to track)
- Error details if failed

### 4. Test (if mode includes test)
Run unit tests on macOS:
```bash
xcodebuild test \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -destination 'platform=macOS' 2>&1
```

Report:
- Test pass/fail summary
- Failed test names with file:line references
- Test duration

### 5. Summary
Provide a clean summary:
- Build status (success/failed)
- Warning count
- Test status (if run): X passed, Y failed
- Total time

## Project Context
- Project: `Forma File Organizing.xcodeproj`
- Scheme: `Forma File Organizing`
- Platform: macOS (native app, not iOS)
- Swift version: 5.9
- Test helpers: Use `TemporaryDirectory.swift` for filesystem tests

## Known Issues to Watch
- Multiple `DerivedData*` folders exist from previous build experiments
- Security-scoped bookmark tests may require specific entitlements
- MainActor warnings in test code should be addressed
