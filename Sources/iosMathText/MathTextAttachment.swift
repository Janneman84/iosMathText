//
//  MathTextAttachment.swift
//  iosMathText
//
//  Created by Jan de Vries on 13/06/2026.
//

import UIKit
import iosMath

class MathTextAttachment: NSTextAttachment {
    
    private static let mtMathUILabel = MTMathUILabel()

    private(set) var latex: String = ""
    private(set) var substring: String = "" // latex + open/close tags
    private(set) var font: String = MTFontNameLatinModern
    private(set) var color: UIColor = .label
    private(set) var scale: CGFloat = 2
    private(set) var fontSize: CGFloat = 14
    private(set) var mode: MTMathUILabelMode = .text
    private var renderingMode: UIImage.RenderingMode = .alwaysTemplate
    private var key: String {
        "\(latex);\(font);\(fontSize);\(scale);\(mode.rawValue);\(renderingMode == .alwaysOriginal ? color.debugDescription : "")"
    }
    
    func update(latex: String? = nil, substring: String? = nil, font: String? = nil, fontSize: CGFloat? = nil, color: UIColor? = nil, scale: CGFloat? = nil, mode: MTMathUILabelMode? = nil, updateImage: Bool = true) -> Bool {
        print(color.debugDescription)
        let dontUpdateImage = !updateImage
        var updateImage = image == nil
        
        if let substring {
            self.substring = substring
        }        
        if let latex, self.latex != latex {
            self.latex = latex
            NotificationCenter.default.removeObserver(self)
            if latex.contains("color") {
                renderingMode = .alwaysOriginal
                NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name("_UIScreenDefaultTraitCollectionDidChangeNotification"), object: nil)
            } else {
                renderingMode = .alwaysTemplate
            }
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
            if renderingMode == .alwaysOriginal {
                updateImage = true
            }
        }
        
        if updateImage && !dontUpdateImage {
            image = createMathLabelImage() ?? image
        }
        
        return updateImage
    }
    
    @objc func appearanceChanged() {
        image = createMathLabelImage() ?? image
    }
    
    private func createMathLabelImage() -> UIImage? {

        let label = renderingMode == .alwaysTemplate ? Self.mtMathUILabel : MTMathUILabel()
        if renderingMode == .alwaysOriginal {
            label.textColor = color
        }
        label.mode = mode
        label.contentScaleFactor = scale
        label.fontSize = fontSize
        label.font = MTFontManager.fontManager.font(withName: font, size: label.fontSize)
        // label.backgroundColor = .systemTeal.withAlphaComponent(0.75)
        label.latex = latex

        if label.error != nil {
            print(label.error!)
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

        // render label to image
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, scale)
        defer { UIGraphicsEndImageContext() }
        label.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? nil
        let baselineOffset = floor((label.displayList?.position.y ?? 0)*scale)/scale
        let nudge = 0.45/scale // fixes baseline sometimes being off a pixel
        
        let result = image?.cgImage == nil ? nil : UIImage(
            cgImage: image!.cgImage!,
            scale: scale,
            orientation: .downMirrored)
        .withBaselineOffset(fromBottom: baselineOffset + nudge)
        .withRenderingMode(renderingMode)

        return result
    }
    

    @available(iOS 15.0, tvOS 15.0, *) //fallback for older iOS below
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
}
