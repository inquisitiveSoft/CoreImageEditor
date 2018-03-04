//
//  CoreImageView.swift
//  PhotoEditor
//
//  Created by Harry Jordan 18/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import UIKit
import CoreImage

@objc public protocol CoreImageViewDelegate: NSObjectProtocol {
    @objc optional func willUpdateTransform(for imageView: CoreImageView)
    @objc optional func didUpdateTransform(for imageView: CoreImageView)
}

public enum ImageViewerConstraintMode {
    case unconstrained

    /// The image will be constrained to always appear within the target rect
    case continuous

    /// The image can be dragged, zoomed, or rotated outside of the target rect,
    /// when the gesture finishes, the image will animate to be within the target rect
    case afterGesturesFinish
}

public final class CoreImageView: UIView, CoreImageViewerLayout {

    public weak var delegate: CoreImageViewDelegate?

    // MARK: Image properties

    public func setImage(_ image: CIImage?, transform: CGAffineTransform = .identity) {
        self.image = image
        canvasView.image = image
        initialImageTransform = transform
        currentRotationOperation = nil
        canvasTransform = .identity

        setNeedsLayout()
    }

    private(set) var image: CIImage?

    public var filters: [FilterDefinition] {
        set {
            canvasView.filters = newValue
        }
        get {
            return canvasView.filters
        }
    }

    public var isEnabled: Bool = true

    // MARK: Customizing interactions

    public var constraintMode: ImageViewerConstraintMode = .afterGesturesFinish

    public var maximumScale: CGFloat = 3.0

    // MARK: Properties exposed for logging

    public var rotationStep: Int {
        return currentRotationOperation?.rotationSteps ?? 0
    }

    // MARK: Appearance

    public var targetAspectRatio: AspectRatio = AspectRatio(width: 1, height: 1) {
        didSet {
            if var overlayView = overlayView as? CoreImageViewerLayout {
                overlayView.targetAspectRatio = targetAspectRatio
            }
        }
    }

    public var contentEdgeInsets: UIEdgeInsets = .zero {
        didSet {
            if var overlayView = overlayView as? CoreImageViewerLayout {
                overlayView.contentEdgeInsets = contentEdgeInsets
            }

            setNeedsLayout()
        }
    }

    public override var backgroundColor: UIColor? {
        didSet {
            canvasView.backgroundColor = backgroundColor
        }
    }

    public var borderColor: UIColor = .white {
        didSet {
            setNeedsDisplay()
        }
    }

    fileprivate(set) var canvasTransform: CGAffineTransform {
        set {
            canvasView.layer.transform = CATransform3DMakeAffineTransform(newValue)
        }

        get {
            let t = canvasView.layer.transform
            let transform = CGAffineTransform(a: t.m11, b: t.m12, c: t.m21, d: t.m22, tx: t.m41, ty: t.m42)
            return transform
        }
    }

    private var initialImageTransform: CGAffineTransform?

    public var imageTransform: CGAffineTransform {
        return imageTransform(within: bounds)
    }

    fileprivate var currentRotationOperation: RotationOperation?

    // MARK: Canvas view related properties

    private lazy var canvasView: CoreImageCanvasView = {
        let canvasView = CoreImageCanvasView()

        // This view is being positioned manually using frames
        // it will have the same bounds as the image, scaled to fill the target area
        canvasView.translatesAutoresizingMaskIntoConstraints = true

        return canvasView
    }()

    public var overlayView: UIView? {
        willSet {
            // Remove any existing overlay view
            overlayView?.removeFromSuperview()
            overlayViewConstraints = []
        }

        didSet {
            // Insert the new overlay view
            if let overlayView = overlayView {
                assert(overlayView.superview == nil,
                       "\(self) Attempting to set an overlay view which has already been inserted in the view hierarchy")

                if var overlayView = overlayView as? CoreImageViewerLayout {
                    overlayView.targetAspectRatio = targetAspectRatio
                    overlayView.contentEdgeInsets = contentEdgeInsets
                }

                overlayView.translatesAutoresizingMaskIntoConstraints = false

                if canvasView.superview == self {
                    insertSubview(overlayView, aboveSubview: canvasView)
                } else {
                    addSubview(overlayView)
                }

                setNeedsUpdateConstraints()
            }
        }
    }

    fileprivate var overlayViewConstraints: [NSLayoutConstraint] = []

    // MARK: Gesture related properties
    fileprivate var hasSetupGestureRecognizers = false
    fileprivate var panGestureRecognizer: UIPanGestureRecognizer?
    fileprivate var pinchGestureRecognizer: UIPinchGestureRecognizer?
    fileprivate var rotationGestureRecognizer: UIRotationGestureRecognizer?

