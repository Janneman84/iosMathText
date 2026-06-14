//
//  ScalingTextAttachment.swift
//  iosMathText
//
//  Created by Jan de Vries on 13/06/2026.
//

import UIKit

/// NSTextAttachment that scales its image down when it is wider than fits the line. Normally these would get clipped.
class ScalingTextAttachment: NSTextAttachment {

    @available(iOS 15.0, tvOS 15.0, *) //fallback for older iOS below
    override func attachmentBounds(for attributes: [NSAttributedString.Key : Any], location: any NSTextLocation, textContainer: NSTextContainer?, proposedLineFragment: CGRect, position: CGPoint) -> CGRect {
        return adjustBounds(
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
        return adjustBounds(
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
            width: (image.size.width * scalingFactor) - 1, //leave a little more room for a zero width space to fit behind instead of under
            height: image.size.height * scalingFactor
        )
    }
}
