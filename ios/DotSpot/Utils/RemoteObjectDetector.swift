//
// RemoteObjectDetector.swift
//
// Sends frames to a remote server for YOLOv8 inference via WebSocket.
//

import Foundation
import UIKit

class RemoteObjectDetector: NSObject, ObservableObject, URLSessionWebSocketDelegate {
  static let shared = RemoteObjectDetector()

  @Published var isConnected = false
  @Published var lastInferenceTime: Double = 0

  private var webSocketTask: URLSessionWebSocketTask?
  private var session: URLSession!
  private var serverURL: URL?

  private var pendingCompletion: (([Detection]) -> Void)?
  private let queue = DispatchQueue(label: "remote-detector")

  override init() {
    super.init()
    session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
  }

  func connect(to urlString: String) {
    guard let url = URL(string: urlString) else {
      print("[RemoteDetector] Invalid URL: \(urlString)")
      return
    }

    serverURL = url
    webSocketTask = session.webSocketTask(with: url)
    webSocketTask?.resume()
    listenForMessages()

    print("[RemoteDetector] Connecting to \(urlString)...")
  }

  func disconnect() {
    webSocketTask?.cancel(with: .goingAway, reason: nil)
    webSocketTask = nil
    DispatchQueue.main.async {
      self.isConnected = false
    }
  }

  func detect(in image: UIImage, completion: @escaping ([Detection]) -> Void) {
    guard isConnected, let webSocketTask = webSocketTask else {
      completion([])
      return
    }

    // Compress image to JPEG
    guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
      completion([])
      return
    }

    queue.async {
      self.pendingCompletion = completion

      let message = URLSessionWebSocketTask.Message.data(jpegData)
      webSocketTask.send(message) { error in
        if let error = error {
          print("[RemoteDetector] Send error: \(error)")
          DispatchQueue.main.async {
            completion([])
          }
        }
      }
    }
  }

  private func listenForMessages() {
    webSocketTask?.receive { [weak self] result in
      switch result {
      case .success(let message):
        self?.handleMessage(message)
        self?.listenForMessages()  // Continue listening

      case .failure(let error):
        print("[RemoteDetector] Receive error: \(error)")
        DispatchQueue.main.async {
          self?.isConnected = false
        }
      }
    }
  }

  private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
    switch message {
    case .string(let text):
      parseResponse(text)
    case .data(let data):
      if let text = String(data: data, encoding: .utf8) {
        parseResponse(text)
      }
    @unknown default:
      break
    }
  }

  private func parseResponse(_ jsonString: String) {
    guard let data = jsonString.data(using: .utf8) else { return }

    do {
      let response = try JSONDecoder().decode(DetectionResponse.self, from: data)

      let detections = response.detections.map { d in
        Detection(
          label: d.label,
          confidence: d.confidence,
          boundingBox: CGRect(x: d.x, y: d.y, width: d.width, height: d.height)
        )
      }

      DispatchQueue.main.async {
        self.lastInferenceTime = response.inference_time_ms
        self.pendingCompletion?(detections)
        self.pendingCompletion = nil
      }

    } catch {
      print("[RemoteDetector] Parse error: \(error)")
      DispatchQueue.main.async {
        self.pendingCompletion?([])
        self.pendingCompletion = nil
      }
    }
  }

  // MARK: - URLSessionWebSocketDelegate

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) {
    print("[RemoteDetector] Connected!")
    DispatchQueue.main.async {
      self.isConnected = true
    }
  }

  func urlSession(
    _ session: URLSession,
    webSocketTask: URLSessionWebSocketTask,
    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
    reason: Data?
  ) {
    print("[RemoteDetector] Disconnected")
    DispatchQueue.main.async {
      self.isConnected = false
    }
  }
}

// MARK: - Response Models

private struct DetectionResponse: Codable {
  let detections: [RemoteDetection]
  let inference_time_ms: Double
}

private struct RemoteDetection: Codable {
  let label: String
  let confidence: Float
  let x: CGFloat
  let y: CGFloat
  let width: CGFloat
  let height: CGFloat
}
