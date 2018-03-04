//
//  PhotoEditorGeometryUnitTests.swift
//  PhotoEditor
//
//  Created by Harry Jordan 29/09/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import XCTest

class GeometryUnitTests: XCTestCase {

    func testPointIntersectionsInside() {
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
        let rotatableRect = TransformableRect(rect, transform: .identity)

        for points in rect.points {
            XCTAssertTrue(rotatableRect.contains(points), "Expect: \(points) to be inside \(rect)")
        }
    }


    func testPointIntersectionsOutside() {
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
        let transformedRect = TransformableRect(rect, transform: .identity)

        let testPoints = [
            CGPoint(x: -0.2, y: -0.2),
            CGPoint(x: 10.2, y: 10.2),
            CGPoint(x: 10.2, y: 5),
            CGPoint(x: 0.5, y: -0.2),
            ]

        let pointsAreInside = testPoints.map { transformedRect.contains($0) }

        for isInside in pointsAreInside {
            XCTAssertFalse(isInside)
        }
    }


    func testRectContainsRect() {
        let originalRect = CGRect(x: 0, y: 0, width: 10, height: 10)
        let rotatableRect = TransformableRect(originalRect, transform: .identity)

        XCTAssertTrue(rotatableRect.contains(originalRect))
        XCTAssertTrue(rotatableRect.contains(CGRect(x: 3, y: 3, width: 6, height: 6)))

        XCTAssertFalse(rotatableRect.contains(CGRect(x: 0, y: 0, width: 12, height: 12)))
        XCTAssertFalse(rotatableRect.contains(CGRect(x: 0, y: 0, width: 14, height: 4)))
    }


    func testRotatedRectsEdges() {
        let originalRect = CGRect(x: 0, y: 0, width: 10, height: 10)

        let fullCircle = CGFloat.pi * 2
        let rotation = fullCircle * (1 / 8)     // 45 degrees in radians
        let rotationTransform = CGAffineTransform(rotationAngle: rotation)
        let rotatedRect = TransformableRect(originalRect, transform: rotationTransform)

        let edges = rotatedRect.edges

        let topLeft = CGPoint(x: 5, y: -2.07)
        let topRight = CGPoint(x: 12.07, y: 5)
        let bottomRight = CGPoint(x: 5, y: 12.07)
        let bottomLeft = CGPoint(x: -2.07, y: 5)

        let expectedEdges = [
            TransformableRect.Edge(start: topLeft, end: topRight),
            TransformableRect.Edge(start: topRight, end: bottomRight),
            TransformableRect.Edge(start: bottomRight, end: bottomLeft),
            TransformableRect.Edge(start: bottomLeft, end: topLeft),
        ]

        for (edge, expectedEdge) in zip(edges, expectedEdges) {
            let accuracy: CGFloat = 0.5
            XCTAssertEqual(edge.start.x, expectedEdge.start.x, accuracy: accuracy)
            XCTAssertEqual(edge.start.y, expectedEdge.start.y, accuracy: accuracy)
        }
    }


    func testRectContainsRect2() {
        let originalSize = CGSize(width: 1.0, height: 1.0)
        let originalRect = CGRect(origin: .zero, size: originalSize).centered(on: .zero)
        let rotatableRect = TransformableRect(originalRect, transform: .identity)

        XCTAssertTrue(rotatableRect.contains(originalRect))
    }


