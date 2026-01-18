//
// HomeScreenView.swift
//
// Welcome screen that lets users choose between iPhone camera or Meta glasses.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel
  @ObservedObject var inputSourceManager = InputSourceManager.shared

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)

      VStack(spacing: 24) {
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

        VStack(spacing: 16) {
          Text("Choose your camera source")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.5))

          HStack(spacing: 16) {
            // iPhone button
            SourceButton(
              icon: "iphone",
              title: "iPhone",
              isLoading: false
            ) {
              inputSourceManager.selectiPhone()
            }

            // Meta Glasses button
            SourceButton(
              icon: "eyeglasses",
              title: "Glasses",
              isLoading: viewModel.registrationState == .registering
            ) {
              viewModel.connectGlasses()
            }
          }
        }
      }
      .padding(.all, 24)
    }
  }
}

struct SourceButton: View {
  let icon: String
  let title: String
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .black))
            .frame(width: 40, height: 40)
        } else {
          Image(systemName: icon)
            .font(.system(size: 32))
            .foregroundColor(.black)
            .frame(width: 40, height: 40)
        }

        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.black)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .background(Color.white)
      .cornerRadius(16)
    }
    .disabled(isLoading)
    .accessibilityLabel("\(title) camera")
    .accessibilityHint("Use \(title) as your camera source")
  }
}
