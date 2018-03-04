//
//  FilterEffect.swift
//  PhotoEditor
//
//  Created by Harry Jordan 12/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

public enum FilterEffect: Int {
    // A FilterEffect represents a set of FilterDefinitions
    public static var visibleEffects = [autoEnhance, enhance]

    case autoEnhance
    case enhance

    public var name: String {
        switch self {
        case .autoEnhance:
            return "AutoEnhance"

        case .enhance:
            return "EnhanceV1"
        }
    }

    public var defaultValue: CGFloat {
        switch self {
        case .autoEnhance:
            return 1.0

        case .enhance:
            return 0.5
        }
    }

    public func filters(for effectAmount: CGFloat, autoEnhanceFilters: [FilterDefinition]) -> [FilterDefinition] {
        switch self {
        case .autoEnhance:
            let filters = autoEnhanceFilters.map { $0.interpolatedWithDefaultValue(effectAmount) }
            return filters

        case .enhance:
            // Create an effect which is linear up to one and then cubic after that (up to four)
            // When the thumb is in the center of the slider it represents a value of one
            let relativeAmount = effectAmount * 2
            let greatestAmount = max(relativeAmount, relativeAmount * relativeAmount)

            var filters: [FilterDefinition] = autoEnhanceFilters.map { (filter) -> FilterDefinition in
                switch filter {
                case .vibrance:
                    return filter.interpolatedWithDefaultValue(clamp(greatestAmount, between: 0, and: 2))

                case .toneCurve:
                    return filter.interpolatedWithDefaultValue(clamp(greatestAmount, between: 0, and: 1))

                case .dynamicRange:
                    return filter.interpolatedWithDefaultValue(clamp(greatestAmount, between: 0, and: 2))

                default:
                    return filter.interpolatedWithDefaultValue(greatestAmount)
                }
            }

            // Add additional vibrancy and a bit of darkness in the dark mid tones
            let squaredInterpolationOfSecondHalf = inverseLerp(greatestAmount, between: 1, and: 4)

            let toneCurve = FilterDefinition.toneCurve(p0: CGPoint(x: 0.0, y: 0.0),
                                                       p1: CGPoint(x: 0.25, y: 0.22),
                                                       p2: CGPoint(x: 0.5, y: 0.5),
                                                       p3: CGPoint(x: 0.75, y: 0.75),
                                                       p4: CGPoint(x: 1.0, y: 1.0))

            filters.append(contentsOf: [
                toneCurve.interpolatedWithDefaultValue(squaredInterpolationOfSecondHalf),
                FilterDefinition.vibrance(0.2).interpolatedWithDefaultValue(squaredInterpolationOfSecondHalf),
            ])

            return filters
        }
    }

}
