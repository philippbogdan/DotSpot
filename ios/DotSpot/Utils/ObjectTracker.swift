//
// ObjectTracker.swift
//
// Tracks objects across frames using IoU and centroid matching.
// Assigns persistent IDs to detected objects.
//

import Foundation
import CoreGraphics

struct TrackedObject: Identifiable {
  let id: UUID
  var label: String
  var boundingBox: CGRect
  var confidence: Float
  var lastSeenFrame: Int
  var dwellTime: TimeInterval
  var wasAnnounced: Bool

  var center: CGPoint {
    CGPoint(
      x: boundingBox.midX,
      y: boundingBox.midY
    )
  }
}

class ObjectTracker {
  private(set) var trackedObjects: [TrackedObject] = []
  private var currentFrame: Int = 0

  // Matching thresholds
  private let iouThreshold: CGFloat = 0.3
  private let centroidDistanceThreshold: CGFloat = 0.1  // Normalized (10% of frame)
  private let maxFramesUnseen: Int = 5  // 5 frames at 5 FPS = 1 second

  func update(detections: [Detection], deltaTime: TimeInterval) -> [TrackedObject] {
    currentFrame += 1

    var matchedDetectionIndices = Set<Int>()
    var matchedTrackedIndices = Set<Int>()

    // Match existing tracked objects to new detections
    for (trackedIndex, tracked) in trackedObjects.enumerated() {
      var bestMatchIndex: Int?
      var bestIoU: CGFloat = 0

      for (detectionIndex, detection) in detections.enumerated() {
        guard !matchedDetectionIndices.contains(detectionIndex) else { continue }
        guard detection.label == tracked.label else { continue }

        let iou = calculateIoU(tracked.boundingBox, detection.boundingBox)
        let centroidDist = calculateCentroidDistance(tracked.boundingBox, detection.boundingBox)

        if iou > iouThreshold || centroidDist < centroidDistanceThreshold {
          if iou > bestIoU {
            bestIoU = iou
            bestMatchIndex = detectionIndex
          }
        }
      }

      if let matchIndex = bestMatchIndex {
        matchedDetectionIndices.insert(matchIndex)
        matchedTrackedIndices.insert(trackedIndex)

        // Update tracked object with new position
        let detection = detections[matchIndex]
        trackedObjects[trackedIndex].boundingBox = detection.boundingBox
        trackedObjects[trackedIndex].confidence = detection.confidence
        trackedObjects[trackedIndex].lastSeenFrame = currentFrame
      }
    }

    // Create new tracked objects for unmatched detections
    for (index, detection) in detections.enumerated() {
      guard !matchedDetectionIndices.contains(index) else { continue }

      let newTracked = TrackedObject(
        id: UUID(),
        label: detection.label,
        boundingBox: detection.boundingBox,
        confidence: detection.confidence,
        lastSeenFrame: currentFrame,
        dwellTime: 0,
        wasAnnounced: false
      )
      trackedObjects.append(newTracked)
    }

    // Remove objects that haven't been seen for too long
    trackedObjects.removeAll { tracked in
      currentFrame - tracked.lastSeenFrame > maxFramesUnseen
    }

    return trackedObjects
  }

  func updateDwellTime(for objectId: UUID, deltaTime: TimeInterval) {
    if let index = trackedObjects.firstIndex(where: { $0.id == objectId }) {
      trackedObjects[index].dwellTime += deltaTime
    }
  }

  func pauseDwellTime(for objectId: UUID) {
    // Dwell time is paused by not updating it - nothing to do
  }

  func markAsAnnounced(objectId: UUID) {
    if let index = trackedObjects.firstIndex(where: { $0.id == objectId }) {
      trackedObjects[index].wasAnnounced = true
    }
  }

  func resetDwellTime(for objectId: UUID) {
    if let index = trackedObjects.firstIndex(where: { $0.id == objectId }) {
      trackedObjects[index].dwellTime = 0
    }
  }

  func getObject(by id: UUID) -> TrackedObject? {
    trackedObjects.first { $0.id == id }
  }

  func findObjectAtCenter(centerPoint: CGPoint) -> TrackedObject? {
    // Find all objects whose bounding box contains the center point
    let candidates = trackedObjects.filter { $0.boundingBox.contains(centerPoint) }

    // Return the smallest one (most specific/innermost object)
    return candidates.min { a, b in
      let areaA = a.boundingBox.width * a.boundingBox.height
      let areaB = b.boundingBox.width * b.boundingBox.height
      return areaA < areaB
    }
  }

  func reset() {
    trackedObjects = []
    currentFrame = 0
  }

  // MARK: - Private Helpers

  private func calculateIoU(_ box1: CGRect, _ box2: CGRect) -> CGFloat {
    let intersection = box1.intersection(box2)

    guard !intersection.isNull else { return 0 }

    let intersectionArea = intersection.width * intersection.height
    let unionArea = box1.width * box1.height + box2.width * box2.height - intersectionArea

    guard unionArea > 0 else { return 0 }

    return intersectionArea / unionArea
  }

  private func calculateCentroidDistance(_ box1: CGRect, _ box2: CGRect) -> CGFloat {
    let center1 = CGPoint(x: box1.midX, y: box1.midY)
    let center2 = CGPoint(x: box2.midX, y: box2.midY)

    let dx = center1.x - center2.x
    let dy = center1.y - center2.y

    return sqrt(dx * dx + dy * dy)
  }
}
