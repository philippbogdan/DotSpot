//
// iPhoneStreamSessionViewModel.swift
//
// View model for streaming from iPhone camera instead of Meta glasses.
//

import SwiftUI
import UIKit
import Combine

@MainActor
class iPhoneStreamSessionViewModel: ObservableObject {
  @Published var currentVideoFrame: UIImage?
  @Published var hasReceivedFirstFrame: Bool = false
  @Published var isStreaming: Bool = false
  @Published var showError: Bool = false
  @Published var errorMessage: String = ""
  @Published var hasActiveDevice: Bool = true  // iPhone is always available

  // Photo capture (simplified - just saves current frame)
  @Published var capturedPhoto: UIImage?
  @Published var showPhotoPreview: Bool = false

  // LiveKit not used for iPhone mode
  var isLiveKitConnected: Bool = false
  var isMicrophoneMuted: Bool = false
  var recordingDuration: TimeInterval = 0

  private let cameraManager = iPhoneCameraManager()
  private var cancellables = Set<AnyCancellable>()

  init() {
    // Subscribe to camera frames
    cameraManager.$currentFrame
      .receive(on: DispatchQueue.main)
      .sink { [weak self] frame in
        guard let self = self, let frame = frame else { return }
        self.currentVideoFrame = frame
        if !self.hasReceivedFirstFrame {
          self.hasReceivedFirstFrame = true
        }
      }
      .store(in: &cancellables)
  }

  func handleStartStreaming() async {
    do {
      try await cameraManager.startCapture()
      isStreaming = true
    } catch {
      showError = true
      errorMessage = "Failed to start camera: \(error.localizedDescription)"
    }
  }

  func stopSession() async {
    cameraManager.stopCapture()
    isStreaming = false
    hasReceivedFirstFrame = false
    currentVideoFrame = nil
  }

  func capturePhoto() {
    if let frame = currentVideoFrame {
      capturedPhoto = frame
      showPhotoPreview = true
    }
  }

  func dismissPhotoPreview() {
    showPhotoPreview = false
    capturedPhoto = nil
  }

  func dismissError() {
    showError = false
    errorMessage = ""
  }

  // Stub for LiveKit toggle (not used in iPhone mode)
  func toggleMicrophone() async {}
}
