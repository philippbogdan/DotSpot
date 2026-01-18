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