    /// Used to determine when all touches have ended
    fileprivate var activeScaleOrRotationGestureRecognizers: Set<UIGestureRecognizer> = Set()

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()

        if superview != nil {
            setup()
        }
    }

    fileprivate func setup() {
        clipsToBounds = true

        if canvasView.superview == nil {
            if let overlayView = overlayView, overlayView.superview != nil {
                insertSubview(canvasView, belowSubview: overlayView)
            } else {
                addSubview(canvasView)
            }
        }

        setupGestureRecognizers()
        resetTransform(animated: false)
    }

    public override func updateConstraints() {
        super.updateConstraints()

        if let overlayView = overlayView, overlayViewConstraints.isEmpty {
            overlayViewConstraints = [
                overlayView.topAnchor.constraint(equalTo: topAnchor),
                overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),
                overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
                overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            ]

            NSLayoutConstraint.activate(overlayViewConstraints)
        }
    }

    private var existingBounds: CGRect = .zero

    public override func layoutSubviews() {
        super.layoutSubviews()

        viewWillTransition(from: existingBounds, to: bounds)
        existingBounds = bounds
    }

    private func viewWillTransition(from existingBounds: CGRect, to boundingRect: CGRect) {
        guard let image = image else { return }

        // Setting the canvas's frame manually to the size of the image,
        // scaled to fill the target rect. The idea is that an identity transform
        // will always fill the target rect perfectly
        let targetFrameRect = self.targetFrameRect(within: boundingRect)
        var frameRect = CGRect(origin: .zero, size: image.extent.size.scaledToFill(targetFrameRect.size))
        frameRect.center = bounds.center
        canvasView.frame = frameRect
        canvasTransform = .identity

        if targetFrameRect.size.width > 0.0 {
            // Set the image transform when the view on the first layout or if the views bounds have changed
            let imageTransform: CGAffineTransform

            if let initialImageTransform = initialImageTransform {
                imageTransform = initialImageTransform
                self.initialImageTransform = nil
            } else {
                imageTransform = self.imageTransform(within: existingBounds)
            }

            setImageTransform(imageTransform, for: image, within: boundingRect)
        }
    }

    private func setImageTransform(_ initialTransform: CGAffineTransform, for image: CIImage, within boundingRect: CGRect) {
        // Convert the translations from image into view space
        let baseScale = image.extent.size.scaleToFill(targetFrameRect(within: boundingRect).size)
        var initialCanvasTransform = initialTransform
        initialCanvasTransform.tx *= baseScale
        initialCanvasTransform.ty *= baseScale

        setCanvasTransform(initialCanvasTransform, validate: true, animated: false)
    }

    func imageTransform(within boundingRect: CGRect) -> CGAffineTransform {
        guard let image = image else {
            return .identity
        }

        // Convert the translations from view into image space
        let targetFrameRect = self.targetFrameRect(within: boundingRect)
        let invertedBaseScale = 1 / image.extent.size.scaleToFill(targetFrameRect.size)
        let initialSize = self.initialSize(for: image.extent.size, within: boundingRect)
        let initialImageRect = CGRect(origin: .zero, size: initialSize).centered(on: .zero)

        var transform = validTransform(from: canvasTransform,
                                       originalRect: initialImageRect,
                                       within: targetFrameRect,
                                       allowScaling: true)

        transform.tx *= invertedBaseScale
        transform.ty *= invertedBaseScale

        return transform
    }

    // MARK: Changing the current transform

    public func resetTransform(animated: Bool) {
        setCanvasTransform(.identity, validate: false, notifying: false, animated: animated)
        currentRotationOperation = nil
    }

    public func rotateClockwise() {
        let origin = CGPoint.zero.applying(canvasTransform.inverted())
        var rotationOperation = currentRotationOperation ?? RotationOperation(transform: canvasTransform, origin: origin)
        rotationOperation = rotationOperation.incrementingRotation
        currentRotationOperation = rotationOperation
        hasBeenRotated90 = rotationOperation.rotationSteps != 0

        applyRotationOperation(rotationOperation)
    }

    public func rotateCounterClockwise() {
        let origin = CGPoint.zero.applying(canvasTransform.inverted())
        var rotationOperation = currentRotationOperation ?? RotationOperation(transform: canvasTransform, origin: origin)
        rotationOperation = rotationOperation.decrementingRotation
        currentRotationOperation = rotationOperation
        hasBeenRotated90 = rotationOperation.rotationSteps != 0

        applyRotationOperation(rotationOperation)
    }

    public func rotate(_ rotation: CGFloat, animated: Bool) {
        let origin = CGPoint.zero.applying(canvasTransform.inverted())
        var rotationOperation = currentRotationOperation ?? RotationOperation(transform: canvasTransform, origin: origin)
        rotationOperation = rotationOperation.withAdjustmentRotation(rotation)
        currentRotationOperation = rotationOperation
        hasBeenRotatedUsingControl = true

        applyRotationOperation(rotationOperation, animated: animated)
    }

    fileprivate func applyRotationOperation(_ rotationOperation: RotationOperation, animated: Bool = true) {
        setCanvasTransform(rotationOperation.rotatedTransform, validate: true, notifying: false, animated: animated)
    }

    // MARK: Applying changes to transforms

    fileprivate func setCanvasTransform(_ newCanvasTransform: CGAffineTransform,
                                        validate shouldValidate: Bool,
                                        allowScaling: Bool = true,
                                        notifying: Bool = false,
                                        animated: Bool) {
        guard let image = image else { return }

        let initialImageRect = CGRect(origin: .zero, size: initialSize(for: image.extent.size)).centered(on: .zero)
        var newCanvasTransform = newCanvasTransform

        if shouldValidate {
            let validatedCanvasTransform = validTransform(from: newCanvasTransform,
                                                          originalRect: initialImageRect,
                                                          within: targetFrameRect,
                                                          allowScaling: allowScaling)

            newCanvasTransform = validatedCanvasTransform
        }

        // Only notify the delegate about a change to the transform
        // if the change was triggered by a direct user interaction
        if notifying {
            delegate?.willUpdateTransform?(for: self)
        }

        let didFinishSettingTransform = { (finished: Bool) in
            if finished && notifying {
                self.delegate?.didUpdateTransform?(for: self)
            }
        }

        if animated {
            // CATransaction and CABasicAnimation work, where UIView animation
            // had an odd bug when swiping when rotated by ±90 or 180 degrees
            CATransaction.begin()

            let animation = CABasicAnimation(keyPath: "transform")
            animation.duration = 0.2
            animation.fromValue = CATransform3DMakeAffineTransform(canvasTransform)
            animation.toValue = CATransform3DMakeAffineTransform(newCanvasTransform)
            animation.isRemovedOnCompletion = true
            canvasView.layer.add(animation, forKey: "transform")

            // Set the final resting point of the animation
            self.canvasTransform = newCanvasTransform

            CATransaction.setCompletionBlock {
                didFinishSettingTransform(true)
            }

            CATransaction.commit()
        } else {
            self.canvasTransform = newCanvasTransform
            didFinishSettingTransform(true)
        }
    }

    fileprivate func validate(_ originalRect: CGRect, transformedBy transform: CGAffineTransform, isWithin targetFrame: CGRect) -> Bool {
        let transformedRect = TransformableRect(originalRect, transform: transform)
        let isValid = transformedRect.contains(targetFrame, approximately: true)
        return isValid
    }

    fileprivate func validTransform(from transform: CGAffineTransform,
                                    originalRect: CGRect,
                                    within targetFrame: CGRect,
                                    allowScaling: Bool) -> CGAffineTransform {

        var updatedTransform = transform

        if updatedTransform.scale > maximumScale || updatedTransform.scale < -0.5 {
            let inverseScale = maximumScale / fabs(updatedTransform.scale)
            updatedTransform = updatedTransform.scaledBy(x: inverseScale, y: inverseScale)

            let anchorPoint = CGPoint(x: updatedTransform.tx, y: updatedTransform.ty) * inverseScale
            updatedTransform.tx = anchorPoint.x
            updatedTransform.ty = anchorPoint.y
        }

        let transformedRect = TransformableRect(originalRect, transform: updatedTransform)

        if allowScaling {
            let transformToFit = transformedRect.transform(toContain: targetFrame)
            updatedTransform = updatedTransform.concatenating(transformToFit)
        } else {
            let translationTransform = transformedRect.translationTransform(toContain: targetFrame)
            updatedTransform = updatedTransform.concatenating(translationTransform)
        }

        return updatedTransform
    }

    // MARK: Logging

    struct ViewState {
        var rotationStep: Int
        var hasBeenScaled: Bool
        var hasBeenRotatedFreeform: Bool
        var hasBeenRotated90: Bool
        var hasOnlyBeenRotated90: Bool
        var hasRotationAdjustment: Bool

        static var empty: ViewState {
            return ViewState(rotationStep: 0,
                             hasBeenScaled: false,
                             hasBeenRotatedFreeform: false,
                             hasBeenRotated90: false,
                             hasOnlyBeenRotated90: false,
                             hasRotationAdjustment: false)
        }
    }

    var viewState: ViewState {
        return ViewState(rotationStep: currentRotationOperation?.rotationSteps ?? 0,
                         hasBeenScaled: hasBeenScaled,
                         hasBeenRotatedFreeform: hasBeenRotatedFreeform,
                         hasBeenRotated90: hasBeenRotated90,
                         hasOnlyBeenRotated90: hasOnlyBeenRotated90,
                         hasRotationAdjustment: hasBeenRotatedUsingControl)
    }

    fileprivate var hasBeenRotated90: Bool = false
    fileprivate var hasBeenRotatedFreeform: Bool = false
    fileprivate var hasBeenRotatedUsingControl: Bool = false
    fileprivate var hasBeenScaled: Bool = false

    private var hasOnlyBeenRotated90: Bool {
        return canvasTransform.rotation.isApproximatelyEqual(canvasTransform.rotatatedToAxis.rotation)
    }

}

