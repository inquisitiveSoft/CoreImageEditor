//
//  CGImage+Scaled.swift
//  PhotoEditor
//
//  Created by Harry Jordan 19/12/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import Foundation
import CoreGraphics

enum CGImageScalingError: Error, LocalizedError {
    case requiresCGImageBasedUIImage
    case unableToCreateCGContext
    case unableToOutputImage

    var errorDescription: String? {
        let prefix = "CGImageScalingError: "

        switch self {
        case .requiresCGImageBasedUIImage:
            return prefix + "requires CGImage based UIImage"

        case .unableToCreateCGContext:
            return prefix + "Unable to create CGContext"

        case .unableToOutputImage:
            return prefix + "Unable to output image"
        }
    }
}

extension CGImage {

    func scaledBySteps(toFit targetSize: CGSize) throws -> CGImage {
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))

        switch size.scaledBySteps(toFit: targetSize) {
        case .needsScaling(let destinationSize):
            return try self.scaled(toFit: destinationSize)

        case .none:
            return self
        }
    }

    func scaled(toFit destinationSize: CGSize) throws -> CGImage {
        // Ref: http://nshipster.com/image-resizing/
        // This is different from CGImage+Transformed as it uses a CGContext.draw approach
        // rather than CoreImage / vImage scaling as it isn't bound by GPU limitations
        // so can scale massive images fairly efficiently
        let colorspace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(data: nil,
                                      width: Int(destinationSize.width),
                                      height: Int(destinationSize.height),
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorspace,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            throw CGImageScalingError.unableToCreateCGContext
        }

        context.interpolationQuality = .high
        context.draw(self, in: CGRect(origin: .zero, size: destinationSize))

        if let scaledCGImage = context.makeImage() {
            return scaledCGImage
        } else {
            throw CGImageScalingError.unableToOutputImage
        }
    }

}

internal extension CGSize {
    // Internal for testing purposes

    internal enum SteppedScaleResult: Equatable {
        case needsScaling(CGSize)
        case none

        static func == (lhs: SteppedScaleResult, rhs: SteppedScaleResult) -> Bool {
            switch (lhs, rhs) {
            case (.needsScaling(let leftSize), .needsScaling(let rightSize)):
                return leftSize == rightSize

            case (.none, .none):
                return true

            default:
                return false
            }
        }
    }

    /// The purpose of this stepping scale is mainly to avoid scaling by amounts close to the original
    /// Scaling an image by 99% introduces a lot more blurring, than say scaling by 75%
    ///
    /// This function calculates a suitable image scale, by halving the image size
    /// until it fits withing the targetSize. If the halved size is less than 25% (or other tolerance)
    /// of the targetSize, then the image is scaled to fit the threshold size (by default 80% of the target)
    internal func scaledBySteps(toFit targetSize: CGSize, tolerance scaleTolerance: CGFloat = 0.25) -> SteppedScaleResult {
        if (width <= targetSize.width) && (height <= targetSize.height) {
            return .none
        }

        var scale: CGFloat = 1.0
        var adaptedSize = self

        let toleranceScale = 1 - scaleTolerance
        let thresholdSize = CGSize(width: targetSize.width * toleranceScale, height: targetSize.width * toleranceScale)

        while (adaptedSize.width > targetSize.width) || (adaptedSize.height > targetSize.height) {
            scale *= 0.5
            adaptedSize = CGSize(width: self.width * scale, height: self.width * scale)

            // Ensure that an image is within a tolerance of the target size
            if (adaptedSize.width < thresholdSize.width) && (adaptedSize.height < thresholdSize.height) {
                return .needsScaling(self.scaledDownToFit(thresholdSize))
            }
        }

        return .needsScaling(floor(adaptedSize))
    }

}
