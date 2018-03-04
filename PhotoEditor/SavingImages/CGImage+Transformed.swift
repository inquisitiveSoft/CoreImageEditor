//
//  CGImage+Transformed.swift
//  PhotoEditor
//
//  Created by Harry Jordan 19/12/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit
import Accelerate
import CoreGraphics

enum CGImageTransformError: Error, LocalizedError {
    case vImageCouldntCreateInputBuffer(originalSize: CGSize)
    case vImageCouldntApplyTransform(transform: CGAffineTransform)
    case vImageCouldntCropAndScale(originlSize: CGSize, cropRect: CGRect, scaledSize: CGSize)
    case vImageCouldntCreateOutputCGImage

    var errorDescription: String? {
        let prefix = "CGImageTransformError: "

        switch self {
        case .vImageCouldntCreateInputBuffer(let originalSize):
            return prefix + "vImage couldn't create input buffer \(originalSize)"

        case .vImageCouldntApplyTransform(let transform):
            return prefix + "vImage couldn't apply transform \(transform.string)"

        case .vImageCouldntCropAndScale(let originlSize, let cropRect, let scaledSize):
            return prefix + "vImage couldn't crop and scale \(originlSize), \(cropRect), \(scaledSize)"

        case .vImageCouldntCreateOutputCGImage:
            return prefix + "vImage couldn't create output CGImage"
        }
    }
}

extension CGImage {

    func transformed(_ transform: CGAffineTransform, desiredAspectRatio: AspectRatio, scaledToFit sizeToFit: CGSize?) throws -> CGImage {
        // Ref: http://nshipster.com/image-resizing/
        let originalSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        let originalRect = CGRect(origin: .zero, size: originalSize)

        var canvasTransform = CGAffineTransform(translationX: originalRect.midX, y: originalRect.midY)

        // Scaling by -1 to flip the context so that transforms rotation works
        // in the correct direction and then repeating it, to return to the normal image space
        canvasTransform = canvasTransform.scaledBy(x: 1.0, y: -1.0)
        canvasTransform = transform.concatenating(canvasTransform)
        canvasTransform = canvasTransform.scaledBy(x: 1.0, y: -1.0)
        canvasTransform = canvasTransform.translatedBy(x: -originalRect.midX, y: -originalRect.midY)

        let originalWidth = Int(originalSize.width)
        let originalHeight = Int(originalSize.height)

        // Determine the crop factor
        let cropRect: CGRect
        let proposedCropRect = CGRect(aspectRatio: desiredAspectRatio, within: originalRect)

        if originalRect.contains(proposedCropRect) {
            cropRect = proposedCropRect
        } else {
            cropRect = originalRect
        }

        // Determine the final size of the image
        let scaledSize: CGSize

        if let sizeToFit = sizeToFit {
            scaledSize = floor(cropRect.size.scaledDownToFit(sizeToFit))
        } else {
            scaledSize = floor(cropRect.size)
        }

        let unmanagedColorSpace: Unmanaged<CGColorSpace>?

        if let colorSpace = colorSpace {
            unmanagedColorSpace = Unmanaged.passUnretained(colorSpace)
        } else {
            unmanagedColorSpace = nil
        }

        let bytesPerRow = self.bytesPerRow
        var pixelFormat = vImage_CGImageFormat(bitsPerComponent: UInt32(bitsPerComponent),
                                               bitsPerPixel: UInt32(bitsPerPixel),
                                               colorSpace: unmanagedColorSpace,
                                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                               version: 0,
                                               decode: nil,
                                               renderingIntent: .defaultIntent)

        // Create a source buffer
        var sourceBuffer = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &pixelFormat, nil, self, numericCast(kvImageNoFlags))

        guard error == kvImageNoError else {
            sourceBuffer.data.deallocate(bytes: Int(sourceBuffer.height) * bytesPerRow, alignedTo: 0)
            throw CGImageTransformError.vImageCouldntCreateInputBuffer(originalSize: originalSize)
        }