extension CoreImageView: UIGestureRecognizerDelegate {

    fileprivate func setupGestureRecognizers() {
        guard !hasSetupGestureRecognizers else { return }
        hasSetupGestureRecognizers = true

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        addGestureRecognizer(panGestureRecognizer)
        self.panGestureRecognizer = panGestureRecognizer

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchGestureRecognizer.delegate = self
        addGestureRecognizer(pinchGestureRecognizer)
        self.pinchGestureRecognizer = pinchGestureRecognizer

        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        rotationGestureRecognizer.delegate = self
        addGestureRecognizer(rotationGestureRecognizer)
        self.rotationGestureRecognizer = rotationGestureRecognizer
    }

    @objc func handlePanGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            canvasGestureRecognizerDidBegin(gestureRecognizer)

        case .changed:
            // This transform is used to adjust pan gestures into the image space
            let translationInCanvas = gestureRecognizer.translation(in: self)
            let translationInImage = translationInCanvas.applying(canvasTransform.normalizingTransform)
            let modifiedCanvasTransform = canvasTransform.translatedBy(x: translationInImage.x, y: translationInImage.y)

            let shouldValidateTransform = constraintMode == .continuous

            setCanvasTransform(modifiedCanvasTransform,
                               validate: shouldValidateTransform,
                               allowScaling: false,
                               notifying: true,
                               animated: false)

