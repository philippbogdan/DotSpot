//
// DotSpotAudioManager.swift
//
// Manages audio feedback for DotSpot feature:
// - Continuous low hum that fades as dwell time increases
// - Lock-on chime when object is announced
//

import AVFoundation
import Foundation

class DotSpotAudioManager: ObservableObject {
  static let shared = DotSpotAudioManager()

  private var humPlayer: AVAudioPlayer?
  private var chimePlayer: AVAudioPlayer?
  private var audioEngine: AVAudioEngine?
  private var toneNode: AVAudioSourceNode?

  @Published var isHumming = false
  @Published var currentVolume: Float = 0

  // Hum parameters
  private let humFrequency: Double = 150  // Low hum frequency in Hz
  private var phase: Double = 0
  private let sampleRate: Double = 44100

  private init() {
    setupAudioSession()
    setupToneGenerator()
  }

  private func setupAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("[DotSpotAudio] Failed to setup audio session: \(error)")
    }
  }

  private func setupToneGenerator() {
    audioEngine = AVAudioEngine()
    guard let audioEngine = audioEngine else { return }

    let mainMixer = audioEngine.mainMixerNode
    let outputFormat = mainMixer.outputFormat(forBus: 0)
    let sampleRate = outputFormat.sampleRate

    // Create tone generator node
    toneNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
      guard let self = self else { return noErr }

      let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

      for frame in 0..<Int(frameCount) {
        let value = sin(self.phase) * Double(self.currentVolume) * 0.3  // 0.3 = max amplitude
        self.phase += 2.0 * .pi * self.humFrequency / sampleRate

        if self.phase > 2.0 * .pi {
          self.phase -= 2.0 * .pi
        }

        for buffer in ablPointer {
          let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
          buf?[frame] = Float(value)
        }
      }

      return noErr
    }

    guard let toneNode = toneNode else { return }

    audioEngine.attach(toneNode)
    audioEngine.connect(toneNode, to: mainMixer, format: outputFormat)
  }

  func startHum() {
    guard let audioEngine = audioEngine, !audioEngine.isRunning else { return }

    do {
      try audioEngine.start()
      isHumming = true
    } catch {
      print("[DotSpotAudio] Failed to start audio engine: \(error)")
    }
  }

  func stopHum() {
    audioEngine?.stop()
    isHumming = false
    currentVolume = 0
    phase = 0
  }

  func setHumVolume(_ volume: Float) {
    // Clamp between 0 and 1
    currentVolume = max(0, min(1, volume))

    // Start engine if needed and volume > 0
    if volume > 0 && !(audioEngine?.isRunning ?? false) {
      startHum()
    }
  }

  func playLockOnChime() {
    // Play a short ascending chime
    playTone(frequencies: [440, 554, 659], duration: 0.1)
  }

  private func playTone(frequencies: [Double], duration: TimeInterval) {
    // Simple chime using system sound or generated tones
    // For simplicity, use AudioServicesPlaySystemSound for a click
    AudioServicesPlaySystemSound(1057)  // System click sound

    // Alternative: Generate custom chime
    DispatchQueue.global().async { [weak self] in
      for freq in frequencies {
        self?.playFrequency(freq, duration: duration)
        Thread.sleep(forTimeInterval: duration)
      }
    }
  }

  private func playFrequency(_ frequency: Double, duration: TimeInterval) {
    // This is a simplified version - in production you'd want proper audio generation
    let savedFreq = humFrequency
    // Temporarily play the chime frequency at full volume
    // (This is a placeholder - real implementation would use a separate audio node)
  }

  deinit {
    stopHum()
  }
}
