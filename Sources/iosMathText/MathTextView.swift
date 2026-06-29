//
//  MathTextView.swift
//  iosMathTextView
//
//  Created by Jan de Vries on 13/06/2026.
//

import UIKit
import iosMath

@available(*, deprecated, message: "renamed to 'MathTextView'")
open class iosMathTextView: MathTextView {}

/// TextView that scans for LaTeX tags in the text and replaces them with LaTeX styled inline images of the containing equations.
/// Set math font with `setMathFont()` and text font/size/color/alignment **first**, then just set `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text or attributedText to this view.
///
open class MathTextView: UITextView {
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleUpdateMath), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleUpdateMath), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2
    
    /// Sets the math font properties.
    /// - Parameters:
    ///   - name: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
    ///   - inlineScale: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
    ///   - displayScale: Same as inlineScale but for centered isolated math. Defaults to 1.2.
    open func setMathFont(name: String, inlineScale: CGFloat, displayScale: CGFloat) {
        mathFontName = name
        mathFontScaleInline = max(0, inlineScale)
        mathFontScaleDisplay = max(0, displayScale)
        scheduleUpdateMath()
    }

    var ignoreAttributedTextDidSet = false

    // When text only contains a centered equation textAlignment gets changed to .centered.
    // Use tempAlignment to set the textAlignment back to its original alignment.
    var tempAlignment: NSTextAlignment? = .natural
    var ignoreTextAlignmentSet = false
    
    open override var text: String! {
        willSet {
            updateScheduled = false
            if let tempAlignment {
                ignoreTextAlignmentSet = true
                textAlignment = tempAlignment
                ignoreTextAlignmentSet = false
                self.tempAlignment = nil
            }
        }
    }
    
    open override var attributedText: NSAttributedString! {
        willSet {
            if ignoreAttributedTextDidSet && tempAlignment == nil {
                tempAlignment = textAlignment
            }
        }
        didSet {
            guard !ignoreAttributedTextDidSet else { return }
            updateScheduled = false
            let scale = traitCollection.displayScale
            
            if let latexedAttributedText = attributedText?.unparsingMath().parseMath(
                pixelDensity: scale,
                mathFontName: mathFontName,
                mathFontScaleInline: mathFontScaleInline,
                mathFontScaleDisplay: mathFontScaleDisplay
            ) {
                ignoreAttributedTextDidSet = true
                attributedText = latexedAttributedText
                scheduleUpdateMath()
                ignoreAttributedTextDidSet = false
            }
        }}
    
    open override var textAlignment: NSTextAlignment {
        willSet {
            if !ignoreTextAlignmentSet && tempAlignment != nil && !ignoreAttributedTextDidSet {
                tempAlignment = newValue
            }
        }
        didSet {
            if !ignoreTextAlignmentSet, let centeredDisplayMath = attributedText.centerDisplayMath() {
                ignoreAttributedTextDidSet = true
                attributedText = centeredDisplayMath
                ignoreAttributedTextDidSet = false
            }
         }
    }
    
    open override var font: UIFont! {
        didSet {
            if font?.pointSize != oldValue?.pointSize {
                scheduleUpdateMath()
            }
        }
    }
    
    open override var textColor: UIColor! {
        didSet {
            if textColor != oldValue {
                scheduleUpdateMath()
            }
        }
    }
    
    open override func setNeedsLayout() {
        if !layingoutSubviews {
            super.setNeedsLayout()
        }
    }
    
    open override func layoutIfNeeded() {
        updateMath()
        super.layoutIfNeeded()
    }
    
    var layingoutSubviews = false
    open override func layoutSubviews() {
        layingoutSubviews = true
        updateMath()
        super.layoutSubviews()
        layingoutSubviews = false
    }
    
    func updateMath() {
        guard updateScheduled else { return }
        updateScheduled = false
        guard !ignoreAttributedTextDidSet else { return }
        let scale = traitCollection.displayScale
        if let attributedString = attributedText.updateMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay
        ) {
            ignoreAttributedTextDidSet = true
            self.attributedText = nil
            self.attributedText = attributedString
            ignoreAttributedTextDidSet = false
            layoutIfNeeded()
        }
    }
    
    var updateScheduled = false
    @objc func scheduleUpdateMath() {
        guard !updateScheduled else { return }
        updateScheduled = true
        setNeedsLayout() //TODO necessary?
    }
    
    
    #if os(iOS)
    open override func copy(_ sender: Any?) {
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

        UIPasteboard.general.string = mutableAttributedSubstring.string.replacingOccurrences(of: " ", with: "") // remove narrow no-break space used to fix a glitch
    }
    #endif

}



