//
//  CIImage+ApplyingFilterDefinitions.swift
//  PhotoEditor
//
//  Created by Harry Jordan 20/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import Foundation
import CoreImage

extension CIImage {

    func applying(filters filterDefinitions: [FilterDefinition]) -> CIImage {
        if filterDefinitions.isEmpty {
            return self
        }

        // Create a chain of filters
        let filters = filterDefinitions.flatMap { CIFilter($0) }

        // Using the previous image as the input to the next
        let output = filters.reduce(self) { (currentImage, filter) -> CIImage? in
            filter.setValue(currentImage, forKey: kCIInputImageKey)
            return filter.outputImage
        }

        return output ?? self
    }

}
