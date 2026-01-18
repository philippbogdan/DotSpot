//
// SpeechManager.swift
//
// Text-to-speech manager for announcing detected objects.
//

import AVFoundation

class SpeechManager: NSObject, ObservableObject {
  static let shared = SpeechManager()

  private let synthesizer = AVSpeechSynthesizer()
  @Published var isSpeaking = false

  private override init() {
    super.init()
    synthesizer.delegate = self
  }

  func speak(_ text: String) {
    // Stop any current speech
    if synthesizer.isSpeaking {
      synthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    utterance.pitchMultiplier = 1.0
    utterance.volume = 1.0

    // Use a clear voice
    if let voice = AVSpeechSynthesisVoice(language: "en-US") {
      utterance.voice = voice
    }

    isSpeaking = true
    synthesizer.speak(utterance)
  }

  func stop() {
    synthesizer.stopSpeaking(at: .immediate)
    isSpeaking = false
  }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.async {
      self.isSpeaking = false
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    DispatchQueue.main.async {
      self.isSpeaking = false
    }
  }
}
