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
    func parseMath (
        pixelDensity: CGFloat,
        mathFontName: String = MTFontNameLatinModern,
        mathFontScaleInline: CGFloat = 1.1,
        mathFontScaleDisplay: CGFloat = 1.2,
    ) -> NSAttributedString {
       
        let scale: CGFloat = max(ProcessInfo.processInfo.isMacCatalystApp ? 2.0 : 1.0, pixelDensity)
        let tempMutableString = NSMutableAttributedString(attributedString: self)

        if let matches = NSMutableAttributedString.parseRegex?.matches(in: self.string, options: [], range: NSRange(location: 0, length: self.string.utf16.count)) {
            if matches.isEmpty {
                return self
            }

            for match in matches.reversed() {
                
                let range = match.range
                
                let firstChar = String.Index(utf16Offset: range.location + 0, in: self.string)
                let secondChar = String.Index(utf16Offset: range.location + 1, in: self.string)
                let lastChar = String.Index(utf16Offset: range.location + range.length, in: self.string)
                let tag = String(self.string[firstChar...secondChar])
                
                let centered = ["\\[", "$$"].contains(tag)
                let inset = ["\\(", "\\[", "$$"].contains(tag) ? 2 : 1
                
                let startIndex = String.Index(utf16Offset: range.location + inset, in: self.string)
                let endIndex = String.Index(utf16Offset: range.location + range.length - inset, in: self.string)
                
                if startIndex <= endIndex {
                    
                    let substring = String(self.string[firstChar..<lastChar])
                    let latex = String(self.string[startIndex..<endIndex])
                    let mode = centered ? MTMathUILabelMode.display : .text
                    
                    let attachment = MathTextAttachment()
                    attachment.update(latex: latex, substring: substring, mode: mode, updateImage: false)
                    var attrs = attributes(at: range.location, effectiveRange: nil)
                    
                    if centered {
                        let centeredParagraphStyle: NSMutableParagraphStyle = ((attrs[.paragraphStyle] as? NSObject)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
                        centeredParagraphStyle.alignment = NSTextAlignment.center
                        attrs[.paragraphStyle] = centeredParagraphStyle
                    }
                    
                    attachment.accessibilityHint = substring
                    let replacement = NSMutableAttributedString(attachment: attachment)
                    replacement.addAttributes(attrs, range: NSRange(location: 0, length: replacement.length))
                    tempMutableString.replaceCharacters(in: range, with: replacement)
                }
            }
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
