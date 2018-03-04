//
//  CGAffineTransform+Maths.swift
//  PhotoEditor
//
//  Created by Harry Jordan 23/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

public typealias AspectRatio = CGSize

extension CGAffineTransform {

    func scaledBy(x xScale: CGFloat, y yScale: CGFloat, fromAnchorPoint anchorPoint: CGPoint) -> CGAffineTransform {
        var transform = self
        transform = transform.translatedBy(x: anchorPoint.x, y: anchorPoint.y)
        transform = transform.scaledBy(x: xScale, y: yScale)
        transform = transform.translatedBy(x: -anchorPoint.x, y: -anchorPoint.y)
        return transform
    }

    func rotated(by rotation: CGFloat, aroundAnchorPoint anchorPoint: CGPoint) -> CGAffineTransform {
        var transform = self
        transform = transform.translatedBy(x: anchorPoint.x, y: anchorPoint.y)
        transform = transform.rotated(by: rotation)
        transform = transform.translatedBy(x: -anchorPoint.x, y: -anchorPoint.y)
        return transform
    }

    var scale: CGFloat {
        get {
            // Assuming that a scale is uniform
            // This will not hold true if we skew the image
            return sqrt(determinant)
        }
        set {
            a = newValue
            d = newValue
        }
    }

    var rotation: CGFloat {
        // CGFloat angle = atan2f(yourView.transform.b, yourView.transform.a);
        // Ref: https://stackoverflow.com/a/24820375
        get {
            return atan2(b, a)
        }
        set {
            // Invert the existing rotation, and add the new one
            var transform: CGAffineTransform = .identity
            transform = transform.rotated(by: -rotation + newValue)

            self = transform.concatenating(self)
        }
    }

    var translation: CGPoint {
        return CGPoint(x: tx, y: ty)
    }

    var rotatatedToAxis: CGAffineTransform {
        let rotation = self.rotation
        let quarterCircle = CGFloat.pi / 2

        if rotation.isApproximatelyEqual(0.0) {
            // Avoid division of zero
            return self
        } else {
            let alignedRotation = round(rotation / quarterCircle) * quarterCircle

            var rotatedTransform = self
            rotatedTransform.rotation = alignedRotation
            return rotatedTransform
        }
    }

    var determinant: CGFloat {
        // Ref: https://www.mathsisfun.com/algebra/matrix-determinant.html
        return (a * d) - (b * c)
    }

    var normalizingTransform: CGAffineTransform {
        var normalizingTransform = self.inverted()
        normalizingTransform.tx = 0.0
        normalizingTransform.ty = 0.0
        return normalizingTransform
    }

    var string: String {
        return "{a: \(a), b: \(b), c: \(c), d: \(d), tx: \(tx), ty: \(ty)}"
    }

    var debugDescription: String {
        return self.string
    }

}
