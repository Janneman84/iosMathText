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
/// Set math font with `setMathFont()` and text font/size/color/alignment **first**, then just set `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text or attributedText to this view.
///
open class MathLabel: UILabel {
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
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
        didSet {
            attributedText = attributedText
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
                self.ignoreAttributedTextDidSet = true
                self.attributedText = latexedAttributedText
                scheduleUpdateMath()
                self.ignoreAttributedTextDidSet = false
            }
        }
    }
    
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
            mathFontScaleDisplay: mathFontScaleDisplay,
            fallbackFontSize: font.pointSize,
            fallbackColor: textColor
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

}
