//
// ObjectDetector.swift
//
// Detection model - now using remote inference via RemoteObjectDetector.
// This file just defines the Detection struct used by both local and remote detection.
//

import Foundation

struct Detection {
  let label: String
  let confidence: Float
  let boundingBox: CGRect  // Normalized coordinates (0-1)
}
