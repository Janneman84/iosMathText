//
//  iosMathText.swift
//  iosMathText
//
//  Created by Jan de Vries on 13/06/2026.
//

import UIKit
import iosMath

/// Label that scans for LaTeX tags in the text and replaces them with LaTeX styled inline images of the containing equations.
/// Use `setMathFont()` first, then just set `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text to this view.
///
public class iosMathLabel: UILabel {
 
    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2
    
    /// Sets the math font properties. Make sure to set this *before* setting the text.
    /// - Parameters:
    ///   - name: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
    ///   - inlineScale: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
    ///   - displayScale: Same as inlineScale but for centered isolated math. Defaults to 1.2.
    public func setMathFont(name: String, inlineScale: CGFloat, displayScale: CGFloat) {
        self.mathFontName = name
        self.mathFontScaleInline = max(0, inlineScale)
        self.mathFontScaleDisplay = max(0, displayScale)
    }
    
    var ignoreAttributedTextDidSet = false
    public override var attributedText: NSAttributedString! { didSet {

        guard !ignoreAttributedTextDidSet && window?.windowScene?.screen != nil else { return }
        let scale = window?.windowScene?.screen.scale ?? 2.0
               
        if let latexedAttributedText = attributedText?.unparsingMath().parseMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay
        ) {
            self.ignoreAttributedTextDidSet = true
            self.attributedText = latexedAttributedText
            self.ignoreAttributedTextDidSet = false
        }
    }}
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        attributedText = attributedText
    }

}


/// TextView that scans for LaTeX tags in the text and replaces them with LaTeX styled inline images of the containing equations.
/// Use `setMathFont()` first, then just set `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text to this view.
///
public class iosMathTextView: UITextView {
    
    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2
    
    /// Sets the math font properties. Make sure to set this *before* setting the text.
    /// - Parameters:
    ///   - name: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
    ///   - inlineScale: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
    ///   - displayScale: Same as inlineScale but for centered isolated math. Defaults to 1.2.
    public func setMathFont(name: String, inlineScale: CGFloat, displayScale: CGFloat) {
        self.mathFontName = name
        self.mathFontScaleInline = max(0, inlineScale)
        self.mathFontScaleDisplay = max(0, displayScale)
    }

    var ignoreAttributedTextDidSet = false
    public override var attributedText: NSAttributedString! { didSet {

        guard !ignoreAttributedTextDidSet && window?.windowScene?.screen != nil else { return }
        let scale = window?.windowScene?.screen.scale ?? 2.0
               
        if let latexedAttributedText = attributedText?.unparsingMath().parseMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay
        ) {
            self.ignoreAttributedTextDidSet = true
            self.attributedText = latexedAttributedText
            self.ignoreAttributedTextDidSet = false
        }
    }}
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        attributedText = attributedText
    }
    
    #if os(iOS)
    public override func copy(_ sender: Any?) {
        //find text attachments and replace them with their respective accessibilityHint, then copy the result to clipboard
        
        var textAttachments = [(range: NSRange, string: String)]()
        let mutableAttributedSubstring = NSMutableAttributedString(attributedString: attributedText.attributedSubstring(from: selectedRange))
        
        mutableAttributedSubstring.enumerateAttribute(.attachment, in: NSRange(0..<mutableAttributedSubstring.length) , options: []) { (value, range, pointer) in
            if let textAttachment = value as? NSTextAttachment {
                textAttachments.append((range, textAttachment.accessibilityHint ?? ""))
            }
        }
        
        for attachment in textAttachments.reversed() {
            mutableAttributedSubstring.replaceCharacters(in: attachment.range, with: attachment.string)
        }

        UIPasteboard.general.string = mutableAttributedSubstring.string
    }
    #endif

}



