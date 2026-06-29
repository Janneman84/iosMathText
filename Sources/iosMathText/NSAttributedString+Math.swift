//
//  NSAttributedString+Math.swift
//  iosMathText
//
//  Created by Jan de Vries on 13/06/2026.
//

import UIKit
import iosMath

extension NSAttributedString {
    
    private static let mtMathUILabel = MTMathUILabel()

    /**
     Checks for LaTeX math tags in the text and replaces them with LaTeX styled inline images of the containing equations. The equation font size will be relative to its surrounding text.

     - Parameter pixelDensity: This is typically obtained with `traitCollection.displayScale`.
     - Parameter mathFontName: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
     - Parameter mathFontScaleInline: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
     - Parameter mathFontScaleDisplay: Same as inlineScale but for centered isolated math. Defaults to 1.2.
     - Returns: Attributed String
     */
    func parseMath(
        pixelDensity: CGFloat,
        mathFontName: String = MTFontNameLatinModern,
        mathFontScaleInline: CGFloat = 1.1,
        mathFontScaleDisplay: CGFloat = 1.2
    ) -> NSAttributedString {
       
        let totalLength = self.length
        guard totalLength > 0,
              let matches = NSMutableAttributedString.parseRegex?.matches(in: self.string, options: [], range: NSRange(location: 0, length: totalLength)),
              !matches.isEmpty else {
            return self
        }

        let scale: CGFloat = max(ProcessInfo.processInfo.isMacCatalystApp ? 2.0 : 1.0, pixelDensity)
        let tempMutableString = NSMutableAttributedString(attributedString: self)
        
        // Cache the Swift String and its UTF16 view for fast access outside the loop
        let swiftString = self.string

        for match in matches.reversed() {
            let range = match.range
            guard range.location != NSNotFound else { continue }
            
            // Convert NSRange to native Swift Range<String.Index> in one optimized step
            guard let swiftRange = Range(range, in: swiftString) else { continue }
            let matchedSubstring = swiftString[swiftRange]
            
            // Get the first two characters to check the tag via prefix
            let tag = matchedSubstring.prefix(2)
            let isCentered = tag == "\\[" || tag == "$$"
            let isInsetTwo = isCentered || tag == "\\("
            let inset = isInsetTwo ? 2 : 1

            // Check for invisible text attachment (if the next character is a newline and NOT the last character of the text)
            var addNarrowSpace = false
            let nextIndexInUtf16 = range.location + range.length
            if nextIndexInUtf16 < totalLength {
                let nextCharIndex = String.Index(utf16Offset: nextIndexInUtf16, in: swiftString)
                if nextCharIndex < swiftString.endIndex && swiftString[nextCharIndex] == "\n" {
                    // The newline is only valid if it is not the very last character of the string
                    let afterNewlineIndex = swiftString.index(after: nextCharIndex)
                    addNarrowSpace = afterNewlineIndex < swiftString.endIndex
                }
            }
            
            // Extract the LaTeX code safely using Substring methods without manual index calculations
            guard matchedSubstring.count >= (inset * 2) else { continue }
            let latexSubstring = matchedSubstring.dropFirst(inset).dropLast(inset)
            
            let substringStr = String(matchedSubstring)
            let latexStr = String(latexSubstring)
            let mode: MTMathUILabelMode = isCentered ? .display : .text
            
            let attachment = MathTextAttachment()
            if #available(iOS 15.0, *) {
                attachment.allowsTextAttachmentView = false
            }
            attachment.update(latex: latexStr, substring: substringStr, mode: mode, updateImage: false)
            attachment.accessibilityHint = substringStr
            
            var attrs = self.attributes(at: range.location, effectiveRange: nil)
            
            if isCentered {
                let centeredParagraphStyle: NSMutableParagraphStyle
                if let existingStyle = attrs[.paragraphStyle] as? NSParagraphStyle {
                    centeredParagraphStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    centeredParagraphStyle = NSMutableParagraphStyle()
                }
                centeredParagraphStyle.alignment = .center
                attrs[.paragraphStyle] = centeredParagraphStyle
            }
            
            let replacement = NSMutableAttributedString(attachment: attachment)
            if addNarrowSpace {
                replacement.append(NSAttributedString(string: " ")) // narrow no-break space
            }
            
            replacement.addAttributes(attrs, range: NSRange(location: 0, length: replacement.length))
            tempMutableString.replaceCharacters(in: range, with: replacement)
        }
        return tempMutableString
    }
    
    func updateMath(
        pixelDensity scale: CGFloat,
        mathFontName: String = MTFontNameLatinModern,
        mathFontScaleInline: CGFloat = 1.1,
        mathFontScaleDisplay: CGFloat = 1.2,
    ) -> NSAttributedString? {
        var updated = false
        var attributedString: NSMutableAttributedString?
        enumerateAttribute(.attachment, in: NSRange(location:0, length:length) , options: []) { (value, range, pointer) in
            if let mathTextAttachment = value as? MathTextAttachment {
                let color = attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor ?? .black
                var fontScale = mathTextAttachment.mode == .display ? mathFontScaleDisplay : mathFontScaleInline
                var fontSize = (attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)?.pointSize ?? 12
                let mathFontSize = round(fontScale > 5 ? fontScale * scale : fontSize * fontScale * scale) / scale
                if mathTextAttachment.update(font: mathFontName, fontSize: mathFontSize, color: color, scale: scale) {
                    updated = true
                }
                //in case of Latex parsing error just show as regular text:
                if mathTextAttachment.image == nil {
                    var attrs = attributes(at: range.location, effectiveRange: nil)
                    var replacement = NSAttributedString(string: mathTextAttachment.substring, attributes: attrs)
                    attributedString = NSMutableAttributedString(attributedString: self)
                    attributedString?.replaceCharacters(in: range, with: replacement)
                }
            }
        }
        return updated ? (attributedString ?? self) : nil
    }
    
    /// Makes sure all .display equations are centered. Setting textAlignment can mess this up.
    func centerDisplayMath() -> NSAttributedString? {
        var mutable: NSMutableAttributedString?
        
        enumerateAttribute(.attachment, in: NSRange(0..<length) , options: []) { (value, range, pointer) in
            if (value as? MathTextAttachment)?.mode == .display {
                var attrs = attributes(at: range.location, effectiveRange: nil)
                let centeredParagraphStyle: NSMutableParagraphStyle = ((attrs[.paragraphStyle] as? NSObject)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                if centeredParagraphStyle.alignment != .center {
                    centeredParagraphStyle.alignment = .center
                    attrs[.paragraphStyle] = centeredParagraphStyle
                    if mutable == nil {
                        mutable = self.mutableCopy() as! NSMutableAttributedString
                    }
                    mutable!.setAttributes(attrs, range: range)
                }
            }
        }
        return mutable
    }
}
