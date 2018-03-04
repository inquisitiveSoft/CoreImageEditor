//
//  FilterDefinition.swift
//  PhotoEditor
//
//  Created by Harry Jordan 09/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics
import CoreImage

private let CIAffineTransform = "CIAffineTransform"
private let CILanczosScaleTransform = "CILanczosScaleTransform"
private let CICrop = "CICrop"
private let CIExposureAdjust = "CIExposureAdjust"
private let CIVibrance = "CIVibrance"
private let CIColorControls = "CIColorControls"
private let CIToneCurve = "CIToneCurve"
private let CIHighlightShadowAdjust = "CIHighlightShadowAdjust"
private let CIGaussianBlur = "CIGaussianBlur"
private let CIAffineClamp = "CIAffineClamp"

public enum FilterDefinition: Equatable {
    // A FilterDefinition is a simple recipe for a CIFilter
    // which allows for easy interpolation and avoids the
    // proliferation of string constants
    case exposure(CGFloat)
    case vibrance(CGFloat)
    case contrast(CGFloat)
    case brightness(CGFloat)
    case toneCurve(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, p4: CGPoint)
    case dynamicRange(highlights: CGFloat, shadows: CGFloat, radius: CGFloat)
    case gaussianBlur(CGFloat)

    var name: String {
        switch self {
        case .contrast:
            return "CIContrast"

        case .brightness:
            return "CIBrightness"

        default:
            return self.className
        }
    }

    fileprivate var className: String {
        switch self {
        case .exposure:
            return CIExposureAdjust

        case .vibrance:
            return CIVibrance

        case .contrast:
            return CIColorControls

        case .brightness:
            return CIColorControls

        case .toneCurve:
            return CIToneCurve

        case .dynamicRange:
            return CIHighlightShadowAdjust

        case .gaussianBlur:
            return CIGaussianBlur
        }
    }

    var identity: FilterDefinition {
        // Returns a version of the filter which would have no effect on the image
        switch self {
        case .vibrance:
            return .vibrance(0.0)

        case .contrast:
            return .contrast(1.0)

        case .brightness:
            return .brightness(0.0)

        case .dynamicRange:
            return .dynamicRange(highlights: 1.0, shadows: 0.0, radius: 0.0)

        case .toneCurve:
            return .toneCurve(p0: CGPoint(x: 0.0, y: 0.0),
                              p1: CGPoint(x: 0.25, y: 0.25),
                              p2: CGPoint(x: 0.5, y: 0.5),
                              p3: CGPoint(x: 0.75, y: 0.75),
                              p4: CGPoint(x: 1.0, y: 1.0))

        case .exposure:
            return .exposure(1.0)

        case .gaussianBlur:
            return .gaussianBlur(0.0)
        }
    }

    func interpolatedWithDefaultValue(_ weighting: CGFloat) -> FilterDefinition {
        return self.identity.interpolated(with: self, by: weighting)
    }

    func interpolated(with matchingFilter: FilterDefinition, by weighting: CGFloat) -> FilterDefinition {
        switch (self, matchingFilter) {
        case (.vibrance(let firstVibrance), .vibrance(let secondVibrance)):
            return .vibrance(lerp(firstVibrance, secondVibrance, weighting))

        case (.contrast(let firstContrast), .contrast(let secondContrast)):
            return .contrast(lerp(firstContrast, secondContrast, weighting))

        case (.brightness(let firstBrightness), .contrast(let secondBrightness)):
            return .brightness(lerp(firstBrightness, secondBrightness, weighting))

        case (.dynamicRange(let firstHighlights, let firstShadows, let firstRadius),
              .dynamicRange(let secondHighlights, let secondShadows, let secondRadius)):

            return .dynamicRange(highlights: lerp(firstHighlights, secondHighlights, weighting),
                                 shadows: lerp(firstShadows, secondShadows, weighting),
                                 radius: lerp(firstRadius, secondRadius, weighting))

        case (.toneCurve(let fp0, let fp1, let fp2, let fp3, let fp4),
              .toneCurve(let sp0, let sp1, let sp2, let sp3, let sp4)):

            return .toneCurve(p0: lerp(fp0, sp0, weighting),
                              p1: lerp(fp1, sp1, weighting),
                              p2: lerp(fp2, sp2, weighting),
                              p3: lerp(fp3, sp3, weighting),
                              p4: lerp(fp4, sp4, weighting))

        default:
            print("Trying to interpolate incompatible types: \(self) - \(matchingFilter)")
            return self
        }
    }

