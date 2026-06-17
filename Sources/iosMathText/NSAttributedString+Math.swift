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
                    var fontSize = (tempMutableString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont)?.pointSize ?? 12
                    var fontScale = centered ? mathFontScaleDisplay : mathFontScaleInline
                    let mathFontSize = round(fontScale > 5 ? fontScale * scale : fontSize * fontScale * scale) / scale
                    let color = tempMutableString.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor ?? .black
                    
                    if let image = imageWithLabel(string: substring, fontSize: mathFontSize, labelMode: centered ? .display : .text, color: color) {
                        let attachment = ScalingTextAttachment()
                        attachment.image = image
                        attachment.accessibilityHint = centered ? "\\[\(substring)\\]" : "\\(\(substring)\\)"
                                               
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

        func imageWithLabel(string: String, fontSize: CGFloat, labelMode: MTMathUILabelMode, color: UIColor) -> UIImage? {
            let label = Self.mtMathUILabel
            label.mode = labelMode
            label.contentScaleFactor = scale
            label.fontSize = fontSize
            label.font = MTFontManager.fontManager.font(withName: mathFontName, size: label.fontSize)
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
            
            // this getter is pretty heavy actually
            let ics = label.intrinsicContentSize
            label.frame = .init(
                origin: .init(x: 0, y: 0),
                size: .init(
                    width: ceil(ics.width*scale)/scale,
                    height: ceil(ics.height*scale)/scale
                )
            )

            //render label to image
            UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, scale)
            defer { UIGraphicsEndImageContext() }
            label.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext() ?? nil
            let baselineOffset = floor((label.displayList?.position.y ?? 0)*scale)/scale
            let nudge = 0.45/scale
            
            return image?.cgImage == nil ? nil : UIImage(cgImage: image!.cgImage!, scale: scale, orientation: .downMirrored).withBaselineOffset(fromBottom: baselineOffset + nudge).withTintColor(color, renderingMode: .alwaysTemplate)
        }
    }
}