            // Reset the gesture recognizer
            gestureRecognizer.setTranslation(.zero, in: self)

        case .ended, .failed, .cancelled:
            canvasGestureRecognizerDidFinish(gestureRecognizer)

        default:
            break
        }
    }

    @objc func handlePinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            canvasGestureRecognizerDidBegin(gestureRecognizer)

        case .changed:
            // Scale from the pinch location
            let locationInCanvas = gestureRecognizer.location(in: self) - canvasOrigin
            let locationInImage = locationInCanvas.applying(canvasTransform.inverted())
            let scale = gestureRecognizer.scale

            let modifiedCanvasTransform = canvasTransform.scaledBy(x: scale, y: scale, fromAnchorPoint: locationInImage)

            let shouldValidateTransform = constraintMode == .continuous
            setCanvasTransform(modifiedCanvasTransform, validate: shouldValidateTransform, notifying: true, animated: false)

            // Reset the gesture recognizer
            gestureRecognizer.scale = 1.0

        case .ended, .failed, .cancelled:
            canvasGestureRecognizerDidFinish(gestureRecognizer)

        default:
            break
        }
    }

    @objc func handleRotationGesture(_ gestureRecognizer: UIRotationGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            canvasGestureRecognizerDidBegin(gestureRecognizer)
            hasBeenRotatedFreeform = true

        case .changed:
            // Rotate around the pinch location
            let locationInCanvas = gestureRecognizer.location(in: self) - canvasOrigin
            let locationInImage = locationInCanvas.applying(canvasTransform.inverted())
            let rotation = gestureRecognizer.rotation
            let modifiedCanvasTransform = canvasTransform.rotated(by: rotation, aroundAnchorPoint: locationInImage)

            let shouldValidateTransform = constraintMode == .continuous
            setCanvasTransform(modifiedCanvasTransform, validate: shouldValidateTransform, notifying: true, animated: false)

            // Reset the gesture recognizer
            gestureRecognizer.rotation = 0.0

        case .ended, .failed, .cancelled:
            canvasGestureRecognizerDidFinish(gestureRecognizer)

        default:
            break
        }
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return isEnabled
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let gestureRecognizers: [UIGestureRecognizer?] = [
            panGestureRecognizer,
            pinchGestureRecognizer,
            rotationGestureRecognizer,
        ]

        let canvasGestureRecognizers = gestureRecognizers.flatMap { $0 }
        let bothAreCanvasGestures = canvasGestureRecognizers.contains(gestureRecognizer)
                                        && canvasGestureRecognizers.contains(otherGestureRecognizer)

        return bothAreCanvasGestures
    }

    fileprivate func canvasGestureRecognizerDidBegin(_ gestureRecognizer: UIGestureRecognizer) {
        currentRotationOperation = nil

        if scaleOrRotationGestureRecognizers.contains(gestureRecognizer) {
            activeScaleOrRotationGestureRecognizers.insert(gestureRecognizer)
        }
    }

    fileprivate func canvasGestureRecognizerDidFinish(_ gestureRecognizer: UIGestureRecognizer) {
        guard isEnabled else { return }

        activeScaleOrRotationGestureRecognizers.remove(gestureRecognizer)

        if constraintMode == .afterGesturesFinish && activeScaleOrRotationGestureRecognizers.isEmpty {
            setCanvasTransform(canvasTransform, validate: true, allowScaling: true, notifying: true, animated: true)
        }
    }

    fileprivate var scaleOrRotationGestureRecognizers: [UIGestureRecognizer] {
        let gestureRecognizers: [UIGestureRecognizer?] = [pinchGestureRecognizer, rotationGestureRecognizer]
        return gestureRecognizers.flatMap { $0 }
    }

}

