//
//  NSAttributedString+Math.swift
//  iosMathText
//
//  Created by Jan de Vries on 13/06/2026.
//

import UIKit
import iosMath

extension NSAttributedString {
    
    /**
     Checks for LaTeX math tags in the text and replaces them with LaTeX styled inline images of the containing equations. The equation font size will be relative to its surrounding text.

     - Parameter pixelDensity: This is typically obtained with `view.window?.windowScene?.screen.scale`.
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

        // round spacing to the nearest pixel
        let fullRange = NSRange(location: 0, length: tempMutableString.length)
        var prevlineSpacing: CGFloat = 0
        var prevParagraphSpacing: CGFloat = 0
        var prevParagraphSpacingBefore: CGFloat = 0
        
        
        tempMutableString.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { (value, range, stop) in
            if let paragraphStyle = value as? NSMutableParagraphStyle {

                paragraphStyle.lineHeightMultiple = 0
                                
                if paragraphStyle.lineSpacing != prevlineSpacing && paragraphStyle.lineSpacing != 0 {
                    prevlineSpacing = round(paragraphStyle.lineSpacing * scale)/scale
                    paragraphStyle.lineSpacing = prevlineSpacing
                }

                if paragraphStyle.paragraphSpacing != prevParagraphSpacing && paragraphStyle.paragraphSpacing != 0 {
                    prevParagraphSpacing = round(paragraphStyle.paragraphSpacing * scale)/scale
                    paragraphStyle.paragraphSpacing = prevParagraphSpacing
                }
                
                if paragraphStyle.paragraphSpacingBefore != prevParagraphSpacingBefore && paragraphStyle.paragraphSpacingBefore != 0 {
                    prevParagraphSpacingBefore = round(paragraphStyle.paragraphSpacingBefore * scale)/scale
                    paragraphStyle.paragraphSpacingBefore = prevParagraphSpacingBefore
                }
            }
        }
        

        if let matches = NSMutableAttributedString.parseRegex?.matches(in: self.string, options: [], range: NSRange(location: 0, length: self.string.utf16.count)) {
            if matches.isEmpty {
                return self
            }

            for match in matches.reversed() {
                
                let range = match.range
                
                let firstChar = String.Index(utf16Offset: range.location + 0, in: self.string)
                let secondChar = String.Index(utf16Offset: range.location + 1, in: self.string)
                let tag = String(self.string[firstChar...secondChar])
                
                let centered = ["\\[", "$$"].contains(tag)
                let inset = ["\\(", "\\[", "$$"].contains(tag) ? 2 : 1
                
                let startIndex = String.Index(utf16Offset: range.location + inset, in: self.string)
                let endIndex = String.Index(utf16Offset: range.location + range.length - inset, in: self.string)
                
                if startIndex <= endIndex {

                    let substring = String(self.string[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                                       
                    var fontSize = (tempMutableString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)?.pointSize ?? 14
                    var fontScale = centered ? mathFontScaleDisplay : mathFontScaleInline
                    let mathFontSize = round(fontScale > 5 ? fontScale * scale : fontSize * fontScale * scale) / scale
                    let color = tempMutableString.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor ?? .red
                    
                    if let image = imageWithLabel(string: substring, fontSize: mathFontSize, labelMode: centered ? .display : .text) {
                        let attachment = ScalingTextAttachment()
                        attachment.accessibilityHint = centered ? "\\[\(substring)\\]" : "\\(\(substring)\\)"
                        attachment.image = image.withTintColor(color)
                                               
                        let replacement = NSAttributedString(attachment: attachment)

                        if centered {
                            let centeredParagraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
                            centeredParagraphStyle.alignment = NSTextAlignment.center
                            let centeredAttributedString = NSMutableAttributedString(string: "\u{200B}", attributes: [.paragraphStyle : centeredParagraphStyle])
                            centeredAttributedString.append(replacement)
                            tempMutableString.replaceCharacters(in: range, with: centeredAttributedString)
                        } else {
                            tempMutableString.replaceCharacters(in: range, with: replacement)
                        }

                        //if attachment is at the very end of the text append some string to prevent formatting issues
                        if range.upperBound == string.count {
                            tempMutableString.append(NSAttributedString(string: "  "))
                        }
                    } else {
                        //in case of Latex parsing error just show as regular text:
                        tempMutableString.replaceCharacters(in: range, with: NSAttributedString(string: substring))
                    }
                }
            }
        }
        tempMutableString.append(NSAttributedString(string: "​"))
        return tempMutableString

        func imageWithLabel(string: String, fontSize: CGFloat, labelMode: MTMathUILabelMode) -> UIImage? {
            let label = MTMathUILabel()
            label.mode = labelMode
            label.contentScaleFactor = scale
            label.fontSize = fontSize
            label.font = MTFontManager.fontManager.font(withName: MTFontNameXITS, size: label.fontSize)
//            label.backgroundColor = .systemTeal.withAlphaComponent(0.75)
            label.latex = string

            if label.error != nil {
                print(label.error!)
                return nil
            }
            
            let inset = round(label.fontSize * 0.025 * scale)/scale
            //you need at least a little bit of insets to prevent clipping
            label.contentInsets = .init(
                top:    inset,
                left:   inset,
                bottom: inset*2,
                right:  inset,
            )
            label.frame = .init(
                origin: .init(x: 0, y: 0),
                size: .init(
                    width: ceil(label.intrinsicContentSize.width*scale)/scale,
                    height: ceil(label.intrinsicContentSize.height*scale)/scale
                )
            )

            //render label to image
            UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, scale)
            defer { UIGraphicsEndImageContext() }
            label.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext() ?? nil
            let baselineOffset = floor((label.displayList?.position.y ?? 0)*scale)/scale
            let nudge = 0.45/scale
            
            return image?.cgImage == nil ? nil : UIImage(cgImage: image!.cgImage!, scale: scale, orientation: .downMirrored).withBaselineOffset(fromBottom: baselineOffset + nudge).withRenderingMode(.alwaysTemplate)
        }
    }
}
