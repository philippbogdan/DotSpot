//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, photo capture,
// and error handling.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @StateObject private var dotSpotViewModel = DotSpotViewModel()

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          ZStack {
            Image(uiImage: videoFrame)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: geometry.size.width, height: geometry.size.height)
              .accessibilityLabel("Live video stream from glasses")
              .accessibilityAddTraits(.isImage)

            // DotSpot overlay
            if dotSpotViewModel.isEnabled {
              DotSpotOverlayView(
                viewModel: dotSpotViewModel,
                frameSize: geometry.size
              )
            }
          }
          .onChange(of: viewModel.currentVideoFrame) { _, newFrame in
            if let frame = newFrame {
              dotSpotViewModel.processFrame(frame)
            }
          }
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
          .accessibilityLabel("Waiting for video stream")
      }

      // Top: Toggles
      VStack {
        HStack(spacing: 12) {
          // DotSpot toggle
          ToggleButton(
            title: "DotSpot",
            isOn: $dotSpotViewModel.isEnabled
          )

          // Debug toggle (only show when DotSpot is on)
          if dotSpotViewModel.isEnabled {
            ToggleButton(
              title: "Debug",
              isOn: $dotSpotViewModel.isDebugMode
            )
          }

          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)

        Spacer()
      }

      // Bottom controls layer
      VStack {
        Spacer()
        ControlsView(viewModel: viewModel)
      }
      .padding(.all, 24)
    }
    // Show captured photos from DAT SDK in a preview sheet
    .sheet(isPresented: $viewModel.showPhotoPreview) {
      if let photo = viewModel.capturedPhoto {
        PhotoPreviewView(
          photo: photo,
          onDismiss: {
            viewModel.dismissPhotoPreview()
          }
        )
      }
    }
    .onDisappear {
      dotSpotViewModel.reset()
    }
  }
}

struct ToggleButton: View {
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    Button(action: { isOn.toggle() }) {
      Text(title)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(isOn ? .black : .white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isOn ? Color.white : Color.white.opacity(0.2))
        .cornerRadius(20)
    }
    .accessibilityLabel("\(title) mode")
    .accessibilityValue(isOn ? "On" : "Off")
    .accessibilityHint("Double tap to toggle")
  }
}// Extracted controls for clarity
struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  var body: some View {
    // Controls row
    HStack(spacing: 8) {
      CustomButton(
        title: "Stop",
        style: .primary,
        isDisabled: false
      ) {
        Task {
          await viewModel.stopSession()
        }
      }
      .accessibilityHint("Stops the stream and returns to home screen")

      // Photo button
      CircleButton(
        icon: "camera.fill",
        text: nil,
        accessibilityLabel: "Capture photo",
        accessibilityHint: "Takes a photo from your glasses camera"
      ) {
        viewModel.capturePhoto()
      }

      // Mute button - only show when LiveKit is connected
      if viewModel.isLiveKitConnected {
        CircleButton(
          icon: viewModel.isMicrophoneMuted ? "mic.slash.fill" : "mic.fill",
          text: nil,
          accessibilityLabel: viewModel.isMicrophoneMuted ? "Unmute microphone" : "Mute microphone",
          accessibilityHint: viewModel.isMicrophoneMuted ? "Turns on your microphone" : "Turns off your microphone"
        ) {
          Task {
            await viewModel.toggleMicrophone()
          }
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Recording controls")
  }
}
