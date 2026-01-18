#!/usr/bin/env python3
"""
DotSpot Detection Server

WebSocket server that receives JPEG frames and returns YOLOv8m detections.

Usage:
    pip install ultralytics websockets
    python detection_server.py

The server listens on ws://0.0.0.0:8765
"""

import asyncio
import json
import time
from io import BytesIO

import websockets
from PIL import Image
from ultralytics import YOLO

# Load YOLOv8m model (medium - good balance of speed and accuracy)
print("Loading YOLOv8m model...")
model = YOLO("yolov8m.pt")
print("Model loaded!")


async def process_frame(websocket):
    """Handle incoming frames from iOS client."""
    client_addr = websocket.remote_address
    print(f"[+] Client connected: {client_addr}")

    frame_count = 0
    total_inference_time = 0

    try:
        async for message in websocket:
            start_time = time.time()

            # Decode JPEG image
            image = Image.open(BytesIO(message))

            # Run YOLO inference
            results = model(image, verbose=False)

            # Extract detections
            detections = []
            for result in results:
                boxes = result.boxes
                for i in range(len(boxes)):
                    box = boxes[i]
                    # Get normalized coordinates (0-1)
                    xyxyn = box.xyxyn[0].tolist()

                    detection = {
                        "label": result.names[int(box.cls[0])],
                        "confidence": float(box.conf[0]),
                        "x": xyxyn[0],
                        "y": xyxyn[1],
                        "width": xyxyn[2] - xyxyn[0],
                        "height": xyxyn[3] - xyxyn[1],
                    }
                    detections.append(detection)

            # Calculate timing
            inference_time = (time.time() - start_time) * 1000
            frame_count += 1
            total_inference_time += inference_time
            avg_time = total_inference_time / frame_count

            # Log occasionally
            if frame_count % 10 == 0:
                print(f"[Frame {frame_count}] {len(detections)} objects, {inference_time:.1f}ms (avg: {avg_time:.1f}ms)")

            # Send response
            response = {
                "detections": detections,
                "inference_time_ms": inference_time,
            }
            await websocket.send(json.dumps(response))

    except websockets.exceptions.ConnectionClosed:
        print(f"[-] Client disconnected: {client_addr}")
    except Exception as e:
        print(f"[!] Error: {e}")


async def main():
    """Start the WebSocket server."""
    host = "0.0.0.0"
    port = 8765

    print(f"\n{'='*50}")
    print(f"DotSpot Detection Server")
    print(f"{'='*50}")
    print(f"Model: YOLOv8m")
    print(f"Listening on: ws://{host}:{port}")
    print(f"{'='*50}\n")

    async with websockets.serve(process_frame, host, port, max_size=10_000_000):
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    asyncio.run(main())
