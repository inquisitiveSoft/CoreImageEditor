//
//  InterpolationAnimation.swift
//  PhotoEditor
//
//  Created by Harry Jordan 27/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import Foundation
import QuartzCore

final class InterpolationAnimation<T: Interpolatable> {

    typealias InterpolationAnimationProgressHandler = (T, TimeInterval) -> Void
    typealias InterpolationAnimationCompletionHandler = (T, Bool) -> Void

    enum InterpolationAnimationState {
        case start
        case animating
        case finished
        case cancelled
    }

    private lazy var displayLink: CADisplayLink = { [weak self] in
        // Using a convoluted approach to get updates to avoid a retain-loop
        // as CADisplayLink retains it's target
        let target = InterpolationAnimationTarget({ [weak self] (displayLink) in
            self?.update(displayLink)
        })

        let displayLink = CADisplayLink(target: target, selector: #selector(update(_:)))
        displayLink.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        displayLink.isPaused = true

        if #available(iOS 10.0, *) {
            // Zero here is the 'native cadence' of the devices display
            displayLink.preferredFramesPerSecond = self?.numberOfFramesPerSecond ?? 0
        } else {
            displayLink.frameInterval = 0
        }

        return displayLink
    }()

    let duration: TimeInterval
    let startValue: T
    let endValue: T

    private var frameNumber: Int = 0
    private var numberOfFrames: Int = 0

    private var delayNumber: Int = 0
    private var numberOfFramesToDelay: Int = 0

    private let numberOfFramesPerSecond: Int = 60

    var progressHandler: InterpolationAnimationProgressHandler?         // (currentValue, progress) -> Void
    var completionHandler: InterpolationAnimationCompletionHandler?     // (endValue, finished) -> Void

    typealias InterpolationFunction = (T, T, CGFloat) -> T

    lazy var interpolationFunction: InterpolationFunction = {
        return InterpolationAnimation.specializedInterpolationFunction(lerp, as: T.self)
    }()

    private static func specializedInterpolationFunction<T>(_ function: @escaping InterpolationFunction,
                                                            as _: T.Type) -> InterpolationFunction {
        // This is a slightly convoluted way to get a specialized version of a function
        // that is assignable. Only for use within InterpolationAnimation.
        // Ref: https://stackoverflow.com/a/40694115
        return function
    }

    private(set) var state: InterpolationAnimationState = .start

    init(duration: TimeInterval, from startValue: T, to endValue: T, progressHandler: InterpolationAnimationProgressHandler? = nil) {
        self.duration = duration
        self.startValue = startValue
        self.endValue = endValue
        self.progressHandler = progressHandler
    }

    func start(afterDelay delay: TimeInterval? = nil) {
        guard state == .start else {
            print("\(self) Animation already started")
            return
        }

        frameNumber = 0
        numberOfFrames = Int(duration * TimeInterval(numberOfFramesPerSecond))

        if let delay = delay {
            numberOfFramesToDelay = Int(delay * TimeInterval(numberOfFramesPerSecond))
        } else {
            numberOfFramesToDelay = 0
        }

        state = .animating
        displayLink.isPaused = false
    }

    @objc private func update(_ displayLink: CADisplayLink) {
        // Wait until we've waited the allocated number of delay frames
        if delayNumber < numberOfFramesToDelay {
            delayNumber += 1
            return
        }

        frameNumber += 1
        progressHandler?(currentValue, progress)

        if frameNumber >= numberOfFrames {
            finish(completed: true)
        }
    }

    func cancel() {
        state = .cancelled
        displayLink.isPaused = true

        finish(completed: false)

    }

    private func finish(completed: Bool) {
        state = .finished
        displayLink.isPaused = true

        if completed {
            completionHandler?(endValue, completed)
        }
    }

    var progress: TimeInterval {
        if frameNumber >= numberOfFrames {
            // Test this statement first, because if numberOfFrames is 0
            // then it counts as the animation as having completed
            return 1.0
        } else if frameNumber <= 0 {
            return 0.0
        } else {
            return TimeInterval(frameNumber) / TimeInterval(numberOfFrames)
        }
    }

    var currentValue: T {
        return interpolationFunction(startValue, endValue, CGFloat(progress))
    }

    deinit {
        displayLink.invalidate()
    }

    fileprivate class InterpolationAnimationTarget {
        fileprivate typealias DisplayLinkHandler = (_ displayLink: CADisplayLink) -> Void

        private var updateHandler: DisplayLinkHandler

        init(_ updateHandler: @escaping DisplayLinkHandler) {
            self.updateHandler = updateHandler
        }

        @objc private func update(_ displayLink: CADisplayLink) {
            updateHandler(displayLink)
        }
    }

}
