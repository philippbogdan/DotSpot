
https://private-user-images.githubusercontent.com/174341097/537279439-fed16046-72a1-4f9c-9e86-c36c1720a3ed.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Njg3MzczNzksIm5iZiI6MTc2ODczNzA3OSwicGF0aCI6Ii8xNzQzNDEwOTcvNTM3Mjc5NDM5LWZlZDE2MDQ2LTcyYTEtNGY5Yy05ZTg2LWMzNmMxNzIwYTNlZC5tcDQ_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwMTE4JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDExOFQxMTUxMTlaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT02MTFjZWQ0NjE0MDg5NzdlMTViY2MyOWVkMGE3N2JiZmFiZGJmMzIyZWVjYTBmYWFlM2Y4NjU1ZDllZThhMTlhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.5Y4gBR0YoqBdN_RcOEnWg3QKnqHFIAIkYznNAkiEmSw

# DotSpot

Point at objects with Ray-Ban Meta glasses to identify them using YOLOv8.

## How It Works

1. Wear Ray-Ban Meta glasses connected to the iOS app
2. Enable **DotSpot** mode - a red pointer appears on screen
3. Point at any object for 2 seconds
4. The glasses speak the object name via TTS

Detection runs on your laptop (YOLOv8m) via WebSocket for better accuracy.

## Quick Setup

### 1. Server (laptop)

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python detection_server.py
```

Server starts on `ws://0.0.0.0:8765`

### 2. iOS App

1. Get your laptop's IP: `ipconfig getifaddr en0`
2. Update `ios/Blindsighted/ViewModels/DotSpotViewModel.swift` line 36:
   ```swift
   static let serverURL = "ws://YOUR_IP:8765"
   ```
3. Copy `ios/Config.xcconfig.example` to `ios/Config.xcconfig`
4. Open `ios/Blindsighted.xcodeproj` in Xcode
5. Build and run on iPhone (same WiFi as laptop)

### 3. Connect Glasses

1. Open Meta AI app → Settings → tap version 5x → enable Developer Mode
2. In DotSpot app, tap "Connect my glasses"
3. Authorize in Meta AI app

## Usage

- **DotSpot** toggle: Enable object detection
- **Debug** toggle: Show bounding boxes and inference stats
- Point at object for 2s → hear the label spoken

## Architecture

```
Ray-Ban Meta ──► iPhone (camera stream)
                      │
                      │ WebSocket (JPEG frames)
                      ▼
               Laptop (YOLOv8m)
                      │
                      │ JSON (detections)
                      ▼
               iPhone (tracking + TTS) ──► Glasses (audio)
```

## Credits

Built on top of [Blindsighted](https://github.com/DJRHails/blindsighted) by [@DJRHails](https://github.com/DJRHails) - a hackathon template for Ray-Ban Meta glasses.
