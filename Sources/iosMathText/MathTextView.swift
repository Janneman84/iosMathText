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
/// Set math font with `setMathFont()`, then set either `text` or `attributedText` like normal.
///
/// If you are using parsers for e.g. Markdown or HTML you should first preparse the text for math with the `preparseMath()` (attributed) string extension.
/// This prevents other parsers from messing with the LaTeX code. Once finished parsing set the text or attributedText to this view.
///
open class MathTextView: UITextView, UIGestureRecognizerDelegate  {

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        initialize()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    func initialize() {
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

    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2
    
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

    var ignoreAttributedTextDidSet = false

    // When text only contains a centered equation textAlignment gets changed to .centered.
    // Use tempAlignment to set the textAlignment back to its original alignment.
    var tempAlignment: NSTextAlignment? = .natural
    var ignoreTextAlignmentSet = false

    open override var text: String! {
        get {
            return super.text == nil ? nil : replaceAttachmentsWithAccessibilityHints(updateSelection: false)
        }
        set {
            updateScheduled = false
            if let tempAlignment {
                ignoreTextAlignmentSet = true
                textAlignment = tempAlignment
                ignoreTextAlignmentSet = false
                self.tempAlignment = nil
            }
            super.text = newValue
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
            
            let unparsedMath = attributedText?.unparseMath()
            if !isFirstResponder, let latexedAttributedText = unparsedMath?.parseMath(
                pixelDensity: scale,
                mathFontName: mathFontName,
                mathFontScaleInline: mathFontScaleInline,
                mathFontScaleDisplay: mathFontScaleDisplay
            ) {
                ignoreAttributedTextDidSet = true
                attributedText = latexedAttributedText
                scheduleUpdateMath()
                ignoreAttributedTextDidSet = false
            } else {
                ignoreAttributedTextDidSet = true
                attributedText = unparsedMath
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

    @objc func didBeginEditing() {
        // selectedRange isn't available yet, so wait
        DispatchQueue.main.async() { [self] in
            ignoreAttributedTextDidSet = true
            replaceAttachmentsWithAccessibilityHints()
            ignoreAttributedTextDidSet = false
        }
    }
    
    @objc func didEndEditing() {
        attributedText = attributedText
        scheduleUpdateMath()
    }
    
    /// Replaces all text attachments with their accessibility hint string, preserving surrounding formatting and keeping the cursor position intact.
    func replaceAttachmentsWithAccessibilityHints(updateSelection: Bool = true) -> String {
        let mutableAttributedText = NSMutableAttributedString(attributedString: self.attributedText)
        let fullRange = NSRange(location: 0, length: mutableAttributedText.length)
        
        let originalSelectedRange = self.selectedRange
        var targetLocation = originalSelectedRange.location
        var targetLength = originalSelectedRange.length
        
        // 1. Structural tuple to store all planned modifications
        var modifications: [(range: NSRange, replacement: NSAttributedString)] = []
        
        // Step A: Scan for NSTextAttachments
        mutableAttributedText.enumerateAttributes(in: fullRange, options: []) { (attributes, range, stop) in
            if let attachment = attributes[.attachment] as? NSTextAttachment {
                let replacementText = attachment.accessibilityHint ?? ""
                
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
            self.attributedText = mutableAttributedText
            
            let safeLocation = max(0, min(targetLocation, mutableAttributedText.length))
            let safeLength = max(0, min(targetLength, mutableAttributedText.length - safeLocation))
            select(self)
            self.selectedRange = NSRange(location: safeLocation, length: safeLength)
        }
        
        return mutableAttributedText.string
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
        super.copy(sender)
        // Find text attachments and replace them with their respective accessibilityHint,
        // then include the selected images and add it all to the pasteboard.
        
        var items = [[String: Any]]()
        var textAttachments = [(range: NSRange, string: String)]()
        let mutableAttributedSubstring = NSMutableAttributedString(attributedString: attributedText.attributedSubstring(from: selectedRange))
        
        mutableAttributedSubstring.enumerateAttribute(.attachment, in: NSRange(0..<mutableAttributedSubstring.length) , options: []) { (value, range, pointer) in
            if let textAttachment = value as? MathTextAttachment {
                textAttachments.append((range, textAttachment.accessibilityHint ?? ""))
                if let image = textAttachment.image {
                    items.append(["public.png" : image])
                }
            }
        }
        
        for attachment in textAttachments.reversed() {
            mutableAttributedSubstring.replaceCharacters(in: attachment.range, with: attachment.string)
        }

        let finalString = mutableAttributedSubstring.string.replacingOccurrences(of: " ", with: "") // remove narrow no-break space used to fix a glitch
        items.insert(["public.utf8-plain-text" : finalString], at: 0)
        UIPasteboard.general.items = items

    }
    #endif
}
