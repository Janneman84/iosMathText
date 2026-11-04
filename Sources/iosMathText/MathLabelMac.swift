//
//  MathLabel.swift
//  iosMathText
//
//  Created by Jan de Vries on 29/08/2026.
//

#if canImport(AppKit)
import AppKit
import iosMath

/// This subclass of NSTextField acts like a label that scans for LaTeX tags in the text and replaces them with LaTeX styled inline images of the containing equations.
/// isEditable and isSelectable are locked to false for technical reasons, if you need this use MathTextView instead. isBezeled and isBordered are set to false too by default, but can be changed.
///
/// Usage: set math font with `mathFont` or `setMathFont()`, then set either `stringValue` or `attributedStringValue` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` (attributed) string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text or attributedString to this view.
///
open class MathLabel: NSTextField {
       
    
    // MARK: - Initializer overrides
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupStaticProperties()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStaticProperties()
    }

    var didSetupStaticProperties = false
    
    private func setupStaticProperties() {
        
        guard !didSetupStaticProperties else { return }
        didSetupStaticProperties = true
        
        // Enforce the locked states
        super.isEditable = false
        super.isSelectable = false
        
        // Typical label configurations (optional but highly recommended)
//        self.drawsBackground = false
        self.isBezeled = false
        self.isBordered = false
        
        attributedStringValue = attributedStringValue
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
    
    // MARK: - Custom Properties
    
    /// Set true to not look for LaTeX between $ ... $ and $$ .... $$.
    @objc public var ignore$: Bool = false { didSet {
        if oldValue != ignore$ {
            // Reconstruct original string and trigger the setter to reparse
            attributedStringValue = attributedStringValue.replaceAttachmentsWithLatex()
        }
    }}
    
    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2

    var updateScheduled = false
    var prevScale: CGFloat = 0
    
    
    // MARK: - Property overrides
    
     // Prevent external code from turning editability back on because that would break the text attachments.
     public override var isEditable: Bool {
         get { return false }
         set { /* Do nothing to keep it locked */ }
     }
     
     // Prevent external code from turning text selection back on because that would break the text attachments.
     public override var isSelectable: Bool {
         get { return false }
         set { /* Do nothing to keep it locked */ }
     }
    
    open override var stringValue: String {
        get {
            return attributedStringValue.replaceAttachmentsWithLatex().string
        }
        set {
            updateScheduled = false
            super.stringValue = newValue
            attributedStringValue = attributedStringValue
        }
    }
    
    open override var attributedStringValue: NSAttributedString {
        get {
            return super.attributedStringValue
        }
        set {
            updateScheduled = false

            let latexedAttributedText = newValue.unparseMath().parseMath(
                ignore$: ignore$
            )
            super.attributedStringValue = latexedAttributedText
            scheduleUpdateMath()
        }
    }
    
    open override var font: NSFont! {
        didSet {
            if font != nil && font != oldValue {
                attributedStringValue = attributedStringValue.alterFont(from: oldValue, to: font)
            }
        }
    }
    
    open override var textColor: NSColor! {
        didSet {
            if textColor != oldValue {
                attributedStringValue = attributedStringValue.alterTextColor(from: oldValue, to: textColor)
            }
        }
    }
    
    open override var alignment: NSTextAlignment {
        didSet {
            if alignment != oldValue {
                let altered = attributedStringValue.alterAlignment(from: oldValue, to: alignment)
                attributedStringValue = altered.centerDisplayMath() ?? altered
            }
        }
    }
    
        
    // MARK: - Method overrides

    // This makes sure after calling layoutSubtreeIfNeeded() the frame gets updated instantly/correctly.
    open override func layoutSubtreeIfNeeded() {
        updateMath()
        super.layoutSubtreeIfNeeded()
    }
    
    open override func layout() {
        updateMath()
        super.layout()
    }
    
    
    // MARK: - Custom methods

    @objc func scheduleUpdateMath() {
        guard !updateScheduled else { return }
        updateScheduled = true
        needsLayout = true
    }
    
    func updateMath() {
        let scale = self.window?.backingScaleFactor ?? 2.0
        guard updateScheduled || scale != prevScale else { return }

        prevScale = scale
        updateScheduled = false
        
        if let attributedString = attributedStringValue.updateMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay,
            fallbackFontSize: font.pointSize,
            fallbackColor: textColor
        ) {
            // when text doesn't change its attachments won't be updated, to force this empty it first
            super.attributedStringValue = NSAttributedString(string: "")
            super.attributedStringValue = attributedString
        }
    }
    
}
#endif
