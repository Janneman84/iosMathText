//
//  MathTextViewMac.swift
//  iosMathText
//
//  Created by Jan de Vries on 10/10/2026.
//

#if canImport(AppKit)
import AppKit
import iosMath

open class MathTextView: NSTextView {

    // MARK: - Initializer overrides
    
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    override public init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    var didCommonInit = false
    
    private func commonInit() {
        guard !didCommonInit else { return }
        didCommonInit = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeSelection), name: NSTextView.didChangeSelectionNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(didEndEditing), name: NSTextView.didEndEditingNotification, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(textStorageWillProcessMathEditing(_:)), name: NSTextStorage.willProcessEditingNotification, object: textStorage)
    }
 
    // Gets triggered when the text changes, either by typing, setting string or calling textStorage.setAttributedString().
    // It is used for the latter, so setting attributed string will parse math.
    @objc private func textStorageWillProcessMathEditing(_ notification: Notification) {
        invalidateIntrinsicContentSize() // TODO keep this here?
        guard !isEditing && !ignoreAttributedStringSet else { return }
//        if editedMask.contains(.editedCharacters) {
        parseAttributedString()
//        }
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
        if oldValue != ignore$, !isEditing {
            // Reconstruct original string and trigger the setter to reparse
            textStorage?.setAttributedString(attributedString().replaceAttachmentsWithLatex())
        }
    }}
    
    var mathFontName: String = MTFontNameLatinModern
    var mathFontScaleInline: CGFloat = 1.1
    var mathFontScaleDisplay: CGFloat = 1.2

    var updateScheduled = false
    var prevScale: CGFloat = 0
    var ignoreAttributedStringSet = false
    var ignoreDidChangeSelection = false
    var isEditing = false

    
    // MARK: - Property overrides
    
    open override var string: String {
        get {
            return attributedString().replaceAttachmentsWithLatex().string
        }
        set {
            super.string = newValue
        }
    }
    
    open override var alignment: NSTextAlignment {
        didSet {
            if alignment != oldValue && !isEditing, let cas = attributedString().centerDisplayMath() {
                textStorage?.setAttributedString(cas)
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
        
        if let attributedString = NSMutableAttributedString(attributedString: attributedString()).updateMath(
            pixelDensity: scale,
            mathFontName: mathFontName,
            mathFontScaleInline: mathFontScaleInline,
            mathFontScaleDisplay: mathFontScaleDisplay,
//            fallbackFontSize: font.pointSize,
//            fallbackColor: textColor
        ) {
            ignoreAttributedStringSet = true
            textStorage?.setAttributedString(attributedString)
            ignoreAttributedStringSet = false
        }
    }
    
    // used for in case self.window.makeFirstResponder() is called programmatically
    open override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        
        DispatchQueue.main.async() { [self] in
            if success && isEditable && !isEditing && window?.firstResponder === self {
                isEditing = true
                ignoreDidChangeSelection = true
                _ = replaceAttachmentsWithLatex(updateSelection: true)
            }
        }
        return success
    }
    
    
    // MARK: - Editing
       
    // Triggered after clicking the view (mouse up), or after finishing selection (mouse up after dragging).
    // Also triggered when text is updated?
    @objc func didChangeSelection() {
        if ignoreDidChangeSelection == false && window?.firstResponder === self && isEditable {
            ignoreDidChangeSelection = true
            _ = replaceAttachmentsWithLatex(updateSelection: true)
        }
    }

    @objc func didEndEditing() {
        isEditing = false
        parseAttributedString()
        ignoreDidChangeSelection = false
    }
    
    // Search attributed string for LateX codes and replace them with empty MathTextAttachments.
    func parseAttributedString() {

        updateScheduled = false
        ignoreAttributedStringSet = true
        self.textStorage?.setAttributedString(
            attributedString().unparseMath().parseMath( ignore$: ignore$ )
        )
        ignoreAttributedStringSet = false
        scheduleUpdateMath() // generates equation images for the empty MathTextAttachments
    }
    
    /// Replaces all text attachments with their LaTeX string, preserving surrounding formatting and keeping the cursor position intact.
    func replaceAttachmentsWithLatex(updateSelection: Bool) -> NSMutableAttributedString? {
        let attributedText = attributedString()
        let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
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
            
            ignoreAttributedStringSet = true
            textStorage?.setAttributedString(mutableAttributedText)
            ignoreAttributedStringSet = false
            
            let safeLocation = max(0, min(targetLocation, mutableAttributedText.length))
            let safeLength = max(0, min(targetLength, mutableAttributedText.length - safeLocation))

            self.selectedRange = NSRange(location: safeLocation, length: safeLength)
            self.scrollRangeToVisible(self.selectedRange)
        }
        
        return mutableAttributedText
    }
    
    // Check for click event on attachment, in that case place cursor behind it and make first responder.
    public override func mouseDown(with event: NSEvent) {

        guard isEditable else {
            super.mouseDown(with: event)
            return
        }
        
        isEditing = true
        
        // Convert mouse location to the coordinates within the text view
        let touchLocation = self.convert(event.locationInWindow, from: nil)
        let characterIndex = self.characterIndexForInsertion(at: touchLocation)
        let textStorageLength = self.textStorage?.length ?? 0
        
        // Scenario A: Click on left half of the attachment
        if characterIndex < textStorageLength {
            let attributes = self.textStorage?.attributes(at: characterIndex, effectiveRange: nil) ?? [:]
            if attributes[.attachment] != nil {
                // Cursor direct achter het attachment plaatsen -> index + 1
                self.setSelectedRange(NSRange(location: characterIndex + 1, length: 0))
                self.window?.makeFirstResponder(self)
                return // Stop further processing so that click isn't overwritten
            }
        }
        
        // Scenario B: Click right half
        let previousIndex = characterIndex - 1
        if previousIndex >= 0 && previousIndex < textStorageLength {
            let attributes = self.textStorage?.attributes(at: previousIndex, effectiveRange: nil) ?? [:]
            if attributes[.attachment] != nil {
                // De index is al direct na het attachment
                self.setSelectedRange(NSRange(location: characterIndex, length: 0))
                self.window?.makeFirstResponder(self)
                return // Stop further processing
            }
        }
        
        // If not clicked on an attachment pass on the event for regular processing.
        super.mouseDown(with: event)
    }

    open override func copy(_ sender: Any?) {

        guard textStorage != nil else {
            super.copy(sender)
            return
        }
        
        // Find text attachments and replace them with their respective LaTeX string,
        // then include the selected images and add it all to the pasteboard.
        
        var image: NSImage?
        var textAttachments = [(range: NSRange, string: String)]()
        let mutableAttributedSubstring = NSMutableAttributedString(attributedString: textStorage!.attributedSubstring(from: selectedRange))
        
        mutableAttributedSubstring.enumerateAttribute(.attachment, in: NSRange(0..<mutableAttributedSubstring.length) , options: []) { (value, range, pointer) in
            if let textAttachment = value as? MathTextAttachment {
                textAttachments.append((range, textAttachment.latexWithTags))
                // only when a single equation is selected, copy its image to pasteboard
                if selectedRange.length == 1 {
                    image = textAttachment.image
                }
            }
        }
        
        for attachment in textAttachments.reversed() {
            mutableAttributedSubstring.replaceCharacters(in: attachment.range, with: attachment.string)
        }
        let finalString = mutableAttributedSubstring.string.replacingOccurrences(of: " ", with: "") // remove narrow no-break space used to fix a glitch

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var pasteboardItems = [NSPasteboardItem]()

        let textItem = NSPasteboardItem()
        textItem.setString(finalString, forType: .string)
        pasteboardItems.append(textItem)

        if let tiffData = image?.tiffRepresentation {
            let imageItem = NSPasteboardItem()
            imageItem.setData(tiffData, forType: .tiff)
            pasteboardItems.append(imageItem)
        }

        /*let success*/ _ = pasteboard.writeObjects(pasteboardItems)
    }
}
#endif
