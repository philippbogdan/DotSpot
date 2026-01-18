//
// iPhoneStreamSessionView.swift
//
// Stream view for iPhone camera mode.
//

import SwiftUI
import UIKit

struct iPhoneStreamSessionView: View {
  @StateObject private var viewModel = iPhoneStreamSessionViewModel()

  var body: some View {
    ZStack {
      if viewModel.isStreaming {
        iPhoneStreamView(viewModel: viewModel)
      } else {
        iPhoneNonStreamView(viewModel: viewModel)
      }
    }
    .alert("Error", isPresented: $viewModel.showError) {
      Button("OK") {
        viewModel.dismissError()
      }
    } message: {
      Text(viewModel.errorMessage)
    }
  }
}

struct iPhoneNonStreamView: View {
  @ObservedObject var viewModel: iPhoneStreamSessionViewModel
  @ObservedObject var inputSourceManager = InputSourceManager.shared

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)

      VStack {
        // Back button
        HStack {
          Button(action: {
            inputSourceManager.reset()
          }) {
            HStack(spacing: 4) {
              Image(systemName: "chevron.left")
              Text("Back")
            }
            .foregroundColor(.white)
          }
          Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)

        Spacer()

        VStack(spacing: 24) {
          ZStack {
            Circle()
              .fill(Color.white)
              .frame(width: 160, height: 160)

            Text("DotSpot")
              .font(.system(size: 24, weight: .bold))
              .foregroundColor(.black)
          }

          Text("Point at objects to identify them")
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.7))
        }

        Spacer()

        CustomButton(
          title: "Start",
          style: .primary,
          isDisabled: false
        ) {
          Task {
            await viewModel.handleStartStreaming()
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
      }
    }
  }
}

struct iPhoneStreamView: View {
  @ObservedObject var viewModel: iPhoneStreamSessionViewModel
  @StateObject private var dotSpotViewModel = DotSpotViewModel()
  @ObservedObject var inputSourceManager = InputSourceManager.shared

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)

      // Video backdrop
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          ZStack {
            Image(uiImage: videoFrame)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: geometry.size.width, height: geometry.size.height)
              .clipped()
              .accessibilityLabel("Live video from iPhone camera")
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
          .accessibilityLabel("Starting camera")
      }

      // Top: Toggles
      VStack {
        HStack(spacing: 12) {
          // DotSpot toggle
          ToggleButton(
            title: "DotSpot",
            isOn: $dotSpotViewModel.isEnabled
          )

          // Debug toggle
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

      // Bottom controls
      VStack {
        Spacer()

        HStack(spacing: 8) {
          CustomButton(
            title: "Stop",
            style: .primary,
            isDisabled: false
          ) {
            Task {
              await viewModel.stopSession()
              inputSourceManager.reset()
            }
          }

          CircleButton(
            icon: "camera.fill",
            text: nil,
            accessibilityLabel: "Capture photo",
            accessibilityHint: "Takes a photo"
          ) {
            viewModel.capturePhoto()
          }
        }
        .padding(.all, 24)
      }
    }
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