        // Apply the transform
        let transformedData = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * originalHeight)

        var transformedBuffer = vImage_Buffer(data: transformedData,
                                              height: vImagePixelCount(originalHeight),
                                              width: vImagePixelCount(originalWidth),
                                              rowBytes: bytesPerRow)

        var vTransform = vImage_CGAffineTransform(transform: canvasTransform)
        var backColor: Pixel_8 = Pixel_8()

        withUnsafePointer(to: &vTransform) { (vTransformPointer: UnsafePointer<vImage_CGAffineTransform>) in
            withUnsafePointer(to: &backColor) { (backColor: UnsafePointer<Pixel_8>) in
                error = vImageAffineWarpCG_ARGB8888(&sourceBuffer,
                                                    &transformedBuffer,
                                                    nil,
                                                    vTransformPointer,
                                                    backColor,
                                                    numericCast(kvImageHighQualityResampling | kvImageEdgeExtend))
            }
        }

        sourceBuffer.data.deallocate(bytes: Int(sourceBuffer.height) * bytesPerRow, alignedTo: 0)

        guard error == kvImageNoError else {
            transformedData.deallocate(capacity: bytesPerRow * originalHeight)
            throw CGImageTransformError.vImageCouldntApplyTransform(transform: canvasTransform)
        }

        // Crop & Scale the image
        let cropX = Int(cropRect.minX)
        let cropY = Int(cropRect.minY)
        let croppedWidth = Int(cropRect.width)
        let croppedHeight = Int(cropRect.height)

        let scaledWidth = Int(scaledSize.width)
        let scaledHeight = Int(scaledSize.height)

        // Advance to the position in the data of the target rects top left corner
        let bytesPerPixel = bitsPerPixel / 8
        let cropSourceData = transformedData.advanced(by: (cropY * bytesPerRow) + (cropX * bytesPerPixel))

        var cropSourceBuffer = vImage_Buffer(data: cropSourceData,
                                             height: vImagePixelCount(croppedHeight),
                                             width: vImagePixelCount(croppedWidth),
                                             rowBytes: bytesPerRow)

        let scaledAndCroppedDestinationData = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerPixel * scaledWidth * scaledHeight)

        var scaledAndCroppedBuffer = vImage_Buffer(data: scaledAndCroppedDestinationData,
                                                   height: vImagePixelCount(scaledHeight),
                                                   width: vImagePixelCount(scaledWidth),
                                                   rowBytes: bytesPerPixel * scaledWidth)

        error = vImageScale_ARGB8888(&cropSourceBuffer, &scaledAndCroppedBuffer, nil, numericCast(kvImageHighQualityResampling))
        transformedData.deallocate(capacity: bytesPerRow * originalHeight)

        guard error == kvImageNoError else {
            scaledAndCroppedDestinationData.deallocate(capacity: bytesPerPixel * scaledWidth * scaledHeight)
            throw CGImageTransformError.vImageCouldntCropAndScale(originlSize: originalSize, cropRect: cropRect, scaledSize: scaledSize)
        }

        var outputBuffer = scaledAndCroppedBuffer

        // Create the output CGImage from the outputBuffer vImage_Buffer
        let outputCGImage = vImageCreateCGImageFromBuffer(&outputBuffer,
                                                          &pixelFormat,
                                                          nil,
                                                          nil,
                                                          numericCast(kvImageNoFlags),
                                                          &error)?.takeRetainedValue()

        scaledAndCroppedDestinationData.deallocate(capacity: bytesPerPixel * scaledWidth * scaledHeight)

        guard error == kvImageNoError else {
            throw CGImageTransformError.vImageCouldntCreateOutputCGImage
        }

        if let outputCGImage = outputCGImage {
            return outputCGImage
        } else {
            throw CGImageTransformError.vImageCouldntCreateOutputCGImage
        }
    }

}

extension vImage_CGAffineTransform {

    init(transform t: CGAffineTransform) {
        // vImage_CGAffineTransform can either accept Floats of Doubles
        // When build for release it compiles both Double and Float variants
        //
        // Ideally this differenct would be detected by testing for VIMAGE_AFFINETRANSFORM_DOUBLE_IS_AVAILABLE
        // but I couldn't get it to compile, so have resorted to using an approach which uses generics
        // to infer input types of the vImage_CGAffineTransform function

        self = vImage_CGAffineTransform(a: t.a.converted(),
                                        b: t.b.converted(),
                                        c: t.c.converted(),
                                        d: t.d.converted(),
                                        tx: t.tx.converted(),
                                        ty: t.ty.converted())
    }

}

// Ref: http://foxinswift.com/2015/08/17/cast-free-arithmetic/
// Origin: https://github.com/Nadohs/Cast-Free-Arithmetic-in-Swift

private protocol FloatingPointConvertible {
    init(_ value: Float)
    init(_ value: Double)
    init(_ value: CGFloat)
}

extension Double: FloatingPointConvertible {}
extension Float: FloatingPointConvertible {}
extension CGFloat: FloatingPointConvertible {}

extension FloatingPointConvertible {

    fileprivate func converted<T: FloatingPointConvertible>() -> T {
        switch self {
        case let x as Float:
            return T(x)

        case let x as Double:
            return T(x)

        case let x as CGFloat:
            return T(x)

        default:
            fatalError("Unsupported FloatingPointConvertible type: \(self)")
        }
    }
}
