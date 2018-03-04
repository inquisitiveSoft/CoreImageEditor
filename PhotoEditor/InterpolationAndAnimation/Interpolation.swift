//
//  Interpolation.swift
//  PhotoEditor
//
//  Created by Harry Jordan 27/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import Foundation
import CoreGraphics

// MARK: Interpolation

typealias Interpolatable = Summable & Subtractable & ScalarMultipliable

// Reference for easing functions: http://gizma.com/easing/

func lerp<T: Interpolatable>(_ first: T, _ second: T, _ weighting: CGFloat) -> T {
    let difference = second - first
    return first + (difference * weighting)
}

// MARK: Quadratic easing

func quadraticEaseIn<T: Interpolatable>(_ first: T, _ second: T, _ weighting: CGFloat) -> T {
    let difference = second - first
    return first + (difference * weighting * weighting)
}

func quadraticEaseOut<T: Interpolatable>(_ first: T, _ second: T, _ weighting: CGFloat) -> T {
    let difference = second - first
    return first + (-difference * weighting * (weighting - 2))
}

func quadraticEaseInOut<T: Interpolatable>(_ first: T, _ second: T, _ weighting: CGFloat) -> T {
    let difference = second - first
    let t1 = weighting * 2      // Weighting across the first half of the curve

    if t1 < 1 {
        return first + (difference * 0.5 * t1 * t1)
    }

    let t2 = t1 - 1             // Weighting across the second half of the curve
    return first + (-difference * 0.5 * ((t2 * (t2 - 2)) - 1))
}

protocol InverseInterpolatable: Comparable, Subtractable, Dividable {
    static var zero: Self { get }
    func isApproximatelyEqual(_ otherValue: Self) -> Bool
}

func inverseLerp<T: InverseInterpolatable>(_ value: T, between first: T, and second: T) -> T {
    let clampedValue = clamp(value, between: first, and: second)
    let position = clampedValue - first
    let length = second - first

    if position.isApproximatelyEqual(T.zero) || length.isApproximatelyEqual(T.zero) {
        return T.zero
    } else {
        let normalized = position / length
        return normalized
    }
}

protocol Summable {
    static func + (lhs: Self, rhs: Self) -> Self
}

protocol Subtractable {
    static func - (lhs: Self, rhs: Self) -> Self
    static prefix func - (value: Self) -> Self
}

protocol Dividable {
    static func / (lhs: Self, rhs: Self) -> Self
}

protocol ScalarMultipliable {
    static func * (lhs: Self, rhs: CGFloat) -> Self
}

// MARK: Declaring Conformance to protocols

extension CGFloat: Interpolatable {}
extension CGPoint: Interpolatable {}

extension CGFloat: InverseInterpolatable {
    static var zero: CGFloat {
        return 0.0
    }

    func isApproximatelyEqual(_ otherValue: CGFloat) -> Bool {
        return isApproximatelyEqual(otherValue, epsilon: 0.01)
    }
}

// MARK: Clamping values

public func clamp<T: Comparable>(_ originalValue: T, between first: T, and second: T) -> T {
    let (greater, lesser) = (first > second) ? (first, second) : (second, first)

    return max(min(originalValue, greater), lesser)
}

