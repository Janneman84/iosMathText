//
//  MathLabel.swift
//  iosMathText
//
//  Created by Jan de Vries on 18/06/2026.
//

import UIKit
import iosMath

@available(*, deprecated, message: "renamed to 'MathLabel'")
open class iosMathLabel: MathLabel {}

/// Label that scans for LaTeX tags in the text and replaces them with LaTeX styled inline images of the containing equations.
/// Set math font with `mathFont` or `setMathFont()`, then set either `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` (attributed) string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished set the resulting attributedText to this view.
///
open class MathLabel: UILabel {
    
    // MARK: - Initializer overrides
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    func initialize() {
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleUpdateMath), name: UIContentSizeCategory.didChangeNotification, object: nil)
        desiredTextAlignment = textAlignment
        attributedText = attributedText
    }
    
    
    // MARK: - Public Interface
    
    /// Instance MathLabel with the math font properties.
    /// - Parameters:
    ///   - mathFontName: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
    ///   - inlineScale: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
    ///   - displayScale: Same as inlineScale but for centered isolated math. Defaults to 1.2.
    ///   - ignore$: Set to true to not look for LaTeX between $ .. $ and $$ ... $$.
    @objc public convenience init(mathFontName: String, inlineScale: CGFloat, displayScale: CGFloat, ignore$: Bool = false) {
        self.init(frame: .zero)
        self.ignore$ = ignore$
        self.mathFont = (name: mathFontName, inlineScale: inlineScale, displayScale: displayScale)
    }
    
    /// Sets the math font properties.
    /// - Parameters:
    ///   - name: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
    ///   - inlineScale: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
    ///   - displayScale: Same as inlineScale but for centered isolated math. Defaults to 1.2.
    @objc open func setMathFont(name: String, inlineScale: CGFloat, displayScale: CGFloat) {
        mathFontName = name
        mathFontScaleInline = max(0, inlineScale)
        mathFontScaleDisplay = max(0, displayScale)
        scheduleUpdateMath()
    }

    /// Sets the math font properties with a tuple, alternative to setMathFont().
    /// - Parameters:
    ///   - name: Add `import iosMath` and you should be able to access consts that start with `MTFontName`.  Defaults to MTFontNameLatinModern.
    ///   - inlineScale: Sets the size factor of the math font relative to the text. Use a value over 5 for absolute size. Defaults to 1.1.
    ///   - displayScale: Same as inlineScale but for centered isolated math. Defaults to 1.2.
    open var mathFont: (name: String, inlineScale: CGFloat, displayScale: CGFloat) = (MTFontNameLatinModern, 1.1, 1.2) { didSet {
        mathFontName = mathFont.name
        mathFontScaleInline = max(0, mathFont.inlineScale)
        mathFontScaleDisplay = max(0, mathFont.displayScale)
        scheduleUpdateMath()
    }}
    
    /// Set true to not look for LaTeX between $ ... $ and $$ .... $$.
    @objc public var ignore$: Bool = false { didSet {
        if oldValue != ignore$, attributedText != nil {
            attributedText = replaceAttachmentsWithLatex()
        }
    }}
    
    
    // MARK: - Custom Private Properties

    // When text only contains a centered equation textAlignment gets automatically changed to .centered.
    // Use desiredAlignment to set the textAlignment back to its original alignment when changing the text.
    var desiredTextAlignment: NSTextAlignment!
    var layingoutSubviews = false
    var updateScheduled = false
    
    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2
    
    
    // MARK: - Property overrides
    
    open override var text: String! {
        get {
            return super.text == nil ? nil : replaceAttachmentsWithLatex().string
        }
        set {
            updateScheduled = false
            super.textAlignment = desiredTextAlignment
            super.text = newValue
            attributedText = attributedText
        }
    }
    
    open override var attributedText: NSAttributedString! {
        get {
            return super.attributedText
        }
        set {
            updateScheduled = false

            let latexedAttributedText = newValue.unparseMath().parseMath(
                ignore$: ignore$
            )
            super.textAlignment = desiredTextAlignment
            super.attributedText = latexedAttributedText
            scheduleUpdateMath()
        }
    }

    open override var textAlignment: NSTextAlignment {
        get {
            return super.textAlignment
        }
        set {
            desiredTextAlignment = newValue
            super.textAlignment = newValue
            if let centeredDisplayMath = attributedText.centerDisplayMath() {
                super.attributedText = centeredDisplayMath
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

    
    // MARK: - Method overrides
    
    open override func setNeedsLayout() {
        if !layingoutSubviews {
            super.setNeedsLayout()
        }
    }
    
    open override func layoutIfNeeded() {
        updateMath()
        super.layoutIfNeeded()
    }

    open override func layoutSubviews() {
        layingoutSubviews = true
        updateMath()
        super.layoutSubviews()
        layingoutSubviews = false
    }
    
    
    // MARK: - Custom methods
    
    @objc func scheduleUpdateMath() {
        guard !updateScheduled else { return }
        updateScheduled = true
        setNeedsLayout() //TODO necessary?
    }
    
    func updateMath() {
        guard updateScheduled else { return }
        updateScheduled = false
        let scale = traitCollection.displayScale
        if let attributedString = attributedText.updateMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay,
            fallbackFontSize: font.pointSize,
            fallbackColor: textColor
        ) {
            super.attributedText = nil // when text doesn't change its attachments won't be updated, to force this set to nil first
            super.textAlignment = desiredTextAlignment // just in case
            super.attributedText = attributedString
//            layoutIfNeeded() //TODO necessary?
        }
    }

    /// Revert to original string by finding text attachments and replace them with their LaTeX strings
    func replaceAttachmentsWithLatex() -> NSMutableAttributedString {
        
        var textAttachments = [(range: NSRange, string: String)]()
        let mutableAttributedSubstring = NSMutableAttributedString(attributedString: attributedText)
        
        mutableAttributedSubstring.enumerateAttribute(.attachment, in: NSRange(0..<mutableAttributedSubstring.length) , options: []) { (value, range, pointer) in
            if let textAttachment = value as? MathTextAttachment {
                textAttachments.append((range, textAttachment.latexWithTags))
            }
        }
        
        for attachment in textAttachments.reversed() {
            mutableAttributedSubstring.replaceCharacters(in: attachment.range, with: attachment.string)
        }

        let range = NSRange(location: 0, length: mutableAttributedSubstring.length)
        mutableAttributedSubstring.mutableString.replaceOccurrences(of: " ", with: "", options: [], range: range) // remove narrow no-break space used to fix a glitch

        return mutableAttributedSubstring
    }

}
