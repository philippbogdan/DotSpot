//
// HapticManager.swift
//
// Manages haptic feedback for DotSpot feature on iPhone mode:
// - Continuous vibration that increases intensity as dwell time increases
// - Strong haptic pulse when object is announced
//

import CoreHaptics
import UIKit

class HapticManager: ObservableObject {
  static let shared = HapticManager()

  private var engine: CHHapticEngine?
  private var continuousPlayer: CHHapticAdvancedPatternPlayer?
  private var isRunning = false

  @Published var currentIntensity: Float = 0

  private init() {
    setupHapticEngine()
  }

  private func setupHapticEngine() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
      print("[Haptic] Device doesn't support haptics")
      return
    }

    do {
      engine = try CHHapticEngine()
      engine?.resetHandler = { [weak self] in
        do {
          try self?.engine?.start()
        } catch {
          print("[Haptic] Failed to restart engine: \(error)")
        }
      }
      engine?.stoppedHandler = { reason in
        print("[Haptic] Engine stopped: \(reason)")
      }
    } catch {
      print("[Haptic] Failed to create haptic engine: \(error)")
    }
  }

  func startContinuousHaptic() {
    guard let engine = engine, !isRunning else { return }

    do {
      try engine.start()
      isRunning = true

      // Create a continuous haptic pattern
      let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
      let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)

      let event = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [intensity, sharpness],
        relativeTime: 0,
        duration: 100  // Long duration, we'll stop it manually
      )

      let pattern = try CHHapticPattern(events: [event], parameters: [])
      continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
      try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
    } catch {
      print("[Haptic] Failed to start continuous haptic: \(error)")
    }
  }

  func stopContinuousHaptic() {
    do {
      try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
    } catch {
      print("[Haptic] Failed to stop continuous haptic: \(error)")
    }
    isRunning = false
    currentIntensity = 0
  }

  func setIntensity(_ intensity: Float) {
    currentIntensity = max(0, min(1, intensity))

    guard isRunning, let continuousPlayer = continuousPlayer else {
      if intensity > 0 {
        startContinuousHaptic()
      }
      return
    }

    // Update the intensity dynamically
    let intensityParam = CHHapticDynamicParameter(
      parameterID: .hapticIntensityControl,
      value: currentIntensity,
      relativeTime: 0
    )

    do {
      try continuousPlayer.sendParameters([intensityParam], atTime: CHHapticTimeImmediate)
    } catch {
      print("[Haptic] Failed to update intensity: \(error)")
    }
  }

  func playLockOnHaptic() {
    // Strong success haptic
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)

    // Also play a custom strong pulse
    guard let engine = engine else { return }

    do {
      try engine.start()

      let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
      let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)

      let event = CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [sharpness, intensity],
        relativeTime: 0
      )

      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      print("[Haptic] Failed to play lock-on haptic: \(error)")
    }
  }

  deinit {
    stopContinuousHaptic()
    engine?.stop()
  }
}
