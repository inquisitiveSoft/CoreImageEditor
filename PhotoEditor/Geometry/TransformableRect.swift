//
//  TransformableRect.swift
//  PhotoEditor
//
//  Created by Harry Jordan 06/10/2017
//
// Copyright Harry Jordan, 2018
// Open-sourced under the MIT license: https://opensource.org/licenses/MIT
//

import CoreGraphics

public struct TransformableRect {
    public var rect: CGRect

    // Transforms are relative to the center of the rect
    public var transform: CGAffineTransform

    init(_ rect: CGRect, transform: CGAffineTransform) {
        self.rect = rect
        self.transform = transform
    }

    private var combinedTransform: CGAffineTransform {
        // Transforms want to be relative to the center of the rect
        // but the CGPoints are in normal view coordinates
        // so adjust to the 'normalized' origin
        let originTransform = CGAffineTransform(translationX: -rect.midX, y: -rect.midY)
        var combinedTransform = originTransform

        // Apply the transform
        combinedTransform = originTransform.concatenating(transform)

        // And then revese the origin transform to return to view coordinates
        combinedTransform = combinedTransform.concatenating(originTransform.inverted())
        return combinedTransform
    }

    public func applying(_ secondTransform: CGAffineTransform) -> TransformableRect {
        let combinedTransform = self.transform.concatenating(secondTransform)
        return TransformableRect(rect, transform: combinedTransform)
    }

    internal struct Edge: Equatable {
        // Only exposed for testing purposes
        var start: CGPoint
        var end: CGPoint

        public static func == (lhs: Edge, rhs: Edge) -> Bool {
            return (lhs.start == rhs.start) && (lhs.end == rhs.end)
        }
    }

    internal var edges: [Edge] {
        // Only public for testing purposes
        var topLeft = CGPoint(x: rect.minX, y: rect.minY)
        var topRight = CGPoint(x: rect.maxX, y: rect.minY)
        var bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        var bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        topLeft = topLeft.applying(combinedTransform)
        topRight = topRight.applying(combinedTransform)
        bottomLeft = bottomLeft.applying(combinedTransform)
        bottomRight = bottomRight.applying(combinedTransform)

        return [
            Edge(start: topLeft, end: topRight),
            Edge(start: topRight, end: bottomRight),
            Edge(start: bottomRight, end: bottomLeft),
            Edge(start: bottomLeft, end: topLeft),
        ]
    }

    public var points: [CGPoint] {
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)

