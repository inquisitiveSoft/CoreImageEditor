//
//  CIImageUnitTests.swift
//  PhotoEditor
//
//  Created by Harry Jordan 18/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import XCTest
import CoreImage
import CoreGraphics
import UIKit

@testable import Photo_Editor_Example

class CIImageUnitTests: XCTestCase {

    func testImageDownScalingToFitWithATransform() {
        let inputImage = CIImage(cgImage: cgImage(named: "001")!)
        let desiredAspectRatio = AspectRatio(width: 3, height: 2)
        let maximumDimensions = CGSize(width: 500.0, height: 500.0)

        let image = try! UIImage(ciImage: inputImage, filters: [], desiredAspectRatio: desiredAspectRatio, maximumDimensions: maximumDimensions)
        XCTAssertNotNil(image)

        let resultingImageRect = CGRect(origin: .zero, size: image.size)
        XCTAssertEqual(resultingImageRect.width, maximumDimensions.width, accuracy: 0.000001)
    }
    

    func cgImage(named name: String) -> CGImage? {
        return UIImage(named: name)?.cgImage
    }

}
