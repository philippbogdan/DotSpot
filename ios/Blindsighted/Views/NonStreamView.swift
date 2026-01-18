//
// NonStreamView.swift
//
// Default screen to show getting started tips after app connection
// Initiates streaming
//

import MWDATCore
import SwiftUI

struct NonStreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)

      VStack {
        Spacer()

        VStack(spacing: 24) {
          // White circle with DotSpot text
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

        HStack(spacing: 8) {
          Image(systemName: "hourglass")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.white.opacity(0.7))
            .frame(width: 16, height: 16)

          Text("Waiting for an active device")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 12)
        .opacity(viewModel.hasActiveDevice ? 0 : 1)
        .accessibilityHidden(viewModel.hasActiveDevice)

        CustomButton(
          title: "Start",
          style: .primary,
          isDisabled: !viewModel.hasActiveDevice
        ) {
          Task {
            await viewModel.handleStartStreaming()
          }
        }
        .accessibilityHint("Starts the camera stream from your glasses")
      }
      .padding(.all, 24)
    }
  }
}