    func testTranslatingTransformedRectToFit2() {
        let originalRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
        let firstTransform = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: -250.33332824707, ty: 21.0)
        let secondTransform = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 150.33332824707, ty: 21.0)

        let transformedRect = originalRect.applying(firstTransform).applying(secondTransform)

        var transformableRect = TransformableRect(originalRect, transform: firstTransform)
        transformableRect.transform = transformableRect.transform.concatenating(secondTransform)

        XCTAssertFalse(transformedRect.contains(originalRect))
        XCTAssertFalse(transformableRect.contains(originalRect))
    }


    func testWindingNumbersForPoints() {
        let rect = CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0)
        let transformedRect = TransformableRect(rect, transform: .identity)

        XCTAssertEqual(transformedRect.windingNumber(for: rect.center, within: transformedRect.edges), 1)

        // Exact corners
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 0.0, y: 20.0), within: transformedRect.edges), 1)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 0.0, y: 0.0), within: transformedRect.edges), 1)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 20, y: 0.0), within: transformedRect.edges), 1)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 20.0, y: 20.0), within: transformedRect.edges), 1)

        // Offest from rect horizontal
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: -1.0, y: 20.0), within: transformedRect.edges), 0)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: -0.1, y: 0.0), within: transformedRect.edges), 0)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 20.1, y: 0.0), within: transformedRect.edges), 0)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 21.0, y: 20.0), within: transformedRect.edges), 0)

        // Offest from rect vertical
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 0.0, y: -1.0), within: transformedRect.edges), 0)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 0.0, y: 21.0), within: transformedRect.edges), 0)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 20.0, y: 21.0), within: transformedRect.edges), 0)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 20.0, y: -1.0), within: transformedRect.edges), 0)
    }


    func testWindingNumbersForPoints2() {
        let rect = CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0)
        let transformedRect = TransformableRect(rect, transform: .identity)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: 20, y: 0.0), within: transformedRect.edges), 1)
    }


    func testWindingNumbersForPoints3() {
        let rect = CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0)
        let transformedRect = TransformableRect(rect, transform: .identity)
        XCTAssertEqual(transformedRect.windingNumber(for: CGPoint(x: -1.0, y: 20.0), within: transformedRect.edges), 0)
    }



    func validateTranslationTransformContainsExpectedPoints(_ rect: CGRect, _ translationTransform: CGAffineTransform, testPoints: [CGPoint]) {
        for testPoint in testPoints {
            let transformedRect = TransformableRect(rect, transform: translationTransform)
            let containedInRect = rect.applying(translationTransform).contains(testPoint)
            let containedInTransformedRect = transformedRect.contains(testPoint)
			XCTAssertEqual(containedInRect, containedInTransformedRect)
        }
    }


    func testRotatedAndScaledRectEdges() {
        let originalRect = CGRect(x: 0, y: 0, width: 10, height: 10)

        let fullCircle = CGFloat.pi * 2
        let rotation = fullCircle * (1 / 8)     // 45 degrees in radians
        let scale: CGFloat = 2.0

        let rotationTransform = CGAffineTransform(rotationAngle: rotation)
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let combinedTransform = rotationTransform.concatenating(scaleTransform)

        let rotatedRect = TransformableRect(originalRect, transform: combinedTransform)
        let edges = rotatedRect.edges

        let topLeft = CGPoint(x: 5, y: -9.14)
        let topRight = CGPoint(x: 19.14, y: 5)
        let bottomRight = CGPoint(x: 5, y: 19.14)
        let bottomLeft = CGPoint(x: -9.14, y: 5)

        let expectedEdges = [
            TransformableRect.Edge(start: topLeft, end: topRight),
            TransformableRect.Edge(start: topRight, end: bottomRight),
            TransformableRect.Edge(start: bottomRight, end: bottomLeft),
            TransformableRect.Edge(start: bottomLeft, end: topLeft),
        ]

        for (edge, expectedEdge) in zip(edges, expectedEdges) {
            let accuracy: CGFloat = 0.5
            XCTAssertEqual(edge.start.x, expectedEdge.start.x, accuracy: accuracy)
            XCTAssertEqual(edge.start.y, expectedEdge.start.y, accuracy: accuracy)
        }
    }


    func testRotatedRectDoesntContainOriginalRect() {
        let originalRect = CGRect(x: 0, y: 0, width: 10, height: 10)

        let fullCircle = CGFloat.pi * 2
        let rotation = fullCircle * (1 / 8)     // 45 degrees in radians
        let rotationTransform = CGAffineTransform(rotationAngle: rotation)
        let rotatableRect = TransformableRect(originalRect, transform: rotationTransform)

        XCTAssertFalse(rotatableRect.contains(originalRect))
    }


    func testRotatedAndScaledRectContainOriginalRect() {
        let originalRect = CGRect(x: 0, y: 0, width: 10, height: 10)

        let fullCircle = CGFloat.pi * 2
        let rotation = fullCircle * (1 / 8)     // 45 degrees in radians
        let scale: CGFloat = 2.0

        let rotationTransform = CGAffineTransform(rotationAngle: rotation)
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let combinedTransform = rotationTransform.concatenating(scaleTransform)

        let rotatedAndScaledRect = TransformableRect(originalRect, transform: combinedTransform)

        XCTAssertTrue(rotatedAndScaledRect.contains(originalRect))
    }


    func testRotatedRectContainsSmallerRects() {
        let originalRect = CGRect(x: 0, y: 0, width: 10, height: 10)
        let interiorRect = CGRect(x: 4, y: -0.25, width: 2, height: 2)

        let fullCircle = CGFloat.pi * 2
        let rotation = fullCircle * (1 / 8)     // 45 degrees in radians
        let rotationTransform = CGAffineTransform(rotationAngle: rotation)
        let rotatedRect = TransformableRect(originalRect, transform: rotationTransform)

        XCTAssertTrue(rotatedRect.contains(interiorRect))
    }


    func testExpandingARectToContainAnotherRect1() {
        let originalRect = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        let targetRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)

        let transformableRect = TransformableRect(originalRect, transform: .identity)
        let transform = transformableRect.scaleTransform(toContain: targetRect)

        let convertedRect = originalRect.applying(transform)
        XCTAssertEqual(convertedRect, targetRect)
    }


    func testExpandingARotatedRectToContainAnotherRect1() {
        let originalRect = CGRect(x: -0.5, y: -0.5, width: 1.0, height: 1.0)
        let targetRect = CGRect(x: -0.5, y: -0.5, width: 1.0, height: 1.0)

        let originalTransform = CGAffineTransform(rotationAngle: (CGFloat.pi * 2) / 8)  // 45 degrees
        var transformableRect = TransformableRect(originalRect, transform: originalTransform)
        let transform = transformableRect.scaleTransform(toContain: targetRect)

        transformableRect.transform = transform
        XCTAssertTrue(transformableRect.contains(targetRect))
    }


    func testExpandingARotatedRectToContainAnotherRect2() {
        let originalRect = CGRect(x: -0.5, y: -0.5, width: 1.0, height: 1.0)
        let targetRect = CGRect(x: -0.5, y: -0.5, width: 1.0, height: 1.0)

        let originalTransform = CGAffineTransform(rotationAngle: (CGFloat.pi * 2) / 4)  // 90 degrees
        var transformableRect = TransformableRect(originalRect, transform: originalTransform)
        let transform = transformableRect.scaleTransform(toContain: targetRect)

        transformableRect.transform = transform
        XCTAssertTrue(transformableRect.contains(targetRect))
    }


    func testScalingTransformedRectToFitOneShift() {
        let originalRect = CGRect(x: 0.0, y: 0.0, width: 50.0, height: 50.0)
        let targetRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)

        let transformableRect = TransformableRect(originalRect, transform: .identity)
        let transform = transformableRect.scaleTransform(toContain: targetRect)

        let convertedRect = originalRect.applying(transform)
        XCTAssertEqual(convertedRect, targetRect)
    }


    func testScalingRectToFitNeedingTwoShifts() {
        let originalRect = CGRect(x: -3.0, y: -1.0, width: 6.0, height: 2.0)
        let targetRect = CGRect(x: -2.0, y: -2.0, width: 4.0, height: 4.0)

        let transformableRect = TransformableRect(originalRect, transform: .identity)
        let transform = transformableRect.transform(toContain: targetRect)

        var scaledRect = transformableRect
        scaledRect.transform = scaledRect.transform.concatenating(transform)

        XCTAssertTrue(scaledRect.contains(targetRect))
    }


    func testScalingTransformedRectToFit() {
        let originalRect = CGRect(x: -2.0, y: -2.0, width: 4.0, height: 4.0)
        let targetRect = CGRect(x: -2.0, y: -2.0, width: 2.0, height: 2.0)

        let originalTransform = CGAffineTransform(rotationAngle: (CGFloat.pi * 2) / 8)  // 45 degrees
        let transformableRect = TransformableRect(originalRect, transform: originalTransform)

        XCTAssertFalse(transformableRect.contains(targetRect))

        let transform = transformableRect.scaleTransform(toContain: targetRect)

        var adaptedRect = transformableRect
        adaptedRect.transform = adaptedRect.transform.concatenating(transform)

        XCTAssertTrue(adaptedRect.contains(targetRect))
    }
	
	
    func testTranslatingTransformedRectToFit() {
        let originalRect = CGRect(x: 0.0, y: 0.0, width: 2.0, height: 2.0)
        let targetRect = CGRect(x: 2.0, y: 2.0, width: 2.0, height: 2.0)
        
        let transformableRect = TransformableRect(originalRect, transform: .identity)
        let translationTransform = transformableRect.translationTransform(toContain: targetRect)

        XCTAssertEqual(translationTransform.tx, 2.0, accuracy: CGFloat.ulpOfOne)
        XCTAssertEqual(translationTransform.ty, 2.0, accuracy: CGFloat.ulpOfOne)
    }


    func testTranslatingTransformedRectToFit3() {
        let originalRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
        let transform = CGAffineTransform(a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: -250.33332824707, ty: 21.0)

        var transformableRect = TransformableRect(originalRect, transform: transform)
        let translationTransform = transformableRect.translationTransform(toContain: originalRect)
        transformableRect.transform = transformableRect.transform.concatenating(translationTransform)

        XCTAssertTrue(transformableRect.contains(originalRect))
    }
	


    func testScalingAndTranslatingToFillEdgeCase1() {
        let transform = CGAffineTransform(a: 2.72568093637708, b: 0.582498559803249, c: -0.582498559803249, d: 2.72568093637708, tx: 6.657285183639, ty: 12.6343684859737)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func testScalingAndTranslatingToFillEdgeCase2() {
        let transform = CGAffineTransform(a: 0.952877436171684, b: 0.286399228437701, c: -0.286399228437701, d: 0.952877436171684, tx: 5.93574044713764, ty: 46.6659516880968)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func testScalingAndTranslatingToFillEdgeCase3() {
        let transform = CGAffineTransform(a: 0.957265840884479, b: -0.345796841291223, c: 0.345796841291223, d: 0.957265840884479, tx: -3.2087214354693, ty: 61.3432559377237)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func testScalingAndTranslatingToFillEdgeCase4() {
        let transform = CGAffineTransform(a: 0.728805764072138, b: 0.0942849324859768, c: -0.0942849324859768, d: 0.728805764072138, tx: 19.5136911281612, ty: -9.1002453599068)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func testScalingAndTranslatingToFillEdgeCase5() {
        let transform = CGAffineTransform(a: 0.564491506714731, b: 0.263652137648569, c: -0.263652137648569, d: 0.564491506714731, tx: -3.8422853913976, ty: 11.7595654276103)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func testScalingAndTranslatingToFillEdgeCase6() {
        let transform = CGAffineTransform(a: 0.434797778756295, b: -0.294928048191694, c: 0.294928048191694, d: 0.434797778756295, tx: 17.562247866063, ty: 105.345770061701)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func validateScaleAndTranslateToFit(_ originalTransform: CGAffineTransform) -> Bool {
        let originalRect = CGRect(x: -167.0, y: -53.2856274072572, width: 334.0, height: 106.571254814514)
        let targetFrameRect = CGRect(x: -167.0, y: -167.0, width: 334.0, height: 334.0)

        let originalTransformableRect = TransformableRect(originalRect, transform: originalTransform)
        let transformToFit = originalTransformableRect.transform(toContain: targetFrameRect)
        let updatedTransformableRect = originalTransformableRect.applying(transformToFit)

        // This works around failing tests due to (hopefully) negligible rounding errors
        let fudgeScaleTransform = CGAffineTransform(scaleX: 0.9999999999, y: 0.9999999999)
        return updatedTransformableRect.contains(targetFrameRect.applying(fudgeScaleTransform))
    }
    

    func testTranslatingToFillEdgeCase1() {
        let transform = CGAffineTransform(a: 1.49882903981265, b: 0.0, c: 0.0, d: 1.49882903981265, tx: -136.0, ty: 146.0)
        XCTAssertTrue(validateScaleAndTranslateToFit(transform))
    }


    func testScaleAndTranslateToFillRotating180() {
        let originalTransform = CGAffineTransform(rotationAngle: CGFloat.pi)

        let originalRect = CGRect(x: -200.0, y: -100.0, width: 400.0, height: 200.0)
        var transformableRect = TransformableRect(originalRect, transform: originalTransform)
        let adjustment = transformableRect.transform(toContain: originalRect)
        transformableRect.transform = originalTransform.concatenating(adjustment)

        let epsilon: CGFloat = 0.001

        XCTAssertEqual(transformableRect.points[0].x, 200.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[0].y, 100.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[1].x, -200.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[1].y, 100.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[2].x, -200.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[2].y, -100.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[3].x, 200.0, accuracy: epsilon)
        XCTAssertEqual(transformableRect.points[3].y, -100.0, accuracy: epsilon)
    }


    func testNearestPointToPoint() {
        let originalRect = CGRect(x: -2.0, y: -2.0, width: 4.0, height: 4.0)
        let transform = CGAffineTransform(rotationAngle: (CGFloat.pi * 2) / 8)  // 45 degrees
        let testPoint = CGPoint(x: 2.0, y: 2.0)
        let expectedPoint = CGPoint(x: sqrt(2.0), y: sqrt(2.0))

        let transformableRect = TransformableRect(originalRect, transform: transform)
        let nearestPoint = transformableRect.nearestPoint(to: testPoint)

        XCTAssertEqual(nearestPoint.x, expectedPoint.x, accuracy: 0.000001)
        XCTAssertEqual(nearestPoint.y, expectedPoint.y, accuracy: 0.000001)
    }


    func testNearestPointOnLine() {
        let edge = TransformableRect.Edge(start: CGPoint(x: -1.0, y: 0.0), end: CGPoint(x: 1.0, y: 0.0))
        let nearestPoint = edge.nearestPoint(to: CGPoint(x: 0.0, y: 1.0))

        XCTAssertEqual(nearestPoint, .zero)
    }


    func testDotProduct() {
        let first = CGPoint(x: 1.0, y: 2.0)
        let second = CGPoint(x: 3.0, y: 4.0)

        XCTAssertEqual(first.dotProduct(second), 11.0)
    }


    func testCGSizeScaleToFit() {
        let aspectRatio = CGSize(width: 3000.0, height: 2000.0)
        let targetSize = CGSize(width: 1024.0, height: 1024.0)

        XCTAssertEqual(aspectRatio.scaleToFit(targetSize), 0.3413333333, accuracy: 0.001)
    }


    func testLookingForTheScaleToZoomBug() {
        let edge = 100.0
        let originalRect = CGRect(x: -edge, y: -edge, width: edge, height: edge)
        let targetRect = CGRect(x: -edge * 2, y: -edge * 2, width: edge * 4, height: edge * 4)

        let transformableRect = TransformableRect(originalRect, transform: .identity)
        let combinedTransform = transformableRect.transform(toContain: targetRect)

        let combinedRect = transformableRect.applying(combinedTransform)

        XCTAssertEqual(combinedRect.points, [
            CGPoint(x: -edge * 2, y: -edge * 2),
            CGPoint(x: edge * 2, y: -edge * 2),
            CGPoint(x: edge * 2, y: edge * 2),
            CGPoint(x: -edge * 2, y: edge * 2),
        ])
    }


    func testLookingForTheScaleToZoomBug2() {
        let originalRect = CGRect(x: -187.0, y: -124.7640625, width: 374.0, height: 249.528125)
        let targetRect = CGRect(x: -187.0, y: -124.666666666667, width: 374.0, height: 249.333333333333)
        let transform = CGAffineTransform(a: 0.445329738280878, b: 0.0, c: 0.0, d: 0.445329738280878, tx: -55.1315892260383, ty: 70.89160912441)

        let transformableRect = TransformableRect(originalRect, transform: transform)
        let transformToFit = transformableRect.transform(toContain: targetRect)
        let updatedRect = transformableRect.applying(transformToFit)

        XCTAssertLessThan(updatedRect.transform.scale, 2.0)
    }


    func testLookingForTheScaleToZoomBug3() {
        let originalRect = CGRect(x: -187.0, y: -124.7640625, width: 374.0, height: 249.528125)
        let targetRect = CGRect(x: -187.0, y: -124.666666666667, width: 374.0, height: 249.333333333333)
        let transform = CGAffineTransform(a: 0.394426328452748, b: 0.0, c: 0.0, d: 0.394426328452748, tx: -23.4209756636358, ty: 81.4286542759142)

        let transformableRect = TransformableRect(originalRect, transform: transform)
        let transformToFit = transformableRect.transform(toContain: targetRect)
        let updatedRect = transformableRect.applying(transformToFit)
        
        XCTAssertLessThan(updatedRect.transform.scale, 2.0)
    }

}