private struct RotationOperation {
    // A RotationOperation groups rotations so that the original scale
    // and position are retained, through multiple steps of rotation
    //
    // For instance if you rotate 90 degrees, and the image needs
    // to be scaled to fill the target in portrait, rotating another
    // 90 degrees (up to 180) should return to the original images scale
    //
    // The RotationOperation is discarded when the user starts a multi-touch gesture

    private let baseTransform: CGAffineTransform
    private let origin: CGPoint
    private let alignToCardinals: Bool
    fileprivate let rotationSteps: Int
    private let adjustment: CGFloat

    init(transform: CGAffineTransform, origin: CGPoint) {
        self.init(transform: transform, origin: origin, alignToCardinals: false, rotationSteps: 0)
    }

    // transform:   		The original transform
    // origin:      		Origin, the point around which to rotate
    // alignToCardinals:    Whether to align to a cardinal direction when rotating 90 degrees
    // rotationSteps:       An integer between 0 and 3 which represents the clockwise steps away from the base transform
    // adjustment:          A float representing a freeform adjustment in radians

    private init(transform: CGAffineTransform, origin: CGPoint, alignToCardinals: Bool, rotationSteps: Int, adjustment: CGFloat = 0.0) {
        baseTransform = alignToCardinals ? transform.rotatatedToAxis : transform

        self.origin = origin
        self.rotationSteps = rotationSteps
        self.adjustment = adjustment
        self.alignToCardinals = alignToCardinals
    }

    var incrementingRotation: RotationOperation {
        var newRotationSteps = self.rotationSteps + 1

        if newRotationSteps > 3 {
            newRotationSteps = 0
        }

        // Intentionally discarding any rotation adjustment
        let transform = alignToCardinals ? baseTransform.rotatatedToAxis : baseTransform

        return RotationOperation(transform: transform,
                                 origin: origin,
                                 alignToCardinals: false,
                                 rotationSteps: newRotationSteps,
                                 adjustment: 0.0)
    }

    var decrementingRotation: RotationOperation {
        var newRotationSteps = self.rotationSteps - 1

        if newRotationSteps < 0 {
            newRotationSteps = 3
        }

        // Intentionally discarding any rotation adjustment
        let transform = alignToCardinals ? baseTransform.rotatatedToAxis : baseTransform

        return RotationOperation(transform: transform,
                                 origin: origin,
                                 alignToCardinals: false,
                                 rotationSteps: newRotationSteps,
                                 adjustment: 0.0)
    }

    func withAdjustmentRotation(_ rotation: CGFloat) -> RotationOperation {
        return RotationOperation(transform: baseTransform,
                                 origin: origin,
                                 alignToCardinals: false,
                                 rotationSteps: rotationSteps,
                                 adjustment: rotation)
    }

    var rotation: CGFloat {
        var rotation = CGFloat(rotationSteps) * (CGFloat.pi / 2)
        rotation += adjustment
        return rotation
    }

    var rotatedTransform: CGAffineTransform {
        return baseTransform.rotated(by: rotation, aroundAnchorPoint: origin)
    }

}
