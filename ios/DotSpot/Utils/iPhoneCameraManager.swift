//
// iPhoneCameraManager.swift
//
// Captures video from the iPhone's camera for DotSpot mode.
//

import AVFoundation
import UIKit

@MainActor
class iPhoneCameraManager: NSObject, ObservableObject {
  @Published var currentFrame: UIImage?
  @Published var isRunning = false
  @Published var hasPermission = false

  private var captureSession: AVCaptureSession?
  private var videoOutput: AVCaptureVideoDataOutput?
  private let sessionQueue = DispatchQueue(label: "iPhoneCameraSession")
  private let outputQueue = DispatchQueue(label: "iPhoneCameraOutput")

  override init() {
    super.init()
  }

  func checkPermission() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      hasPermission = true
      return true
    case .notDetermined:
      let granted = await AVCaptureDevice.requestAccess(for: .video)
      hasPermission = granted
      return granted
    default:
      hasPermission = false
      return false
    }
  }

  func startCapture() async throws {
    guard await checkPermission() else {
      throw CameraError.permissionDenied
    }

    let session = AVCaptureSession()
    session.sessionPreset = .hd1280x720

    // Get back camera
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      throw CameraError.noCameraAvailable
    }

    // Add input
    let input = try AVCaptureDeviceInput(device: camera)
    guard session.canAddInput(input) else {
      throw CameraError.cannotAddInput
    }
    session.addInput(input)

    // Add output
    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: outputQueue)
    output.alwaysDiscardsLateVideoFrames = true

    guard session.canAddOutput(output) else {
      throw CameraError.cannotAddOutput
    }
    session.addOutput(output)

    // Set orientation to portrait
    if let connection = output.connection(with: .video) {
      if connection.isVideoRotationAngleSupported(90) {
        connection.videoRotationAngle = 90
      }
    }

    self.captureSession = session
    self.videoOutput = output

    // Start session on background queue
    sessionQueue.async {
      session.startRunning()
      Task { @MainActor in
        self.isRunning = true
      }
    }
  }

  func stopCapture() {
    sessionQueue.async { [weak self] in
      self?.captureSession?.stopRunning()
      Task { @MainActor [weak self] in
        self?.isRunning = false
        self?.currentFrame = nil
      }
    }
  }

  enum CameraError: Error {
    case permissionDenied
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
  }
}

extension iPhoneCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()

    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
    let image = UIImage(cgImage: cgImage)

    Task { @MainActor [weak self] in
      self?.currentFrame = image
    }
  }
}
