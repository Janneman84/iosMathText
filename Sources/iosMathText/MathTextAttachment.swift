//
//  MathTextAttachment.swift
//  iosMathText
//
//  Created by Jan de Vries on 13/06/2026.
//

import iosMath

#if canImport(UIKit)
import UIKit
/// Bridges to `UIColor` on iOS, tvOS, and watchOS.
internal typealias MTColor = UIColor
internal typealias MTFont = UIFont
internal typealias MTImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Bridges to `NSColor` on macOS.
internal typealias MTColor = NSColor
internal typealias MTFont = NSFont
internal typealias MTImage = NSImage

/// A thread-safe observer that converts system appearance updates into standard notifications.
@MainActor
public final class MTAppearanceObserver {

    public static let shared = MTAppearanceObserver()

    private var observation: NSKeyValueObservation?
    
    private init() {
        // Safely hook into the application's appearance lifecycle on the MainActor
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            NotificationCenter.default.post(
                name: MathTextAttachment.appearanceChangeNotification,
                object: nil
            )
        }
    }
    
    /// Force-initializes the singleton instance. Call this once during app startup if needed.
    public func start() {}
}

#else
// Fallback for environments without UI frameworks (like Linux)
#error("Unsupported platform: requires UIKit or AppKit")
#endif


class MathTextAttachment: NSTextAttachment {
    
#if canImport(UIKit)
    @MainActor
    private static let mtMathUILabel = MTMathUILabel()
    private var renderingMode: UIImage.RenderingMode = .alwaysTemplate
    private(set) var color: MTColor = .label
#elseif canImport(AppKit)
    private(set) var color: MTColor = .labelColor
#endif
    fileprivate static let appearanceChangeNotification = Notification.Name("_UIScreenDefaultTraitCollectionDidChangeNotification")

    private(set) var latex: String = ""
    private(set) var latexWithTags: String = "" // LaTeX + open/close tags
    private(set) var font: String = MTFontNameLatinModern

    private(set) var scale: CGFloat = 2
    private(set) var fontSize: CGFloat = 14
    private(set) var mode: MTMathUILabelMode = .text


