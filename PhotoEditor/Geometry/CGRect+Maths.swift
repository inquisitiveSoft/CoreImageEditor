//
//  CGRect+Maths.swift
//  PhotoEditor
//
//  Created by Harry Jordan 23/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

extension CGRect {

    init(center: CGPoint, size: CGSize) {
        var rect = CGRect(origin: .zero, size: size)
        rect.center = center

        self = rect
    }

    init(aspectRatio: AspectRatio, within: CGRect) {
        let targetSize = aspectRatio.scaledToFit(within.size)
        var targetRect = CGRect(origin: within.origin, size: targetSize)
        let difference = (within.size - targetSize) / 2.0
        targetRect.origin += CGPoint(size: difference)

        self = targetRect
    }

    init(aspectRatio: AspectRatio, toFill rectToFill: CGRect) {
        let targetSize = aspectRatio.scaledToFill(rectToFill.size)
        var targetRect = CGRect(origin: .zero, size: targetSize)
        targetRect.origin = rectToFill.origin

        self = targetRect
    }

    public var center: CGPoint {
        get {
            return CGPoint(x: midX, y: midY)
        }

        mutating set {
            var updatedRect = self
            updatedRect.origin.x = newValue.x - (updatedRect.size.width / 2)
            updatedRect.origin.y = newValue.y - (updatedRect.size.height / 2)
            self = updatedRect
        }
    }

    public func centered(on newCenter: CGPoint) -> CGRect {
        var centeredRect = self
        centeredRect.center = newCenter
        return centeredRect
    }

    var points: [CGPoint] {
        return [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: maxY),
        ]
    }

    var interleavedPoints: [CGPoint] {
        /*
         Give a rectangle with points labeled:

         A ---- B
         |      |
         |      |
         D ---- C

         This returns the points ordered ACBD, which in theory
         reduces the error when applying repeated scale transforms
         */
        return [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY),
        ]
    }

}