/*
@available(iOS 16, *)
extension AttributedString {

    func parseMath(
        pixelDensity: CGFloat,
        mathFontName: String = "LatinModern",
        mathFontScaleInline: CGFloat = 1.1,
        mathFontScaleDisplay: CGFloat = 1.2
    ) -> AttributedString {
        
        let scale: CGFloat = max(ProcessInfo.processInfo.isMacCatalystApp ? 2.0 : 1.0, pixelDensity)
        var tempString = self
        let plainString = String(tempString.characters)

        // 1. Definieer de Swift Regex Literal met compile-time checks en Strongly Typed Captures.
        // Groep 1 (tag): Vangt \\[, $$, \\(, of $ op.
        // Groep 2 (formula): Vangt de wiskundige LaTeX code ertussen op (lazy matching).
//        let mathRegex = /\\\[(?<display1>.*?)\\\]|\$\$(?<display2>.*?)\$\$|\\\((?<inline1>.*?)\\\)|\$(?<inline2>.*?)\$/
        
        let mathRegex = #/(?:\\\[(.*?)\\\])|(?:\$\$(.*?)\$\$)|(?:\\\((.*?)\\\))|(?:\$(.*?)\$)/#

        // 2. Haal alle matches op via de native Swift string API
        let matches = plainString.matches(of: mathRegex) //
        if matches.isEmpty {
            return self
        }

        // 3. Verwerk de matches in omgekeerde volgorde om verschuiving van String indices te voorkomen
        for match in matches.reversed() {
            let fullRange = match.range
            
            // Bepaal de modus en formule op basis van welke capture group gevuld is
            let centered: Bool
            let rawFormula: Substring
            
            if let display1 = match.output.1 {
                centered = true
                rawFormula = display1
            } else if let display2 = match.output.2 {
                centered = true
                rawFormula = display2
            } else if let inline1 = match.output.3 {
                centered = false
                rawFormula = inline1
            } else if let inline2 = match.output.4 {
                centered = false
                rawFormula = inline2
            } else {
                continue
            }
            
            let substring = rawFormula.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Zet String.Index range om naar AttributedString.Index range
            guard let attrStart = AttributedString.Index(fullRange.lowerBound, within: tempString),
                  let attrEnd = AttributedString.Index(fullRange.upperBound, within: tempString) else { continue }
            
            let subRange = attrStart..<attrEnd
            
            // Haal styling-informatie direct type-safe op uit de AttributedString container
            let fontSize = tempString[subRange].font?.pointSize ?? 14
            let fontScale = centered ? mathFontScaleDisplay : mathFontScaleInline
            let mathFontSize = round(fontScale > 5 ? fontScale * scale : fontSize * fontScale * scale) / scale
            
            let uiColor = tempString[subRange].foregroundColor ?? .red
            
            if let image = imageWithLabel(string: substring, fontSize: mathFontSize, labelMode: centered ? .display : .text) {
                let attachment = ScalingTextAttachment()
                attachment.accessibilityHint = centered ? "\\[\(substring)\\]" : "\\(\(substring)\\)"
                attachment.image = image.withTintColor(UIColor(uiColor))
                
                // Converteer het UIKit attachment via NSAttributedString naar AttributedString
                let nsReplacement = NSAttributedString(attachment: attachment)
                var replacement = AttributedString(nsReplacement)
                
                if centered {
                    let centeredParagraphStyle = NSMutableParagraphStyle()
                    centeredParagraphStyle.alignment = .center
                    
                    var container = AttributeContainer()
                    container.paragraphStyle = centeredParagraphStyle
                    
                    var centeredAttributedString = AttributedString("\u{200B}")
                    centeredAttributedString.mergeAttributes(container)
                    centeredAttributedString.append(replacement)
                    
                    tempString.replaceSubrange(subRange, with: centeredAttributedString)
                } else {
                    tempString.replaceSubrange(subRange, with: replacement)
                }
                
                // Voeg haarsplaties toe als de attachment aan het einde van de string staat
                if fullRange.upperBound == plainString.endIndex {
                    tempString.append(AttributedString("  "))
                }
            } else {
                // Toon de platte formule bij een LaTeX parsingfout
                tempString.replaceSubrange(subRange, with: AttributedString(substring))
            }
        }
        
        tempString.append(AttributedString("​"))
        return tempString

        // Interne helper-functie (blijft ongewijzigd voor UIKit beeldrendering)
        func imageWithLabel(string: String, fontSize: CGFloat, labelMode: MTMathUILabelMode) -> UIImage? {
            let label = MTMathUILabel()
            label.mode = labelMode
            label.contentScaleFactor = scale
            label.fontSize = fontSize
            label.font = MTFontManager.fontManager.font(withName: mathFontName, size: label.fontSize)
            label.latex = string

            if label.error != nil {
                print(label.error!)
                return nil
            }
            
            let inset = round(label.fontSize * 0.025 * scale) / scale
            label.contentInsets = .init(top: inset, left: inset, bottom: inset * 2, right: inset)
            label.frame = .init(
                origin: .zero,
                size: .init(
                    width: ceil(label.intrinsicContentSize.width * scale) / scale,
                    height: ceil(label.intrinsicContentSize.height * scale) / scale
                )
            )

            UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, scale)
            defer { UIGraphicsEndImageContext() }
            label.layer.render(in: UIGraphicsGetCurrentContext()!)
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            let baselineOffset = floor((label.displayList?.position.y ?? 0) * scale) / scale
            let nudge = 0.45 / scale
            
            return image?.cgImage == nil ? nil : UIImage(cgImage: image!.cgImage!, scale: scale, orientation: .downMirrored)
                .withBaselineOffset(fromBottom: baselineOffset + nudge)
                .withRenderingMode(.alwaysTemplate)
        }
    }
}
*/
