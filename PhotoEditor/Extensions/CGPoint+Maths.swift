//
//  CGPoint+Maths.swift
//  PhotoEditor
//
//  Created by Harry Jordan 23/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

// MARK: Extending CoreGraphic types to support basic math operations

public extension CGPoint {

    init(size: CGSize) {
        self = CGPoint(x: size.width, y: size.height)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x * rhs.x, y: lhs.y * rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x / rhs.x, y: lhs.y / rhs.y)
    }

    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static prefix func - (point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }

    func isApproximatelyEqual(_ rhs: CGPoint) -> Bool {
        return x.isApproximatelyEqual(rhs.x) && y.isApproximatelyEqual(rhs.y)
    }

}

// MARK: Vector operations

extension CGPoint {

    /// The distance between two points
    func distance(_ secondPoint: CGPoint) -> CGFloat {
        let difference = self - secondPoint

        return difference.length
    }

    /// The distance squared is useful as it can be used to compare distance
    /// without the performance overhead of square rooting
    func distanceSquared(_ secondPoint: CGPoint) -> CGFloat {
        let difference = self - secondPoint

        return difference.lengthSquared
    }

    var length: CGFloat {
        return sqrt(lengthSquared)
    }

    /// Think of the lengthSquared as the first half of the pythagorean theorem: https://en.wikipedia.org/wiki/Pythagorean_theorem
    /// without the final square root. It's mostly used for vector maths, but can also
    /// be used to sort by distance without the performance overhead of square rooting
    var lengthSquared: CGFloat {
        return (x * x) + (y * y)
    }

    /// The dot product is a way of multiplying vectors together
    /// to get a scalar which represents the length of a vector,
    /// multipled by the length of the second vector in the direction of first vector
    /// The multiplication order isn't important.
    /// https://www.mathsisfun.com/algebra/vectors-dot-product.html
    func dotProduct(_ point: CGPoint) -> CGFloat {
        return (x * point.x) + (y * point.y)
    }

    /// Convert the vector to its unit length
    /// which means taking the direction of the vector
    /// scaled so that it has a length of 1
    func normalize() -> CGPoint {
        let length = self.length

        if length.isApproximatelyEqual(0) {
            return self
        } else {
            return CGPoint(x: (x / length), y: (y / length))
        }
    }

}
