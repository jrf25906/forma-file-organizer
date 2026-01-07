# RuleCondition Type Safety Improvements

## Overview

`RuleCondition` has been refactored from a loose struct with `String` values to a type-safe enum with associated values. This provides compile-time type safety while maintaining full backward compatibility and SwiftData persistence.

## The Problem

**Before:** RuleCondition used a loose String for all values:

```swift
struct RuleCondition: Codable, Equatable {
    var type: ConditionType
    var value: String  // TOO LOOSE - can be anything
}
```

This caused several issues:
- Invalid values only failed at runtime
- No type safety for numeric values (days, bytes)
- Easy to pass wrong data types
- No compile-time validation

## The Solution

**After:** RuleCondition is now a type-safe enum:

```swift
enum RuleCondition: Codable, Equatable, Hashable {
    case fileExtension(String)
    case nameContains(String)
    case nameStartsWith(String)
    case nameEndsWith(String)
    case dateOlderThan(days: Int, extension: String?)
    case sizeLargerThan(bytes: Int64)
    case dateModifiedOlderThan(days: Int)
    case dateAccessedOlderThan(days: Int)
    case fileKind(String)
}
```

## Benefits

### 1. Compile-Time Type Safety

```swift
// OLD: No type checking, runtime failure
let condition = RuleCondition(type: .dateOlderThan, value: "abc")  // Crashes at runtime

// NEW: Type-safe construction with validation
let condition = try RuleCondition(type: .dateOlderThan, value: "7")  // Validated at construction
```

### 2. Type-Safe Accessors

```swift
let condition = try RuleCondition(type: .dateOlderThan, value: "7")

// Type-safe accessors
condition.daysValue    // Int? = 7
condition.sizeValue    // Int64? = nil
condition.textValue    // String? = nil

// Direct pattern matching
switch condition {
case .dateOlderThan(let days, let ext):
    print("Files older than \(days) days")
case .sizeLargerThan(let bytes):
    print("Files larger than \(bytes) bytes")
default:
    break
}
```

### 3. Validation at Construction

```swift
// Invalid input is caught immediately
do {
    let condition = try RuleCondition(type: .dateOlderThan, value: "abc")
} catch RuleCondition.ValidationError.invalidDays(let value) {
    print("Invalid days value: \(value)")
}
```

### 4. Full Backward Compatibility

Legacy code continues to work via compatibility properties:

```swift
let condition = try RuleCondition(type: .fileExtension, value: "pdf")

// Legacy properties still work
condition.type   // .fileExtension
condition.value  // "pdf"
```

## Implementation Details

### Custom Codable Implementation

The enum implements custom `Codable` conformance to ensure SwiftData persistence:

```swift
private enum CodingKeys: String, CodingKey {
    case type
    case stringValue
    case intValue
    case int64Value
    case extensionValue
}

func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .fileExtension(let value):
        try container.encode(ConditionTypeCode.fileExtension, forKey: .type)
        try container.encode(value, forKey: .stringValue)

    case .dateOlderThan(let days, let ext):
        try container.encode(ConditionTypeCode.dateOlderThan, forKey: .type)
        try container.encode(days, forKey: .intValue)
        try container.encodeIfPresent(ext, forKey: .extensionValue)

    // ... other cases
    }
}
```

### Failable Initializer

For backward compatibility with views, a failable initializer validates input:

```swift
init(type: Rule.ConditionType, value: String) throws {
    switch type {
    case .dateOlderThan:
        let components = value.split(separator: ":")
        if components.count == 2 {
            let ext = String(components[0])
            guard let days = Int(components[1]), days > 0 else {
                throw ValidationError.invalidDays(value: String(components[1]))
            }
            self = .dateOlderThan(days: days, extension: ext)
        } else {
            guard let days = Int(value), days > 0 else {
                throw ValidationError.invalidDays(value: value)
            }
            self = .dateOlderThan(days: days, extension: nil)
        }

    case .sizeLargerThan:
        let bytes = try Self.parseSizeString(value)
        guard bytes > 0 else {
            throw ValidationError.invalidSize(value: value)
        }
        self = .sizeLargerThan(bytes: bytes)

    // ... other cases
    }
}
```

### Size Parsing

Size strings are parsed into bytes at construction:

```swift
try RuleCondition(type: .sizeLargerThan, value: "100MB")
// Stores: .sizeLargerThan(bytes: 104857600)
```