        return [
            topLeft.applying(combinedTransform),
            topRight.applying(combinedTransform),
            bottomRight.applying(combinedTransform),
            bottomLeft.applying(combinedTransform),
        ]
    }

    public var center: CGPoint {
        return rect.center.applying(transform)
    }

    public var boundingRect: CGRect {
        // Again, force unwrapping here seems justified
        let initialRect = CGRect(origin: points[0], size: .zero)

        let boundingRect = points.reduce(initialRect) { (rectangle, nextPoint) -> CGRect in
            let nextRect = CGRect(origin: nextPoint, size: .zero)
            return rectangle.union(nextRect)
        }

        return boundingRect
    }

    // MARK: Detect whether the TransformableRect contains a given point or rect

    public func contains(_ point: CGPoint) -> Bool {
        return windingNumber(for: point, within: edges) != 0
    }

    public func contains(_ rect: CGRect, approximately: Bool = false) -> Bool {
        let edges = self.edges
        var rect = rect

        if approximately {
            rect = rect.applying(CGAffineTransform.identity.scaledBy(x: 0.9999, y: 0.9999, fromAnchorPoint: rect.center))
        }

        let hasPointOutside = rect.points.contains(where: { (point) -> Bool in
            return windingNumber(for: point, within: edges) == 0
        })

        return !hasPointOutside
    }

    internal func windingNumber(for testPoint: CGPoint, within edges: [Edge]) -> Int {
        // Using the winding number to detect whether a given point is within a polygon
        // Reference: http://geomalgorithms.com/a03-_inclusion.html
        var windingNumber = 0

        let isPointBetween = { (testPoint: CGFloat, firstValue: CGFloat, secondValue: CGFloat) -> Bool in
            // This weird Swift.max is required https://stackoverflow.com/a/32507467
            let upperBound = max(firstValue, secondValue)
            let lowerBound = min(firstValue, secondValue)

            return testPoint >= lowerBound && testPoint <= upperBound

        }

        for edge in edges {
            if edge.start.y <= testPoint.y && edge.end.y >= testPoint.y {
                let position = self.position(of: testPoint, relatativeToLine: edge)

                if position == .left {
                    // Mark as a valid upwards intersection
                    windingNumber += 1
                } else if position == .equal && isPointBetween(testPoint.x, edge.start.x, edge.end.x) {
                    // The point lies exactly on the boundary edge
                    return 1
                }
            } else if edge.start.y >= testPoint.y && edge.end.y <= testPoint.y {
                let position = self.position(of: testPoint, relatativeToLine: edge)

                if position == .right {
                    // Counts as a valid downward intersection
                    windingNumber -= 1
                } else if position == .equal && isPointBetween(testPoint.x, edge.start.x, edge.end.x) {
                    // The point lies exactly on the boundary edge
                    return 1
                }
            }
        }

        return windingNumber
    }

    private enum RelativePosition {
        case left, equal, right
    }

    private func position(of testPoint: CGPoint, relatativeToLine edge: Edge) -> RelativePosition {
        let result = (edge.end.x - edge.start.x) * (testPoint.y - edge.start.y) - (edge.end.y - edge.start.y) * (testPoint.x - edge.start.x)

        if result == 0 {
            return .equal
        } else if result > 0 {
            return .left
        } else {
            return .right
        }
    }

    // MARK: Calculating transforms to scale and translate a TransformableRect to fill a given bounds

    func transform(toContain rectToEnclose: CGRect) -> CGAffineTransform {
        var adaptedRect: TransformableRect = self
        var combinedTransform: CGAffineTransform = .identity

        // Translations here and inside the for loop below
        // are only used to get more accurate scaling

        // Start with a translation to avoid scaling if that is sufficient
        let initialTranslationTransform = adaptedRect.adaptiveTranslationTransform(toContain: rectToEnclose)
        combinedTransform = combinedTransform.concatenating(initialTranslationTransform)
        adaptedRect = self.applying(combinedTransform)

        let maximumNumberOfIterations = 200

        for _ in 0..<maximumNumberOfIterations where !adaptedRect.contains(rectToEnclose, approximately: true) {
            let scaleTransform = adaptedRect.scaleTransform(toContain: rectToEnclose)
            combinedTransform = combinedTransform.concatenating(scaleTransform)
            adaptedRect = self.applying(combinedTransform)

            let translationTransform = adaptedRect.adaptiveTranslationTransform(toContain: rectToEnclose)
            combinedTransform = combinedTransform.concatenating(translationTransform)
            adaptedRect = self.applying(combinedTransform)
        }

        if !adaptedRect.contains(rectToEnclose, approximately: true) {
            // Reset the translation
            combinedTransform.tx = 0.0
            combinedTransform.ty = 0.0
            adaptedRect = self.applying(combinedTransform)

            // Then do a single edge based translation
            // so we move the minimum possible amount
            let translationTransform = adaptedRect.translationTransform(toContain: rectToEnclose)
            combinedTransform = combinedTransform.concatenating(translationTransform)
            adaptedRect = self.applying(combinedTransform)
        }

        // Round the resulting transform if it's close to the identity
        let epsilon: CGFloat = 0.001

        if abs(combinedTransform.tx) < epsilon {
            combinedTransform.tx = 0
        }

        if abs(combinedTransform.ty) < epsilon {
            combinedTransform.ty = 0
        }

        return combinedTransform
    }

    internal func scaleTransform(toContain rectToEnclose: CGRect) -> CGAffineTransform {
        let originTransform = CGAffineTransform(translationX: rect.midX, y: rect.midY)

        // Scale the rectangle to fit the bounds if necessary
        let closestScale = rectToEnclose.points.filter { (point) in
            return !self.contains(point)
        }.flatMap { (point) -> (transform: CGAffineTransform, distanceBetweenIntersections: CGFloat)? in
            return self.scale(toInclude: point, inDirection: self.center, origin: originTransform)
        }.min { $0.distanceBetweenIntersections > $1.distanceBetweenIntersections }

        let transform: CGAffineTransform = closestScale?.transform ?? .identity

        // Restore the transform into view space
        let scaleTransform = transform.concatenating(originTransform.inverted())
        return scaleTransform
    }

    private func scale(toInclude point: CGPoint,
                       inDirection direction: CGPoint,
                       origin originTransform: CGAffineTransform)
                       -> (transform: CGAffineTransform, distanceBetweenIntersections: CGFloat)? {
        // Project a line from the target point through the center of the transformable rect
        let directionToScale = Edge(start: direction, end: point)

        // Find the nearest and furthest points on that line
        var possibleFurthestIntersection: CGPoint? = nil
        var distanceToFurthestIntersection: CGFloat = 0.0

        var possibleNearestIntersection: CGPoint? = nil
        var distanceToNearestIntersection: CGFloat = CGFloat.greatestFiniteMagnitude

        for edge in self.edges {
            if let intersectionPoint = directionToScale.intersection(with: edge, projectFirstLine: true, projectSecondLine: false) {
                let distance = intersectionPoint.distance(point)

                if distance > distanceToFurthestIntersection {
                    distanceToFurthestIntersection = distance
                    possibleFurthestIntersection = intersectionPoint
                }

                if distance < distanceToNearestIntersection {
                    distanceToNearestIntersection = distance
                    possibleNearestIntersection = intersectionPoint
                }
            }
        }

        guard let nearestIntersection = possibleNearestIntersection,
            let furthestIntersection = possibleFurthestIntersection else {
                return nil
        }

        let existingDistance = nearestIntersection.distance(furthestIntersection)

        if existingDistance > 1.0 {
            let desiredDistance = furthestIntersection.distance(point)

            // Dividing the length from the furthest point to the target point
            // by the length from the furthest point to the nearest point
            // gives us the amount to scale by
            let scale = desiredDistance / existingDistance

            if abs(scale - 1.0) > 0.005 {
                // Then scale by that amount from the furthest point
                let anchorPoint = furthestIntersection.applying(originTransform.inverted())
                let scaleTransform = CGAffineTransform.identity.scaledBy(x: scale, y: scale, fromAnchorPoint: anchorPoint)
                return (scaleTransform, existingDistance)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    private func adaptiveTranslationTransform(toContain rectToEnclose: CGRect) -> CGAffineTransform {
        if isAbleToBeTranslated(toContain: rectToEnclose, approximately: true) || transform.scale > 1.0 {
            // Use the nearest edge method to fit the target rect
            return translationTransform(toContain: rectToEnclose)
        } else {
            // If the current transform wouldn't fill the current area then simply
            // move it towards the center, to avoid snapping to an incorrect edge
            return translationTransformTowardsCenter(of: rectToEnclose)
        }
    }

    public func translationTransform(toContain rectToEnclose: CGRect) -> CGAffineTransform {
        // Use the nearest edge method to fit the target rect
        var translationTransform: CGAffineTransform = .identity
        var adaptedRect = self

        // Translate the rectangle to fit the target rect if necessary
        for _ in 0..<4 {
            for point in rectToEnclose.interleavedPoints where !adaptedRect.contains(point) {
                let nearestPoint = adaptedRect.nearestPoint(to: point)
                let translationVector = point - nearestPoint

                translationTransform = translationTransform.translatedBy(x: translationVector.x, y: translationVector.y)
                adaptedRect.transform = self.transform.concatenating(translationTransform)
            }
        }

        return translationTransform
    }

    private func translationTransformTowardsCenter(of targetRect: CGRect) -> CGAffineTransform {
        let translation = -(self.center - targetRect.center) * 0.1

        return CGAffineTransform(translationX: translation.x, y: translation.y)
    }

    private func isAbleToBeTranslated(toContain rectToEnclose: CGRect, approximately: Bool = false) -> Bool {
        var adaptedRect = self

        // Set the translation to zero
        var transform = adaptedRect.transform
        transform.tx = 0.0
        transform.ty = 0.0
        adaptedRect.transform = transform

        let centeredTargetRect = rectToEnclose.centered(on: .zero)

        return adaptedRect.contains(centeredTargetRect, approximately: approximately)
    }

    internal func furthestEdge(from point: CGPoint) -> Edge {
        // Force unwrapping here seems fine
        // as a rectangle will always have 4 edges
        var furthestEdge: Edge = edges[0]
        var furthestDistance: CGFloat = 0.0

        for edge in edges {
            let distance = edge.distanceSquared(from: point)

            if distance > furthestDistance {
                furthestEdge = edge
                furthestDistance = distance
            }
        }

        return furthestEdge
    }

    internal func nearestEdge(to point: CGPoint) -> Edge {
        let edges = self.edges

        // Force unwrapping here seems fine
        // as a rectangle will always have 4 edges
        var nearestEdge: Edge = edges[0]
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for edge in edges {
            let distance = edge.distanceSquared(from: point)

            if distance < nearestDistance {
                nearestEdge = edge
                nearestDistance = distance
            }
        }

        return nearestEdge
    }

    internal func nearestPoint(to point: CGPoint) -> CGPoint {
        var nearestPoint: CGPoint = points.first!
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for edge in edges {
            let nearbyPoint = edge.nearestPoint(to: point)
            let distance = nearbyPoint.distance(point)

            if distance < nearestDistance {
                nearestDistance = distance
                nearestPoint = nearbyPoint
            }
        }

        return nearestPoint
    }
}

internal extension TransformableRect.Edge {

    internal func intersection(with secondLine: TransformableRect.Edge, projectFirstLine: Bool, projectSecondLine: Bool) -> CGPoint? {
        // Ref: https://stackoverflow.com/questions/15690103/intersection-between-two-lines-in-coordinates
        // Specifically: https://stackoverflow.com/a/45931831
        let l1 = self
        let l2 = secondLine

        let distance = (l1.end.x - l1.start.x) * (l2.end.y - l2.start.y) - (l1.end.y - l1.start.y) * (l2.end.x - l2.start.x)

        if distance == 0 {
            // The lines are exactly parallel
            return nil
        }

        let u = ((l2.start.x - l1.start.x) * (l2.end.y - l2.start.y) - (l2.start.y - l1.start.y) * (l2.end.x - l2.start.x)) / distance
        let v = ((l2.start.x - l1.start.x) * (l1.end.y - l1.start.y) - (l2.start.y - l1.start.y) * (l1.end.x - l1.start.x)) / distance

        if (u < 0.0 || u > 1.0) && !projectFirstLine {
            return nil
        } else if (v < 0.0 || v > 1.0) && !projectSecondLine {
            return nil
        }

        return CGPoint(x: l1.start.x + u * (l1.end.x - l1.start.x), y: l1.start.y + u * (l1.end.y - l1.start.y))
    }

    internal func nearestPoint(to point: CGPoint) -> CGPoint {
        // Ref: https://stackoverflow.com/a/9557244
        let a = start
        let b = end
        let p = point
        let ap = p - a      // Vector from A to P
        let ab = b - a      // Vector from A to B

        // Get the normalized distance from a to the closest point
        let distance = ap.dotProduct(ab) / ab.lengthSquared
        let validDistance = clamp(distance, between: 0.0, and: 1.0)
        return a + ab * validDistance
    }

    internal func distanceSquared(from point: CGPoint) -> CGFloat {
        let startDistance = start.distance(point)
        let endDistance = end.distance(point)

        return (startDistance * startDistance) + (endDistance * endDistance)
    }

}
