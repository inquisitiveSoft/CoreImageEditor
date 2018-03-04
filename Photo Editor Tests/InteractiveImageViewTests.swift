//
//  InteractiveImageViewTests.swift
//  PhotoEditor
//
//  Created by Harry Jordan 10/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import XCTest
@testable import Photo_Editor_Example


class InteractiveImageViewTests: XCTestCase {
    var imageView: CoreImageView!

    override func setUp() {
        imageView = CoreImageView(frame: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 200.0))
    }


}

