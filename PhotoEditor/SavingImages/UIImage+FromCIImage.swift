//
//  UIImage+FromCIImage.swift
//  PhotoEditor
//
//  Created by Harry Jordan 19/12/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit
import CoreImage

enum CoreImageConversionError: Error, LocalizedError {
    case couldntCreateFilteredCGImage

    var errorDescription: String? {
        switch self {
        case .couldntCreateFilteredCGImage:
            return "CoreImageConversionError: Couldn't create filtered CGImage"
        }
    }
}

public extension UIImage {

    convenience init(ciImage inputImage: CIImage,
                     filters: [FilterDefinition] = [],
                     desiredAspectRatio: CGSize,
                     maximumDimensions: CGSize,
                     transform: CGAffineTransform = .identity) throws {
        // Make sure to return an output image in the RGB space
        let ciContext = CIContext(options: [
            kCIContextUseSoftwareRenderer: false,
            kCIContextOutputColorSpace: CGColorSpaceCreateDeviceRGB(),
        ])

        let filteredImage = inputImage.applying(filters: filters)

        guard let cgImage = ciContext.createCGImage(filteredImage, from: filteredImage.extent) else {
            throw CoreImageConversionError.couldntCreateFilteredCGImage
        }

        let transformedCGImage = try cgImage.transformed(transform,
                                                         desiredAspectRatio: desiredAspectRatio,
                                                         scaledToFit: maximumDimensions)

        self.init(cgImage: transformedCGImage)
    }

}

extension UIImageOrientation {

    var exifOrientation: Int32 {
        // Convert the UIImageOrientation to a kCGImagePropertyOrientation equivalent
        // Ref: https://developer.apple.com/documentation/imageio/kcgimagepropertyorientation
        switch self {
        case .up:
            return 1
        case .down:
            return 3
        case .left:
            return 8
        case .right:
            return 6
        case .upMirrored:
            return 2
        case .downMirrored:
            return 4
        case .leftMirrored:
            return 5
        case .rightMirrored:
            return 7
        }
    }

}
