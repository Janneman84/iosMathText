//
//  MathTextView.swift
//  iosMathTextView
//
//  Created by Jan de Vries on 13/06/2026.
//

#if canImport(UIKit)
import UIKit
import iosMath

@available(*, deprecated, message: "renamed to 'MathTextView'")
open class iosMathTextView: MathTextView {}

/// TextView that scans for LaTeX tags in the text and replaces them with LaTeX styled inline images of the containing equations.
/// Set math font with `mathFont` or `setMathFont()`, then set either `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` (attributed) string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text or attributedText to this view.
///
open class MathTextView: UITextView, UIGestureRecognizerDelegate  {

    // MARK: - Initializer overrides
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        initialize()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    
    var initialized = false
    
    func initialize() {
        guard !initialized else { return }
        initialized = true
        desiredTextAlignment = textAlignment
        
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleUpdateMath), name: UIContentSizeCategory.didChangeNotification, object: nil)
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(didBeginEditing), name: UITextView.textDidBeginEditingNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(didEndEditing), name: UITextView.textDidEndEditingNotification, object: self)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        #endif
    }
    
    
    // MARK: - Public Interface
    
    /// Instance MathTextView with the math font properties.
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
        var isEditing = false
        #if os(iOS)
        isEditing = isEditable && isFirstResponder
        #endif
        if oldValue != ignore$, attributedText != nil, !isEditing {
            attributedText = replaceAttachmentsWithLatex(updateSelection: false)
        }
    }}
    
    
    // MARK: - Custom Private Properties

    // When text only contains a centered equation textAlignment gets changed to .centered.
    // Use tempAlignment to set the textAlignment back to its original alignment.
    var desiredTextAlignment: NSTextAlignment!
    var layingoutSubviews = false
    var updateScheduled = false
    
    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2
    
    
    // MARK: - Property overrides
    
    open override var text: String! {
        get {
            return replaceAttachmentsWithLatex(updateSelection: false)?.string
        }
        set {
            updateScheduled = false
            super.textAlignment = desiredTextAlignment
            super.text = newValue
        }
    }

    open override var attributedText: NSAttributedString! {
        get {
            return super.attributedText
        }
        set {
            updateScheduled = false
            super.textAlignment = desiredTextAlignment ?? textAlignment
            
            let unparsedMath = newValue?.unparseMath()
            if !isFirstResponder, let latexedAttributedText = unparsedMath?.parseMath(
                ignore$: ignore$
            ) {
                super.attributedText = latexedAttributedText
                scheduleUpdateMath()
            } else {
                super.attributedText = unparsedMath
            }
            
            // when setting attributed string with no attributes the alignment gets set to natural
            if textAlignment == .natural {
                desiredTextAlignment = .natural
            }
        }
    }
    
    open override var textAlignment: NSTextAlignment {
        get {
            return super.textAlignment
        }
        set {
            desiredTextAlignment = newValue
            super.textAlignment = newValue
            if let centeredDisplayMath = attributedText?.centerDisplayMath() {
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
    
    // This makes sure after calling layoutSubtreeIfNeeded() the frame gets updated instantly/correctly.
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
        setNeedsLayout()
    }
    
    func updateMath() {
        guard updateScheduled else { return }
        updateScheduled = false
        let scale = traitCollection.displayScale
        if let attributedString = attributedText?.updateMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay
        ) {
            super.attributedText = nil // when text doesn't change its attachments won't be updated, to force this set to nil first
            super.textAlignment = desiredTextAlignment // just in case
            super.attributedText = attributedString
            //super.layoutIfNeeded() //unnecessary for now
        }
    }

    
    // MARK: - Editing
    
    @objc func didBeginEditing() {
        // selectedRange isn't available yet, so wait
        DispatchQueue.main.async() { [self] in
            _ = replaceAttachmentsWithLatex(updateSelection: true)
        }
    }
    
    @objc func didEndEditing() {
        attributedText = attributedText // trigger setter
    }
    
    /// Replaces all text attachments with their LaTeX string, preserving surrounding formatting and keeping the cursor position intact.
    func replaceAttachmentsWithLatex(updateSelection: Bool) -> NSMutableAttributedString? {
        guard attributedText != nil else { return nil }
        let mutableAttributedText = NSMutableAttributedString(attributedString: self.attributedText)
        let fullRange = NSRange(location: 0, length: mutableAttributedText.length)
        
        let originalSelectedRange = self.selectedRange
        var targetLocation = originalSelectedRange.location
        var targetLength = originalSelectedRange.length
        
        // 1. Structural tuple to store all planned modifications
        var modifications: [(range: NSRange, replacement: NSAttributedString)] = []
        
        // Step A: Scan for NSTextAttachments
        mutableAttributedText.enumerateAttributes(in: fullRange, options: []) { (attributes, range, stop) in
            if let attachment = attributes[.attachment] as? MathTextAttachment {
                let replacementText = attachment.latexWithTags
                
                var cleanAttributes = attributes
                cleanAttributes.removeValue(forKey: .attachment)
                
                // Remove paragraph style / text alignment to prevent layout shifts
                cleanAttributes.removeValue(forKey: .paragraphStyle)
                
                let replacementString = NSAttributedString(string: replacementText, attributes: cleanAttributes)
                modifications.append((range: range, replacement: replacementString))
            }
        }
        
        // Step B: Scan for narrow no-break spaces (\u{202F})
        let string = mutableAttributedText.string as NSString
        var searchRange = NSRange(location: 0, length: string.length)
        
        while searchRange.location < string.length {
            let foundRange = string.range(of: " ", options: [], range: searchRange)
            if foundRange.location == NSNotFound { break }
            
            // Replace the space with an empty string to remove it
            modifications.append((range: foundRange, replacement: NSAttributedString(string: "")))
            
            // Move the search range to the remaining part of the string
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(location: nextLocation, length: string.length - nextLocation)
        }
        
        // 2. Sort all modifications by location in descending order (reversed)
        // This prevents indices from shifting while looping
        modifications.sort { $0.range.location > $1.range.location }
        
        // 3. Execute modifications backwards and correct the cursor position
        for mod in modifications {
            mutableAttributedText.replaceCharacters(in: mod.range, with: mod.replacement)
            
            // Calculate length delta (new text length minus old range length)
            let delta = mod.replacement.length - mod.range.length
            
            // Shift cursor location if the modification happened before the cursor
            if mod.range.location < originalSelectedRange.location {
                targetLocation += delta
            }
            
            // Adjust selection length if the modification happened inside the current selection
            if mod.range.location >= originalSelectedRange.location &&
               (mod.range.location + mod.range.length) <= (originalSelectedRange.location + originalSelectedRange.length) {
                targetLength += delta
            }
        }
        
        if updateSelection {
            // 4. Update text view content and safely assign the adjusted selection range
            super.attributedText = mutableAttributedText
            
            let safeLocation = max(0, min(targetLocation, mutableAttributedText.length))
            let safeLength = max(0, min(targetLength, mutableAttributedText.length - safeLocation))
            select(self)
            self.selectedRange = NSRange(location: safeLocation, length: safeLength)
            self.scrollRangeToVisible(self.selectedRange)
        }
        
        return mutableAttributedText
    }
    
    #if os(iOS)
    // Allow the system's text selection gestures to run alongside your tap gesture
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // Process tapping on an equation to place the cursor accordingly
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .recognized, isEditable else { return }
        
        let touchLocation = gesture.location(in: self)
        guard let textPosition = closestPosition(to: touchLocation) else { return }
        let characterIndex = offset(from: beginningOfDocument, to: textPosition)
        
        // Scenario A: Tapping the left half. The index is exactly the attachment's index.
        if characterIndex < attributedText.length {
            let attributes = attributedText.attributes(at: characterIndex, effectiveRange: nil)
            if attributes[.attachment] != nil {
                // Cursor should be placed directly after the attachment, so index + 1
                selectedRange = NSRange(location: characterIndex + 1, length: 0)
                becomeFirstResponder()
                return
            }
        }
        
        // Scenario B: Tapping the right half. The engine already returns the index AFTER the attachment.
        // The attachment itself is located one position back (characterIndex - 1).
        let previousIndex = characterIndex - 1
        if previousIndex >= 0 && previousIndex < attributedText.length {
            let attributes = attributedText.attributes(at: previousIndex, effectiveRange: nil)
            if attributes[.attachment] != nil {
                // The characterIndex we received is already directly after the attachment.
                // No +1 needed here, preventing the cursor from jumping too far.
                selectedRange = NSRange(location: characterIndex, length: 0)
                becomeFirstResponder()
                return
            }
        }
    }

    open override func copy(_ sender: Any?) {

        // Find text attachments and replace them with their respective LaTeX string,
        // then include the selected images and add it all to the pasteboard.
        
        var items = [[String: Any]]()
        let mutableAttributedSubstring = NSMutableAttributedString(attributedString: attributedText.attributedSubstring(from: selectedRange))
        
        mutableAttributedSubstring.enumerateAttribute(.attachment, in: NSRange(0..<mutableAttributedSubstring.length) , options: []) { (value, range, pointer) in
            if let textAttachment = value as? MathTextAttachment, let image = textAttachment.image {
                items.append(["public.png" : image])
            }
        }

        items.insert(["public.utf8-plain-text" : mutableAttributedSubstring.replaceAttachmentsWithLatex()], at: 0)
        UIPasteboard.general.items = items

    }
    #endif
}
#endif
