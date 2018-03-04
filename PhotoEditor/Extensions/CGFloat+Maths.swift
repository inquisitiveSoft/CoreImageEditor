//
//  CGFloat+Maths.swift
//  PhotoEditor
//
//  Created by Harry Jordan 19/12/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

extension CGFloat {

    public func isApproximatelyEqual(_ rhs: CGFloat, epsilon: CGFloat = 0.01) -> Bool {
        return fabs(self - rhs) < epsilon
    }

}
