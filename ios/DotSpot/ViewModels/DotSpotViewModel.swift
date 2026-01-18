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
  @Published var isEdgeComputeEnabled = false  // Use on-device YOLOv8n instead of server
  @Published var trackedObjects: [TrackedObject] = []
  @Published var currentPointedObject: TrackedObject?
  @Published var dwellProgress: Double = 0  // 0-1, for UI feedback
  @Published var detectionCount: Int = 0  // Debug: number of detections run
  @Published var inferenceTime: Double = 0  // Debug: last inference time in ms
  @Published var isConnected = false  // Remote server connection status
  @Published var isUsingEdgeCompute = false  // Actually using edge compute right now

  // MARK: - Configuration

  // Your laptop's IP address
  static let serverURL = "ws://172.20.10.2:8765"

  // MARK: - Private Properties

  private let remoteDetector = RemoteObjectDetector.shared
  private let localDetector = LocalObjectDetector.shared
  private let objectTracker = ObjectTracker()
  private let speechManager = SpeechManager.shared
  private let audioManager = DotSpotAudioManager.shared
  private let hapticManager = HapticManager.shared

  // Use haptics instead of audio for iPhone mode
  private var useHaptics: Bool {
    InputSourceManager.shared.selectedSource == .iPhone
  }

  private var lastProcessedTime: Date?
  private var lastAnnouncedObjectId: UUID?
  private var frameCounter = 0
  private var isProcessingFrame = false
  private var cancellables = Set<AnyCancellable>()

  // Detection runs at 10 FPS (every 3rd frame at 30fps)
  private let detectionInterval = 3

  // Dwell time required for announcement (1 second)
  private let requiredDwellTime: TimeInterval = 1.0

  init() {
    // Observe remote detector connection status
    remoteDetector.$isConnected
      .receive(on: DispatchQueue.main)
      .sink { [weak self] connected in
        self?.isConnected = connected
        // Update which detector is being used
        self?.updateDetectorMode()
      }
      .store(in: &cancellables)

    // Observe inference times from both detectors
    remoteDetector.$lastInferenceTime
      .receive(on: DispatchQueue.main)
      .sink { [weak self] time in
        if self?.isUsingEdgeCompute == false {
          self?.inferenceTime = time
        }
      }
      .store(in: &cancellables)

    localDetector.$lastInferenceTime
      .receive(on: DispatchQueue.main)
      .sink { [weak self] time in
        if self?.isUsingEdgeCompute == true {
          self?.inferenceTime = time
        }
      }
      .store(in: &cancellables)
  }

  private func updateDetectorMode() {
    // Server takes priority when connected
    // Edge compute only used when enabled AND not connected to server
    isUsingEdgeCompute = isEdgeComputeEnabled && !isConnected
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

    // Run object detection (local or remote based on mode)
    isProcessingFrame = true

    let handleDetections: ([Detection]) -> Void = { [weak self] detections in
      guard let self = self else { return }

      self.isProcessingFrame = false
      self.detectionCount += 1

      if !detections.isEmpty {
        let mode = self.isUsingEdgeCompute ? "Edge" : "Server"
        print("[DotSpot/\(mode)] Frame \(self.detectionCount): Found \(detections.count) objects - \(detections.map { $0.label }.joined(separator: ", "))")
      }

      // Update tracker
      self.trackedObjects = self.objectTracker.update(detections: detections, deltaTime: deltaTime)

      // Find object at pointer (center + 0.1 down = 0.6 y)
      // Circle radius normalized to frame size (80px targeting circle)
      let centerPoint = CGPoint(x: 0.5, y: 0.6)
      let targetingCircleSize: CGFloat = 80
      let circleRadius = targetingCircleSize / max(image.size.width, image.size.height)
      let pointedObject = self.objectTracker.findObjectAtCenter(centerPoint: centerPoint, circleRadius: circleRadius)

      self.handlePointedObject(pointedObject, deltaTime: deltaTime)
    }

    if isUsingEdgeCompute {
      // Use on-device YOLOv8n
      localDetector.detect(in: image, completion: handleDetections)
    } else {
      // Use remote server
      remoteDetector.detect(in: image, completion: handleDetections)
    }
  }

  func connectToServer() {
    remoteDetector.connect(to: Self.serverURL)
  }

  func disconnectFromServer() {
    remoteDetector.disconnect()
  }

  func setEdgeComputeEnabled(_ enabled: Bool) {
    isEdgeComputeEnabled = enabled
    updateDetectorMode()
  }

  var canToggleEdgeCompute: Bool {
    // Can only toggle edge compute when not connected to server
    !isConnected
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
    if useHaptics {
      hapticManager.stopContinuousHaptic()
    } else {
      audioManager.stopHum()
    }
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
          // Coming back to announced object - silence, no feedback
          currentPointedObject = pointed
          dwellProgress = 1.0
          if useHaptics {
            hapticManager.setIntensity(0)
          } else {
            audioManager.setHumVolume(0)
          }
        } else {
          // New object - start fresh and clear previous announcement memory
          // This allows re-announcing objects after looking at something else
          lastAnnouncedObjectId = nil
          objectTracker.clearAnnouncedFlag(for: pointed.id)

          currentPointedObject = pointed
          objectTracker.resetDwellTime(for: pointed.id)
          dwellProgress = 0
          if useHaptics {
            hapticManager.setIntensity(1.0)
            hapticManager.startContinuousHaptic()
          } else {
            audioManager.setHumVolume(1.0)
            audioManager.startHum()
          }
        }
      }
    } else {
      // No object pointed at
      currentPointedObject = nil
      dwellProgress = 0
      if useHaptics {
        hapticManager.setIntensity(0)
      } else {
        audioManager.setHumVolume(0)
      }
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
      if useHaptics {
        hapticManager.setIntensity(0)
      } else {
        audioManager.setHumVolume(0)
      }
    } else {
      // Feedback intensity increases as dwell time increases (opposite of audio which decreases)
      if useHaptics {
        let intensity = Float(dwellProgress)  // Intensity increases with dwell
        hapticManager.setIntensity(intensity)
      } else {
        // Audio volume decreases as dwell time increases
        let volume = Float(1.0 - dwellProgress)
        audioManager.setHumVolume(volume)
      }
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
    // Stop feedback
    if useHaptics {
      hapticManager.stopContinuousHaptic()
      // Play lock-on haptic
      hapticManager.playLockOnHaptic()
    } else {
      audioManager.stopHum()
      // Play lock-on chime
      audioManager.playLockOnChime()
    }

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
