//
//  String+Math.swift
//  iosMathText
//
//  Created by Jan de Vries on 10/06/2026.
//
import Foundation

extension String {
    // Pre-compile the regex once to save CPU cycles.
    // Thread-safe and compatible with iOS 13+.
    private static let mathRegex: NSRegularExpression? = {
        let pattern = "((?<!\\\\)\\$\\$.*?(?<!\\\\)\\$\\$)|((?<!\\\\)\\$.*?(?<!\\\\)\\$)|(\\\\\\[.*?\\\\\\])|(\\\\\\(.*?\\\\\\))"
        return try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    /// Searches for LaTeX math strings ($$, $, \[, \() and replaces them in-place with: ✽[Base64]❄︎
    /// Fully optimized and backward-compatible with iOS 13.
    public func preparseMath() -> String {
        guard let regex = String.mathRegex else { return self }
        
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        let matches = regex.matches(in: self, options: [], range: range)
        
        // If no math blocks are found, exit early to save memory and CPU
        guard !matches.isEmpty else { return self }
        
        // Build the new string using a linear buffer to avoid O(N²) memory shifting
        var result = String()
        
        // iOS 13 safe capacity reservation using standard string count
        result.reserveCapacity(self.count + (matches.count * 30))
        
        var currentIndex = self.startIndex
        
        for match in matches {
            guard let matchRange = Range(match.range(at: 0), in: self) else { continue }
            
            // 1. Append plain text leading up to the math block
            result.append(contentsOf: self[currentIndex..<matchRange.lowerBound])
            
            // 2. Extract and encode the math block
            let fullMathString = String(self[matchRange])
            if let formulaData = fullMathString.data(using: .utf8) {
                let base64Encoded = formulaData.base64EncodedString()
                
                // 3. Append the wrapped Base64 string to our buffer
                result.append("✽")
                result.append(base64Encoded)
                result.append("❄︎")
            } else {
                // Fallback if UTF-8 conversion fails
                result.append(fullMathString)
            }
            
            currentIndex = matchRange.upperBound
        }
        
        // 4. Append remaining plain text after the last match
        result.append(contentsOf: self[currentIndex..<self.endIndex])
        
        // 5. Overwrite the original string in-place exactly once
        return result
    }

    // Pre-compile the regex once to save CPU cycles.
    // Matches everything between ✽ and ❄︎ safely.
    private static let unparseRegex: NSRegularExpression? = {
        let pattern = "\\✽(.*?)\\❄︎"
        return try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()

    /// Searches for ✽[Base64]❄︎ blocks and replaces them in-place with the decoded LaTeX string.
    /// Fully optimized and backward-compatible with iOS 13.
    public func unparseMath() -> String {
        guard let regex = String.unparseRegex else { return self }
        
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        let matches = regex.matches(in: self, options: [], range: range)
        
        // If no encoded blocks are found, exit early to save memory and CPU
        guard !matches.isEmpty else { return self }
        
        // Build the new string using a linear buffer to avoid O(N²) memory shifting
        var result = String()
        result.reserveCapacity(self.count)
        
        var currentIndex = self.startIndex
        
        for match in matches {
            // Group 0 is the full match including emojis: ✽[Base64]❄︎
            // Group 1 is just the Base64 string inside
            guard let fullMatchRange = Range(match.range(at: 0), in: self),
                  let base64Range = Range(match.range(at: 1), in: self) else { continue }
            
            // 1. Append plain text leading up to the encoded block
            result.append(contentsOf: self[currentIndex..<fullMatchRange.lowerBound])
            
            // 2. Extract and decode the Base64 string
            let base64String = String(self[base64Range])
            if let decodedData = Data(base64Encoded: base64String),
               let decodedMath = String(data: decodedData, encoding: .utf8) {
                // 3. Append the original LaTeX string to our buffer
                result.append(decodedMath)
            } else {
                // Fallback: if decoding fails, keep the original encoded block untouched
                result.append(contentsOf: self[fullMatchRange])
            }
            
            currentIndex = fullMatchRange.upperBound
        }
        
        // 4. Append remaining plain text after the last match
        result.append(contentsOf: self[currentIndex..<self.endIndex])
        
        return result
    }
}

// MARK: - Extension for In-Place Mutation (NSMutableAttributedString)
extension NSMutableAttributedString {
    
    // Pre-compiled regex patterns for performance and iOS 13 compatibility
    static let parseRegex: NSRegularExpression? = {
        let pattern = "((?<!\\\\)\\$\\$.*?(?<!\\\\)\\$\\$)|((?<!\\\\)\\$.*?(?<!\\\\)\\$)|(\\\\\\[.*?\\\\\\])|(\\\\\\(.*?\\\\\\))"
        return try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()
    
    static let unparseRegex: NSRegularExpression? = {
        let pattern = "\\✽(.*?)\\❄︎"
        return try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
    }()
    
    /// Searches for LaTeX math strings ($$, $, \[, \() and replaces them in-place with: ✽[Base64]❄︎
    /// Preserves all other text attributes.
    func xparseMath() {
        guard let regex = NSMutableAttributedString.parseRegex else { return }
        
        let fullRange = NSRange(location: 0, length: self.length)
        let matches = regex.matches(in: self.string, options: [], range: fullRange)
        
        // Process from back to front to prevent index shifting during replacement
        for match in matches.reversed() {
            let matchRange = match.range(at: 0)
            
            // Extract the plain math string from the attributed string
            let fullMathString = (self.string as NSString).substring(with: matchRange)
            
            if let formulaData = fullMathString.data(using: .utf8) {
                let base64Encoded = formulaData.base64EncodedString()
                let formattedResult = "✽\(base64Encoded)❄︎"
                
                // Replace the text while preserving attributes from the original first character
                self.replaceCharacters(in: matchRange, with: formattedResult)
            }
        }
    }
    
    /// Searches for ✽[Base64]❄︎ blocks and replaces them in-place with the decoded LaTeX string.
    /// Preserves all other text attributes.
    func xunparseMath() {
        guard let regex = NSMutableAttributedString.unparseRegex else { return }
        
        let fullRange = NSRange(location: 0, length: self.length)
        let matches = regex.matches(in: self.string, options: [], range: fullRange)
        
        // Process from back to front to prevent index shifting during replacement
        for match in matches.reversed() {
            let fullMatchRange = match.range(at: 0)
            let base64Range = match.range(at: 1)
            
            let base64String = (self.string as NSString).substring(with: base64Range)
            
            if let decodedData = Data(base64Encoded: base64String),
               let decodedMath = String(data: decodedData, encoding: .utf8) {
                
                // Replace the encoded block with the original LaTeX string
                self.replaceCharacters(in: fullMatchRange, with: decodedMath)
            }
        }
    }
}

// MARK: - Extension for Non-Mutating Strings (NSAttributedString)
extension NSAttributedString {
    
    /// Returns a new attributed string with LaTeX math strings replaced by ✽[Base64]❄︎
    public func preparseMath() -> NSAttributedString {
        let mutableCopy = NSMutableAttributedString(attributedString: self)
        mutableCopy.xparseMath()
        return NSAttributedString(attributedString: mutableCopy)
    }
    
    /// Returns a new attributed string with ✽[Base64]❄︎ blocks decoded back to original LaTeX.
    public func unparsingMath() -> NSAttributedString {
        let mutableCopy = NSMutableAttributedString(attributedString: self)
        mutableCopy.xunparseMath()
        return NSAttributedString(attributedString: mutableCopy)
    }
}

