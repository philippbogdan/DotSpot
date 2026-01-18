//
// LocalObjectDetector.swift
//
// On-device YOLOv8n inference using CoreML for edge compute.
//

import CoreML
import UIKit
import Vision

@MainActor
class LocalObjectDetector: ObservableObject {
  static let shared = LocalObjectDetector()

  @Published var isModelLoaded = false
  @Published var lastInferenceTime: Double = 0

  private var model: VNCoreMLModel?
  private var request: VNCoreMLRequest?
  private var lastDetections: [Detection] = []
  private var inferenceStartTime: Date?

  private init() {
    setupModel()
  }

  private func setupModel() {
    do {
      let config = MLModelConfiguration()
      config.computeUnits = .cpuAndNeuralEngine

      // Load YOLOv8n model
      let yoloModel = try Yolov8n(configuration: config)
      model = try VNCoreMLModel(for: yoloModel.model)

      request = VNCoreMLRequest(model: model!) { [weak self] request, error in
        self?.processResults(request: request, error: error)
      }
      request?.imageCropAndScaleOption = .scaleFill

      isModelLoaded = true
      print("[LocalDetector] YOLOv8n model loaded successfully")
    } catch {
      print("[LocalDetector] Failed to load model: \(error)")
      isModelLoaded = false
    }
  }

  func detect(in image: UIImage, completion: @escaping ([Detection]) -> Void) {
    guard let cgImage = image.cgImage, let request = request else {
      completion([])
      return
    }

    inferenceStartTime = Date()

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        try handler.perform([request])

        DispatchQueue.main.async {
          if let startTime = self?.inferenceStartTime {
            self?.lastInferenceTime = Date().timeIntervalSince(startTime) * 1000
          }
          completion(self?.lastDetections ?? [])
        }
      } catch {
        print("[LocalDetector] Detection failed: \(error)")
        DispatchQueue.main.async {
          completion([])
        }
      }
    }
  }

  private func processResults(request: VNRequest, error: Error?) {
    guard let results = request.results as? [VNRecognizedObjectObservation] else {
      lastDetections = []
      return
    }

    lastDetections = results.compactMap { observation in
      guard let topLabel = observation.labels.first else { return nil }

      // VNRecognizedObjectObservation boundingBox is in normalized coordinates
      // with origin at bottom-left. Convert to top-left origin.
      let box = observation.boundingBox
      let convertedBox = CGRect(
        x: box.origin.x,
        y: 1 - box.origin.y - box.height,
        width: box.width,
        height: box.height
      )

      return Detection(
        label: topLabel.identifier,
        confidence: topLabel.confidence,
        boundingBox: convertedBox
      )
    }
  }
}
