//
// InputSourceManager.swift
//
// Manages the input source selection (iPhone camera vs Meta glasses)
//

import SwiftUI

enum InputSource {
  case iPhone
  case metaGlasses
}

@MainActor
class InputSourceManager: ObservableObject {
  static let shared = InputSourceManager()

  @Published var selectedSource: InputSource?
  @Published var isSourceSelected: Bool = false

  private init() {}

  func selectiPhone() {
    selectedSource = .iPhone
    isSourceSelected = true
  }

  func selectMetaGlasses() {
    selectedSource = .metaGlasses
    isSourceSelected = true
  }

  func reset() {
    selectedSource = nil
    isSourceSelected = false
  }
}
