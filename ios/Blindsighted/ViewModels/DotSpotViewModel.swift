//
// DotSpotViewModel.swift
//
// Main view model for DotSpot feature.
// Manages object detection, tracking, dwell timing, and announcements.
//

import Combine
import SwiftUI
import UIKit

@MainActor
class DotSpotViewModel: ObservableObject {
  // MARK: - Published State

  @Published var isEnabled = false {
    didSet {
      if isEnabled && !isConnected {
        connectToServer()
      } else if !isEnabled {
        reset()
      }
    }
  }
  @Published var isDebugMode = false
  @Published var trackedObjects: [TrackedObject] = []
  @Published var currentPointedObject: TrackedObject?
  @Published var dwellProgress: Double = 0  // 0-1, for UI feedback
  @Published var detectionCount: Int = 0  // Debug: number of detections run
  @Published var inferenceTime: Double = 0  // Debug: last inference time in ms
  @Published var isConnected = false  // Remote server connection status

  // MARK: - Configuration

  // Your laptop's IP address
  static let serverURL = "ws://10.154.18.227:8765"

  // MARK: - Private Properties

  private let remoteDetector = RemoteObjectDetector.shared
  private let objectTracker = ObjectTracker()
  private let speechManager = SpeechManager.shared
  private let audioManager = DotSpotAudioManager.shared

  private var lastProcessedTime: Date?
  private var lastAnnouncedObjectId: UUID?
  private var frameCounter = 0
  private var isProcessingFrame = false
  private var cancellables = Set<AnyCancellable>()

  // Detection runs at 5 FPS (every 6th frame at 30fps)
  private let detectionInterval = 6

  // Dwell time required for announcement (2 seconds)
  private let requiredDwellTime: TimeInterval = 2.0

  init() {
    // Observe remote detector connection status
    remoteDetector.$isConnected
      .receive(on: DispatchQueue.main)
      .assign(to: &$isConnected)

    remoteDetector.$lastInferenceTime
      .receive(on: DispatchQueue.main)
      .assign(to: &$inferenceTime)
  }

  // MARK: - Public Methods

  func processFrame(_ image: UIImage) {
    guard isEnabled else { return }
    guard !isProcessingFrame else { return }  // Skip if still processing previous frame

    frameCounter += 1

    // Only run detection every N frames (5 FPS at 30fps input)
    guard frameCounter % detectionInterval == 0 else {
      // Still update dwell time between detections
      updateDwellTimeBetweenDetections()
      return
    }

    let now = Date()
    let deltaTime: TimeInterval
    if let lastTime = lastProcessedTime {
      deltaTime = now.timeIntervalSince(lastTime)
    } else {
      deltaTime = 0.2  // First frame, assume 5 FPS
    }
    lastProcessedTime = now

    // Run remote object detection
    isProcessingFrame = true
    remoteDetector.detect(in: image) { [weak self] detections in
      guard let self = self else { return }

      self.isProcessingFrame = false
      self.detectionCount += 1

      if !detections.isEmpty {
        print("[DotSpot] Frame \(self.detectionCount): Found \(detections.count) objects - \(detections.map { $0.label }.joined(separator: ", "))")
      }

      // Update tracker
      self.trackedObjects = self.objectTracker.update(detections: detections, deltaTime: deltaTime)

      // Find object at pointer (center + 0.1 down = 0.6 y)
      let centerPoint = CGPoint(x: 0.5, y: 0.6)
      let pointedObject = self.objectTracker.findObjectAtCenter(centerPoint: centerPoint)

      self.handlePointedObject(pointedObject, deltaTime: deltaTime)
    }
  }

  func connectToServer() {
    remoteDetector.connect(to: Self.serverURL)
  }

  func disconnectFromServer() {
    remoteDetector.disconnect()
  }

  func reset() {
    objectTracker.reset()
    trackedObjects = []
    currentPointedObject = nil
    dwellProgress = 0
    lastAnnouncedObjectId = nil
    lastProcessedTime = nil
    frameCounter = 0
    isProcessingFrame = false
    audioManager.stopHum()
  }


  // MARK: - Private Methods

  private func updateDwellTimeBetweenDetections() {
    // Approximate time between frames at 30fps
    let frameDelta: TimeInterval = 1.0 / 30.0

    if let current = currentPointedObject {
      objectTracker.updateDwellTime(for: current.id, deltaTime: frameDelta)

      // Update UI
      if let updated = objectTracker.getObject(by: current.id) {
        currentPointedObject = updated
        updateDwellProgress(updated)
        updateAudioFeedback(updated)
      }
    }
  }

  private func handlePointedObject(_ pointed: TrackedObject?, deltaTime: TimeInterval) {
    let previousObject = currentPointedObject

    if let pointed = pointed {
      // Check if this is the same object we were pointing at
      if let previous = previousObject, previous.id == pointed.id {
        // Same object - update dwell time
        objectTracker.updateDwellTime(for: pointed.id, deltaTime: deltaTime)

        if let updated = objectTracker.getObject(by: pointed.id) {
          currentPointedObject = updated
          updateDwellProgress(updated)
          updateAudioFeedback(updated)
          checkForAnnouncement(updated)
        }
      } else {
        // Different object - check if it was already announced
        if pointed.id == lastAnnouncedObjectId {
          // Coming back to announced object - silence, no hum
          currentPointedObject = pointed
          dwellProgress = 1.0
          audioManager.setHumVolume(0)
        } else {
          // New object - start fresh
          currentPointedObject = pointed
          objectTracker.resetDwellTime(for: pointed.id)
          dwellProgress = 0
          audioManager.setHumVolume(1.0)
          audioManager.startHum()
        }
      }
    } else {
      // No object pointed at
      currentPointedObject = nil
      dwellProgress = 0
      audioManager.setHumVolume(0)
    }
  }

  private func updateDwellProgress(_ object: TrackedObject) {
    if object.wasAnnounced || object.id == lastAnnouncedObjectId {
      dwellProgress = 1.0
    } else {
      dwellProgress = min(1.0, object.dwellTime / requiredDwellTime)
    }
  }

  private func updateAudioFeedback(_ object: TrackedObject) {
    if object.wasAnnounced || object.id == lastAnnouncedObjectId {
      // Already announced - silence
      audioManager.setHumVolume(0)
    } else {
      // Hum volume decreases as dwell time increases
      let volume = Float(1.0 - dwellProgress)
      audioManager.setHumVolume(volume)
    }
  }

  private func checkForAnnouncement(_ object: TrackedObject) {
    // Don't re-announce
    guard !object.wasAnnounced, object.id != lastAnnouncedObjectId else { return }

    // Check if dwell time reached threshold
    guard object.dwellTime >= requiredDwellTime else { return }

    // Announce!
    announceObject(object)
  }

  private func announceObject(_ object: TrackedObject) {
    // Stop hum
    audioManager.stopHum()

    // Play lock-on chime
    audioManager.playLockOnChime()

    // Mark as announced
    objectTracker.markAsAnnounced(objectId: object.id)
    lastAnnouncedObjectId = object.id

    // Update local state
    if let updated = objectTracker.getObject(by: object.id) {
      currentPointedObject = updated
    }
    dwellProgress = 1.0

    // Speak the label
    let label = formatLabel(object.label)
    speechManager.speak(label)
  }

  private func formatLabel(_ label: String) -> String {
    // Convert YOLO labels to natural speech
    // e.g., "cell_phone" -> "cell phone"
    label.replacingOccurrences(of: "_", with: " ")
  }
}
