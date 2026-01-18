//
// DotSpotOverlayView.swift
//
// Overlay view showing the center crosshair and debug bounding boxes.
//

import SwiftUI

struct DotSpotOverlayView: View {
  @ObservedObject var viewModel: DotSpotViewModel
  let frameSize: CGSize

  var body: some View {
    ZStack {
      // Debug: Bounding boxes
      if viewModel.isDebugMode {
        ForEach(viewModel.trackedObjects) { object in
          BoundingBoxView(
            object: object,
            frameSize: frameSize,
            isPointed: object.id == viewModel.currentPointedObject?.id
          )
        }

        // Debug info overlay (top right)
        VStack {
          HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              // Connection status
              HStack(spacing: 4) {
                Circle()
                  .fill(viewModel.isConnected ? Color.green : Color.red)
                  .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? "Server" : "Disconnected")
              }

              // Edge compute toggle
              Button {
                viewModel.setEdgeComputeEnabled(!viewModel.isEdgeComputeEnabled)
              } label: {
                HStack(spacing: 4) {
                  Circle()
                    .fill(viewModel.isUsingEdgeCompute ? Color.green : (viewModel.isEdgeComputeEnabled ? Color.yellow : Color.gray))
                    .frame(width: 8, height: 8)
                  Text(viewModel.isConnected ? "Edge (Server active)" : (viewModel.isEdgeComputeEnabled ? "Edge ON" : "Edge OFF"))
                }
                .opacity(viewModel.canToggleEdgeCompute ? 1.0 : 0.5)
              }
              .disabled(!viewModel.canToggleEdgeCompute)
              .accessibilityLabel("Edge compute toggle")
              .accessibilityHint(viewModel.canToggleEdgeCompute ? "Toggles on-device object detection" : "Disabled while connected to server")

              Text("Frames: \(viewModel.detectionCount) | Objects: \(viewModel.trackedObjects.count)")
              Text("Inference: \(String(format: "%.0f", viewModel.inferenceTime))ms")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(4)
          }
          .padding(.trailing, 24)
          .padding(.top, 100)
          Spacer()
        }
      }

      // Center crosshair/dot (offset 0.1 down from center)
      GeometryReader { geometry in
        CenterDotView(
          dwellProgress: viewModel.dwellProgress,
          hasTarget: viewModel.currentPointedObject != nil
        )
        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.6)
      }
    }
  }
}

struct BoundingBoxView: View {
  let object: TrackedObject
  let frameSize: CGSize
  let isPointed: Bool

  var body: some View {
    let rect = denormalizeRect(object.boundingBox, to: frameSize)
    let boxColor = isPointed ? Color.red : Color.white.opacity(0.5)

    ZStack(alignment: .topLeading) {
      // Bounding box
      Rectangle()
        .stroke(boxColor, lineWidth: isPointed ? 3 : 1)
        .frame(width: rect.width, height: rect.height)

      // Label background
      Text(object.label)
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(isPointed ? .white : .black)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isPointed ? Color.red : Color.white.opacity(0.7))
        .cornerRadius(2)
        .offset(y: -16)
    }
    .position(x: rect.midX, y: rect.midY)
  }

  private func denormalizeRect(_ normalized: CGRect, to size: CGSize) -> CGRect {
    CGRect(
      x: normalized.origin.x * size.width,
      y: normalized.origin.y * size.height,
      width: normalized.width * size.width,
      height: normalized.height * size.height
    )
  }
}

struct CenterDotView: View {
  let dwellProgress: Double
  let hasTarget: Bool

  // Circle size - this is the targeting circle
  static let circleSize: CGFloat = 80
  private let outlineWidth: CGFloat = 2
  private let centerDotSize: CGFloat = 6

  var body: some View {
    ZStack {
      // Main targeting circle (opaque outline)
      Circle()
        .stroke(Color.red.opacity(0.6), lineWidth: outlineWidth)
        .frame(width: Self.circleSize, height: Self.circleSize)

      // Progress ring (fills as dwell time increases)
      Circle()
        .trim(from: 0, to: dwellProgress)
        .stroke(Color.red, lineWidth: outlineWidth + 1)
        .frame(width: Self.circleSize, height: Self.circleSize)
        .rotationEffect(.degrees(-90))

      // Tiny center dot
      Circle()
        .fill(Color.red)
        .frame(width: centerDotSize, height: centerDotSize)
    }
  }
}

struct CrosshairLines: View {
  private let lineLength: CGFloat = 8
  private let gap: CGFloat = 12

  var body: some View {
    ZStack {
      // Top line
      Rectangle()
        .fill(Color.red.opacity(0.7))
        .frame(width: 1, height: lineLength)
        .offset(y: -(gap + lineLength / 2))

      // Bottom line
      Rectangle()
        .fill(Color.red.opacity(0.7))
        .frame(width: 1, height: lineLength)
        .offset(y: gap + lineLength / 2)

      // Left line
      Rectangle()
        .fill(Color.red.opacity(0.7))
        .frame(width: lineLength, height: 1)
        .offset(x: -(gap + lineLength / 2))

      // Right line
      Rectangle()
        .fill(Color.red.opacity(0.7))
        .frame(width: lineLength, height: 1)
        .offset(x: gap + lineLength / 2)
    }
  }
}
