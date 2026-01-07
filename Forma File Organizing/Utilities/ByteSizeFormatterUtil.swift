import Foundation

/// Shared utilities for parsing and formatting byte sizes.
/// Centralizing this logic avoids subtle inconsistencies between
/// RuleCondition, RuleEngine, and other services.
enum ByteSizeFormatterUtil {
    enum ParseError: LocalizedError {
        case invalidFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat(let value):
                return "Invalid size value: '\(value)'. Use format like '100MB', '1.5GB', etc."
            }
        }
    }
    
    /// Parse a size string (e.g., "100MB", "1.5GB") into bytes.
    /// Supports units: B, KB, MB, GB, TB (case-insensitive).
    static func parse(_ sizeString: String) throws -> Int64 {
        let cleanString = sizeString.uppercased().trimmingCharacters(in: .whitespaces)
        
        var numberString = ""
        var unit = ""
        
        for char in cleanString {
            if char.isNumber || char == "." {
                numberString.append(char)
            } else {
                unit.append(char)
            }
        }
        
        guard let number = Double(numberString) else {
            throw ParseError.invalidFormat(sizeString)
        }
        
        let multiplier: Double
        switch unit {
        case "KB":
            multiplier = 1_024
        case "MB":
            multiplier = 1_024 * 1_024
        case "GB":
            multiplier = 1_024 * 1_024 * 1_024
        case "TB":
            multiplier = 1_024 * 1_024 * 1_024 * 1_024
        case "B", "":
            multiplier = 1
        default:
            throw ParseError.invalidFormat(sizeString)
        }
        
        return Int64(number * multiplier)
    }
    
    /// Format a byte count into a human-readable string (e.g., "10KB", "100MB").
    static func format(_ bytes: Int64) -> String {
        let kb: Double = 1_024
        let mb = kb * 1_024
        let gb = mb * 1_024
        let tb = gb * 1_024
        
        let bytesDouble = Double(bytes)
        
        if bytesDouble >= tb {
            return String(format: "%.1fTB", bytesDouble / tb)
        } else if bytesDouble >= gb {
            return String(format: "%.1fGB", bytesDouble / gb)
        } else if bytesDouble >= mb {
            return String(format: "%.0fMB", bytesDouble / mb)
        } else if bytesDouble >= kb {
            return String(format: "%.0fKB", bytesDouble / kb)
        } else {
            return "\(bytes)B"
        }
    }
}