    @MainActor
    func update(latex: String? = nil, substring: String? = nil, font: String? = nil, fontSize: CGFloat? = nil, color: MTColor? = nil, scale: CGFloat? = nil, mode: MTMathUILabelMode? = nil, updateImage: Bool = true) -> Bool {

        let dontUpdateImage = !updateImage
        var updateImage = image == nil
        
        if let substring {
            self.latexWithTags = substring
        }
        if let latex, self.latex != latex {
            self.latex = latex
            NotificationCenter.default.removeObserver(self, name: Self.appearanceChangeNotification, object: nil) //TODO macos?
            #if os(iOS)
            NotificationCenter.default.removeObserver(self, name: UIPasteboard.changedNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(pasteBoardChanged), name: UIPasteboard.changedNotification, object: nil)
            #endif
            #if canImport(UIKit)
            if latex.contains("color") {
                renderingMode = .alwaysOriginal
                NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Self.appearanceChangeNotification, object: nil)
            } else {
                renderingMode = .alwaysTemplate
            }
            #elseif canImport(AppKit)
                NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Self.appearanceChangeNotification, object: nil)
            #endif
            updateImage = true
        }
        if let font, self.font != font {
            self.font = font
            updateImage = true
        }
        if let fontSize, self.fontSize != fontSize {
            self.fontSize = fontSize
            updateImage = true
        }
        if let scale, self.scale != scale {
            self.scale = scale
            updateImage = true
        }
        if let mode, self.mode != mode {
            self.mode = mode
            updateImage = true
        }
        if let color, self.color != color {
            self.color = color
            #if canImport(UIKit)
            if renderingMode == .alwaysOriginal {
                updateImage = true
            }
            #elseif canImport(AppKit)
            updateImage = true
            #endif
        }
        
        if updateImage && !dontUpdateImage {
            image = createMathLabelImage() ?? image
        }
        
        return updateImage
    }
    
    @MainActor
    @objc func appearanceChanged() {
        image = createMathLabelImage() ?? image
    }
    
    @MainActor
    private func createMathLabelImage() -> MTImage? {

        #if canImport(UIKit)
        let label = renderingMode == .alwaysTemplate ? Self.mtMathUILabel : MTMathUILabel()
        if renderingMode == .alwaysOriginal {
            label.textColor = color
        }
        label.contentScaleFactor = scale
        #elseif canImport(AppKit)
        let label = MTMathUILabel()
        label.textColor = color
        MTAppearanceObserver.shared.start()
        #endif
        
        label.mode = mode
        label.fontSize = fontSize
        let mtFont = MTFontManager.fontManager.font(withName: font, size: label.fontSize)
        assert(mtFont != nil, "Invalid mathFont.name provided: \'\(font)\'. Import 'iosMath' to access consts that start with \'MTFontName\'.")
        label.font = mtFont ?? label.font
        // label.backgroundColor = .systemTeal.withAlphaComponent(0.75)
        label.latex = latex

        if label.error != nil {
            print("iosMath error processing \"\(latex)\": \(label.error?.localizedDescription ?? "unknown")" )
            return nil
        }
        
        let inset = round(label.fontSize * 0.025 * scale)/scale
        // you need at least a little bit of insets to prevent clipping
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

        #if canImport(UIKit)
        
        // render label to image
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, scale)
        defer { UIGraphicsEndImageContext() }
        label.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? nil
        let baselineOffset = floor((label.displayList?.position.y ?? 0)*scale)/scale
        // Nudge fixes baseline sometimes being off a pixel.
        // Add some randomness for identification purposes when copying.
        let nudge = CGFloat.random(in: 0.445..<0.455)/scale
        let result = image?.cgImage == nil ? nil : UIImage(
            cgImage: image!.cgImage!,
            scale: scale,
            orientation: .downMirrored)
        .withBaselineOffset(fromBottom: baselineOffset + nudge)
        .withRenderingMode(renderingMode)
        return result
        
        #elseif canImport(AppKit)
        
        label.layoutSubtreeIfNeeded()
        let size = label.bounds.size
        let baselineOffset = floor((label.displayList?.position.y ?? 0)*scale)/scale
        self.bounds = .init(x: 0, y: 0-baselineOffset, width: size.width, height: size.height)
        guard let bitmapRep = label.bitmapImageRepForCachingDisplay(in: label.bounds) else {
            return nil
        }
        bitmapRep.size = label.bounds.size
        label.cacheDisplay(in: label.bounds, to: bitmapRep)
        let image = NSImage(size: label.bounds.size)
        image.addRepresentation(bitmapRep)
        return image
        
        #endif
    }
    

    @available(iOS 15.0, tvOS 15.0, macOS 12.0, *) //fallback for older iOS below
    override func attachmentBounds(for attributes: [NSAttributedString.Key : Any], location: any NSTextLocation, textContainer: NSTextContainer?, proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        return image == nil ? .zero : adjustBounds(
            super.attachmentBounds(
                for: attributes,
                location: location,
                textContainer: textContainer,
                proposedLineFragment: proposedLineFragment,
                position: position),
            lineFragment: proposedLineFragment)
    }
    
    //This override will only get called in case TextView uses TextKit 1,
    //i.e. iOS 14 or lower or forcing to use TextKit 1 text layout in constructor or storyboard.
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return image == nil ? .zero : adjustBounds(
            super.attachmentBounds(
                for: textContainer,
                proposedLineFragment: lineFrag,
                glyphPosition: position,
                characterIndex: charIndex),
            lineFragment: lineFrag)
    }
    
    /// Scales down bounds when too wide.
    func adjustBounds(_ initialBounds: CGRect, lineFragment: CGRect) -> CGRect {

        guard let image = self.image, lineFragment.size.width <= image.size.width else {
            return initialBounds
        }
        
        let scalingFactor = lineFragment.size.width / image.size.width
        return CGRect(
            x: initialBounds.origin.x,
            y: initialBounds.origin.y,
            width: (image.size.width * scalingFactor) - 1, // leave a little more room for a zero width space to fit behind instead of under
            height: image.size.height * scalingFactor
        )
    }

    // When copying an equation image by long pressing it, have its LaTeX code string also added to the pasteboard.
    #if os(iOS)
    @objc func pasteBoardChanged() {
        if UIPasteboard.general.string == nil, // prevents infinite looping
           let pbImage = UIPasteboard.general.image,
           image?.baselineOffsetFromBottom != nil,
           pbImage.baselineOffsetFromBottom != nil,
           pbImage.size == image!.size,
           Float(pbImage.baselineOffsetFromBottom!) == Float(image!.baselineOffsetFromBottom!) // the offset is abused for identification
        {
            var items: [String: Any] = [:]
            items["public.utf8-plain-text"] = latexWithTags
            items[pbImage.cgImage?.utType as? String ?? "public.png"] = pbImage
            UIPasteboard.general.items = [items]
        }
    }
    #endif
}
