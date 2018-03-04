//
//  CoreImageCanvasView.swift
//  PhotoEditor
//
//  Created by Harry Jordan 06/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit
import GLKit
import CoreImage

final class CoreImageCanvasView: GLKView {
    // CoreImageCanvasView draws a filtered CIImage using a CIContext within a GLKView (Open GL)

    var image: CIImage? {
        didSet {
            updateFilteredImage()
        }
    }

    var filters: [FilterDefinition] = [] {
        didSet {
            updateFilteredImage()
        }
    }

    // MARK: Appearance

    override var backgroundColor: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: Core Image internals

    private func updateFilteredImage() {
        guard let image = image else {
            self.filteredImage = nil
            return
        }

        let filters = self.filters

        DispatchQueue.global(qos: .default).async {
            let filteredImage = image.applying(filters: filters)

            DispatchQueue.main.async {
                self.filteredImage = filteredImage
            }
        }
    }

    private var filteredImage: CIImage? {
        didSet {
            setNeedsDisplay()
        }
    }

    private lazy var canvasContext: CIContext = {
        // A CIContext is relatively expensive so cache it for the lifetime of the view
        return CIContext(eaglContext: self.context)
    }()

    init() {
        // Since OpenGL 2.0 is supported back to the iPhone 3GS its safe to force unwrap here
        // Ref Apple Docs: 'Configuring OpenGL ES Contexts' and 'Device Compatibility Matrix'
        let eaglContext = EAGLContext(api: .openGLES2)!
        let placeholderRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)

        super.init(frame: placeholderRect, context: eaglContext)

        contentMode = .redraw
        contentScaleFactor = UIScreen.main.scale    // Can be multiplied  x2 for better scaling quality
    }

    override init(frame: CGRect) {
        fatalError("init(frame:) has not been implemented. Use init() instead.")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Use init() instead.")
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        if let backgroundColor = backgroundColor {
            drawBackground(backgroundColor)
        }

        if let filteredImage = filteredImage {
            let scale = CGAffineTransform(scaleX: contentScaleFactor, y: contentScaleFactor)
            let scaledBounds = bounds.applying(scale)

            canvasContext.draw(filteredImage, in: scaledBounds, from: filteredImage.extent)
        }
    }

    func drawBackground(_ color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            glClearColor(GLfloat(red), GLfloat(green), GLfloat(blue), GLfloat(alpha))
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }
    }

}