    init?(from filter: CIFilter) {
        // Used to extract values from the Auto-Enhance filters
        // Currently not translating CIFaceBalance or CIRedEyeCorrection

        switch filter.name {
        case CIVibrance:
            guard let amount = filter.value(forKey: "inputAmount") as? CGFloat else { return nil }
            self = .vibrance(amount)

        case CIHighlightShadowAdjust:
            guard let highlightAmount = filter.value(forKey: "inputHighlightAmount") as? CGFloat,
                let shadowAmount = filter.value(forKey: "inputShadowAmount") as? CGFloat,
                let radius = filter.value(forKey: kCIInputRadiusKey) as? CGFloat else { return nil }

            self = .dynamicRange(highlights: highlightAmount, shadows: shadowAmount, radius: radius)

        case CIToneCurve:
            guard let p0 = filter.value(forKey: "inputPoint0") as? CIVector,
                let p1 = filter.value(forKey: "inputPoint1") as? CIVector,
                let p2 = filter.value(forKey: "inputPoint2") as? CIVector,
                let p3 = filter.value(forKey: "inputPoint3") as? CIVector,
                let p4 = filter.value(forKey: "inputPoint4") as? CIVector else { return nil }

            self = .toneCurve(p0: p0.cgPointValue, p1: p1.cgPointValue, p2: p2.cgPointValue, p3: p3.cgPointValue, p4: p4.cgPointValue)

        default:
            return nil
        }
    }

    fileprivate var properties: [String: Any] {
        switch self {
        case .exposure(let exposure):
            return [
                kCIInputEVKey: exposure,
            ]

        case .vibrance(let vibrance):
            return [
                "inputAmount": vibrance,
            ]

        case .contrast(let contrast):
            return [
                "inputContrast": contrast,
            ]

        case .brightness(let brightness):
            return [
                "inputBrightness": brightness,
            ]

        case .dynamicRange(let highlightAmount, let shadowAmount, let radius):
            return [
                "inputHighlightAmount": highlightAmount,
                "inputShadowAmount": shadowAmount,
                "inputRadius": radius,
                kCIInputVersionKey: 0, // This is necessary to replicate Apples Auto-Enhance filter
            ]

        case .toneCurve(let p0, let p1, let p2, let p3, let p4):
            return [
                "inputPoint0": CIVector(cgPoint: p0),
                "inputPoint1": CIVector(cgPoint: p1),
                "inputPoint2": CIVector(cgPoint: p2),
                "inputPoint3": CIVector(cgPoint: p3),
                "inputPoint4": CIVector(cgPoint: p4),
            ]

        default:
            return [:]
        }
    }

    public static func == (lhs: FilterDefinition, rhs: FilterDefinition) -> Bool {
        switch (lhs, rhs) {
        case (.exposure(let lhsExposure), .exposure(let rhsExposure)):
            return lhsExposure.isApproximatelyEqual(rhsExposure)

        case (.vibrance(let lhsVibrance), .vibrance(let rhsVibrance)):
            return lhsVibrance.isApproximatelyEqual(rhsVibrance)

        case (.contrast(let lhsContrast), .contrast(let rhsContrast)):
            return lhsContrast.isApproximatelyEqual(rhsContrast)

        case (.brightness(let lhsBrightness), .brightness(let rhsBrightness)):
            return lhsBrightness.isApproximatelyEqual(rhsBrightness)

        case (.toneCurve(let lp0, let lp1, let lp2, let lp3, let lp4), .toneCurve(let rp0, let rp1, let rp2, let rp3, let rp4)):
            return lp0.isApproximatelyEqual(rp0) &&
                lp1.isApproximatelyEqual(rp1) &&
                lp2.isApproximatelyEqual(rp2) &&
                lp3.isApproximatelyEqual(rp3) &&
                lp4.isApproximatelyEqual(rp4)

        case (.dynamicRange(let lhsHighlights, let lhsShadows, let lhsRadius),
              .dynamicRange(let rhsHighlights, let rhsShadows, let rhsRadius)):
            return lhsHighlights.isApproximatelyEqual(rhsHighlights) &&
                    lhsShadows.isApproximatelyEqual(rhsShadows) &&
                    lhsRadius.isApproximatelyEqual(rhsRadius)

        case (.gaussianBlur(let lhsGaussian), .gaussianBlur(let rhsGaussian)):
            return lhsGaussian.isApproximatelyEqual(rhsGaussian)

        default:
            return false
        }
    }
}

extension CIImage {

    public func autoEnhanceFilterDefinitions() -> [FilterDefinition] {
        // Convert CIFilter back into FilterDefinition's which are easy to interpolate
        let filters = self.autoAdjustmentFilters(options: [
            kCIImageAutoAdjustRedEye: false,
            kCIImageAutoAdjustFeatures: [],
        ])

        return filters.flatMap { FilterDefinition(from: $0) }
    }

}

extension CIFilter {

    public convenience init?(_ filterDefinition: FilterDefinition) {
        self.init(name: filterDefinition.className)

        applyProperties(filterDefinition)
    }

    public func applyProperties(_ filterDefinition: FilterDefinition) {
        setValuesForKeys(filterDefinition.properties)
    }

}
