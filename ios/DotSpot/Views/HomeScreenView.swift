//
// HomeScreenView.swift
//
// Welcome screen that guides users through the DAT SDK registration process.
// This view is displayed when the app is not yet registered.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel

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

        VStack(spacing: 20) {
          Text("You'll be redirected to the Meta AI app to confirm your connection.")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)

          CustomButton(
            title: viewModel.registrationState == .registering ? "Connecting..." : "Connect my glasses",
            style: .primary,
            isDisabled: viewModel.registrationState == .registering
          ) {
            viewModel.connectGlasses()
          }
          .accessibilityHint("Opens Meta AI app to authorize connection")
        }
      }
      .padding(.all, 24)
    }
  }

}
