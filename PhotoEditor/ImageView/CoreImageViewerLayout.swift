//
//  CoreImageViewerLayout.swift
//  PhotoEditor
//
//  Created by Harry Jordan 10/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit

public protocol CoreImageViewerLayout {
    // This protocol is inherited by CoreImageView and any overlay view
    // It offers shared extensions for determining the canvas's target rect

    var bounds: CGRect { get }

    var targetAspectRatio: AspectRatio { get set }
    var contentEdgeInsets: UIEdgeInsets { get set }
}

extension CoreImageViewerLayout {

    // MARK: Calculate canvas layout properties

    var contentInsetRect: CGRect {
        let contentInsetRect = UIEdgeInsetsInsetRect(bounds, contentEdgeInsets)

        return contentInsetRect
    }

    public var canvasOrigin: CGPoint {
        return contentInsetRect.center
    }

    public var targetFrameRect: CGRect {
        // In canvas coordinates
        let targetFrameSize = targetAspectRatio.scaledToFit(contentInsetRect.size)

        return CGRect(origin: .zero, size: targetFrameSize).centered(on: .zero)
    }

    public func initialSize(for imageOfSize: CGSize) -> CGSize {
        return imageOfSize.scaledToFill(targetFrameRect.size)
    }

    func contentInsetRect(within boundingRect: CGRect) -> CGRect {
        return UIEdgeInsetsInsetRect(boundingRect, contentEdgeInsets)
    }

    func canvasOrigin(within boundingRect: CGRect) -> CGPoint {
        return contentInsetRect(within: boundingRect).center
    }

    func targetFrameRect(within boundingRect: CGRect) -> CGRect {
        // In canvas coordinates
        let targetFrameSize = targetAspectRatio.scaledToFit(contentInsetRect(within: boundingRect).size)

        return CGRect(origin: .zero, size: targetFrameSize).centered(on: .zero)
    }

    func initialSize(for imageOfSize: CGSize, within boundingRect: CGRect) -> CGSize {
        return imageOfSize.scaledToFill(targetFrameRect(within: boundingRect).size)
    }

}
