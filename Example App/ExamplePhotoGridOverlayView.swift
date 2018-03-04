//
//  ExamplePhotoGridOverlayView.swift
//  PhotoEditor
//
//  Created by Harry Jordan 10/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit
import PhotoEditor

final class ExamplePhotoGridOverlayView: UIView, CoreImageViewerLayout {

    var targetAspectRatio: AspectRatio = AspectRatio(width: 1.0, height: 1.0)

    var borderColor: UIColor = UIColor(white: 0.85, alpha: 1.0) {
        didSet {
            setNeedsDisplay()
        }
    }

    var gridLineColor: UIColor? = UIColor(white: 0.95, alpha: 0.65) {
        didSet {
            setNeedsDisplay()
        }
    }

    var maskColor: UIColor? = UIColor(white: 0.25, alpha: 0.65) {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0))

        backgroundColor = .clear
        layer.needsDisplayOnBoundsChange = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentEdgeInsets: UIEdgeInsets = .zero {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.translateBy(x: canvasOrigin.x, y: canvasOrigin.y)
        let centeredBounds = bounds.centered(on: .zero)
        let targetFrameRect = self.targetFrameRect.integral

        // Draw a mask
        if let maskColor = maskColor {
            context.saveGState()
            context.addRect(centeredBounds)
            context.addRect(targetFrameRect)
            context.clip(using: .evenOdd)

            context.setFillColor(maskColor.cgColor)
            context.fill(centeredBounds)

            context.restoreGState()
        }

        // Draw grid lines
        if let gridLineColor = gridLineColor {
            context.setLineWidth(0.5)
            context.setStrokeColor(gridLineColor.cgColor)

            let third = CGPoint(x: (targetFrameRect.width / 3), y: (targetFrameRect.height / 3))
            let firstThird = targetFrameRect.origin + third
            let secondThird = targetFrameRect.origin + third + third

            // Vertical grid lines
            context.strokeLineSegments(between: [
                CGPoint(x: firstThird.x, y: targetFrameRect.minY),
                CGPoint(x: firstThird.x, y: targetFrameRect.maxY),
            ])

            context.strokeLineSegments(between: [
                CGPoint(x: secondThird.x, y: targetFrameRect.minY),
                CGPoint(x: secondThird.x, y: targetFrameRect.maxY),
            ])

            // Horizontal grid lines
            context.strokeLineSegments(between: [
                CGPoint(x: targetFrameRect.minX, y: firstThird.y),
                CGPoint(x: targetFrameRect.maxX, y: firstThird.y),
            ])

            context.strokeLineSegments(between: [
                CGPoint(x: targetFrameRect.minX, y: secondThird.y),
                CGPoint(x: targetFrameRect.maxX, y: secondThird.y),
            ])
        }

        // Stroke the outline border
        context.setLineWidth(1.0)
        context.setStrokeColor(borderColor.cgColor)
        context.stroke(targetFrameRect)
    }

}