Supported formats:
- `"100MB"` → 104,857,600 bytes
- `"1.5GB"` → 1,610,612,736 bytes
- `"500KB"` → 512,000 bytes

## Migration Path

### Existing Code

No changes required! The legacy `type` and `value` properties are still available:

```swift
// This still works exactly as before
let condition = try RuleCondition(type: .fileExtension, value: "pdf")
print(condition.type)   // .fileExtension
print(condition.value)  // "pdf"
```

### New Code

Use type-safe construction and accessors:

```swift
// Direct enum construction
let condition = RuleCondition.dateOlderThan(days: 7, extension: "dmg")

// Type-safe accessors
if let days = condition.daysValue {
    print("Checking files older than \(days) days")
}

// Pattern matching
switch condition {
case .dateOlderThan(let days, let ext):
    // Type-safe pattern matching
    print("Days: \(days), Extension: \(ext ?? "all")")
default:
    break
}
```

## RuleEngine Integration

The RuleEngine now uses type-safe pattern matching:

```swift
private func matchesCondition<F: Fileable>(file: F, condition: RuleCondition) -> Bool {
    switch condition {
    case .fileExtension(let ext):
        return file.fileExtension.lowercased() == ext.lowercased()

    case .dateOlderThan(let days, let extensionFilter):
        guard days > 0 else { return false }

        // Check extension if specified
        if let ext = extensionFilter, !ext.isEmpty {
            let cleanExt = ext.replacingOccurrences(of: ".", with: "")
            if file.fileExtension.lowercased() != cleanExt.lowercased() {
                return false
            }
        }

        // Check date
        let calendar = Calendar.current
        guard let dateThreshold = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return false
        }

        return file.creationDate < dateThreshold

    case .sizeLargerThan(let bytes):
        return file.sizeInBytes > bytes

    // ... other cases
    }
}
```

## View Layer Integration

Views now handle validation errors gracefully:

```swift
// InlineRuleBuilderView.swift
private func addCondition() {
    guard !conditionValue.isEmpty else { return }

    do {
        let newCondition = try RuleCondition(
            type: conditionType,
            value: conditionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        conditions.append(newCondition)
        conditionValue = ""
    } catch {
        validationError = error.localizedDescription
        return
    }
}
```

## Testing

Comprehensive tests verify type safety:

```swift
func testInvalidDaysValue() {
    XCTAssertThrowsError(try RuleCondition(type: .dateOlderThan, value: "abc")) { error in
        guard case RuleCondition.ValidationError.invalidDays = error else {
            XCTFail("Expected invalidDays error")
            return
        }
    }
}

func testSizeLargerThanCondition() throws {
    let condition = try RuleCondition(type: .sizeLargerThan, value: "100MB")
    XCTAssertEqual(condition.sizeValue, 100 * 1024 * 1024)
}

func testDirectConstruction() {
    let condition = RuleCondition.dateOlderThan(days: 7, extension: "dmg")
    XCTAssertEqual(condition.daysValue, 7)
    XCTAssertEqual(condition.extensionFilter, "dmg")
}
```

## Future Improvements

### 1. SwiftUI Bindings

Create type-safe bindings for SwiftUI:

```swift
extension Binding where Value == RuleCondition {
    var daysBinding: Binding<Int>? {
        guard case .dateOlderThan = wrappedValue else { return nil }

        return Binding<Int>(
            get: { self.wrappedValue.daysValue ?? 0 },
            set: { newDays in
                if case .dateOlderThan(_, let ext) = self.wrappedValue {
                    self.wrappedValue = .dateOlderThan(days: newDays, extension: ext)
                }
            }
        )
    }
}
```

### 2. Builder Pattern

Add a fluent builder for complex conditions:

```swift
RuleCondition.dateOlderThan()
    .days(7)
    .extension("dmg")
    .build()
```

### 3. Validation Rules

Add cross-condition validation:

```swift
extension Array where Element == RuleCondition {
    func validate() throws {
        // Check for conflicting conditions
        // Ensure logical combinations make sense
    }
}
```

## Summary

The refactored `RuleCondition` provides:

- **Type Safety**: Compile-time guarantees for condition values
- **Validation**: Early error detection at construction
- **Clarity**: Clear separation of different value types
- **Compatibility**: Full backward compatibility with existing code
- **Maintainability**: Easier to extend with new condition types
- **Testing**: Comprehensive test coverage for all cases

All while maintaining SwiftData persistence and existing API compatibility.
