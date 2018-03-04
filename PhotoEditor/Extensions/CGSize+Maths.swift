//
//  CGSize+Maths.swift
//  PhotoEditor
//
//  Created by Harry Jordan 23/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

public func floor(_ size: CGSize) -> CGSize {
    return CGSize(width: floor(size.width), height: floor(size.height))
}

public extension CGSize {

    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func - (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width * rhs.width, height: lhs.height * rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    static func / (lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width / rhs.width, height: lhs.height / rhs.height)
    }

    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }

}

// MARK: Calculating a rectangle that satisfies a desired aspect ratio within a bounding rect

extension CGSize {

    func scaledToFill(_ boundingSize: CGSize) -> CGSize {
        let aspectRatio = self
        let widthScaleFactor = boundingSize.width / aspectRatio.width
        let heightScaleFactor = boundingSize.height / aspectRatio.height

        var resultingSize = boundingSize

        if widthScaleFactor > heightScaleFactor {
            resultingSize.height = aspectRatio.height * widthScaleFactor
        } else {
            resultingSize.width = aspectRatio.width * heightScaleFactor
        }

        return resultingSize
    }

    func scaledToFit(_ boundingSize: CGSize) -> CGSize {
        let aspectRatio = self
        let widthScaleFactor = boundingSize.width / aspectRatio.width
        let heightScaleFactor = boundingSize.height / aspectRatio.height

        var resultingSize = boundingSize

        if widthScaleFactor < heightScaleFactor {
            resultingSize.height = aspectRatio.height * widthScaleFactor
        } else {
            resultingSize.width = aspectRatio.width * heightScaleFactor
        }

        return resultingSize
    }

    func scaledDownToFit(_ boundingSize: CGSize) -> CGSize {
        let aspectRatio = self
        let widthScaleFactor = boundingSize.width / aspectRatio.width
        let heightScaleFactor = boundingSize.height / aspectRatio.height

        var resultingSize = boundingSize

        if widthScaleFactor < heightScaleFactor {
            if widthScaleFactor >= 1.0 {
                resultingSize = self
            } else {
                resultingSize.height = aspectRatio.height * widthScaleFactor
            }
        } else {
            if heightScaleFactor >= 1.0 {
                resultingSize = self
            } else {
                resultingSize.width = aspectRatio.width * heightScaleFactor
            }
        }

        return resultingSize
    }

    func scaleToFill(_ targetSize: CGSize) -> CGFloat {
        let widthScaleFactor = targetSize.width / self.width
        let heightScaleFactor = targetSize.height / self.height

        return max(widthScaleFactor, heightScaleFactor)
    }

    func scaleToFit(_ targetSize: CGSize) -> CGFloat {
        let widthScaleFactor = targetSize.width / self.width
        let heightScaleFactor = targetSize.height / self.height

        return min(widthScaleFactor, heightScaleFactor)
    }

}
