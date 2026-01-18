//
// MainAppView.swift
//
// Central navigation hub that displays different views based on input source selection.
// Supports both iPhone camera and Meta glasses modes.
//

import MWDATCore
import SwiftUI

struct MainAppView: View {
  let wearables: WearablesInterface
  @ObservedObject private var viewModel: WearablesViewModel
  @ObservedObject private var inputSourceManager = InputSourceManager.shared

  init(wearables: WearablesInterface, viewModel: WearablesViewModel) {
    self.wearables = wearables
    self.viewModel = viewModel
  }

  var body: some View {
    Group {
      // Check if iPhone mode is selected
      if inputSourceManager.selectedSource == .iPhone {
        iPhoneStreamSessionView()
      }
      // Check if Meta glasses are registered
      else if viewModel.registrationState == .registered || viewModel.hasMockDevice {
        StreamSessionView(wearables: wearables)
      }
      // Show home screen for source selection
      else {
        HomeScreenView(viewModel: viewModel)
      }
    }
  }
}
