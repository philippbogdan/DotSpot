# Demo (sound on)
https://private-user-images.githubusercontent.com/174341097/537279439-fed16046-72a1-4f9c-9e86-c36c1720a3ed.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Njg3MzczNzksIm5iZiI6MTc2ODczNzA3OSwicGF0aCI6Ii8xNzQzNDEwOTcvNTM3Mjc5NDM5LWZlZDE2MDQ2LTcyYTEtNGY5Yy05ZTg2LWMzNmMxNzIwYTNlZC5tcDQ_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjYwMTE4JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI2MDExOFQxMTUxMTlaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT02MTFjZWQ0NjE0MDg5NzdlMTViY2MyOWVkMGE3N2JiZmFiZGJmMzIyZWVjYTBmYWFlM2Y4NjU1ZDllZThhMTlhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCJ9.5Y4gBR0YoqBdN_RcOEnWg3QKnqHFIAIkYznNAkiEmSw

# DotSpot

**An assistive tool for blind and visually impaired people.**

Point your head at something. The glasses tell you what it is.

---

## Why This Exists

Blind people constantly ask "what's in front of me?" — at the grocery store, in a new room, on a desk. Current solutions require pulling out a phone, opening an app, pointing a camera. Too slow. Too awkward.

DotSpot uses Ray-Ban Meta smart glasses to identify objects hands-free. Just look at something for 2 seconds. The glasses speak the object name directly into your ears.

No phone in hand. No screen to look at. Just point and listen.

---

## How It Works

1. Wear Ray-Ban Meta glasses connected to the iOS app
2. Point your head at any object for 2 seconds
3. A fading hum tells you the system is tracking
4. Chime plays → glasses speak the object name

The system remembers what it already told you — look away and back, it won't repeat itself.

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

## Accessibility Design

This app was built with blind users in mind:

- **No visual dependency** — audio hum provides feedback while pointing, chime confirms lock-on
- **Hands-free** — no phone interaction needed once started
- **No repeat announcements** — system remembers what it told you
- **Open-ear audio** — Ray-Ban Meta glasses let you hear the world while getting spoken info
- **Forgiving tracking** — brief glances away don't reset the timer

The red crosshair and debug boxes are for sighted developers/helpers only.

---

## Limitations

- Requires WiFi connection to laptop (not standalone)
- 2-second dwell time may be too long/short for some users
- YOLOv8 only knows ~80 object categories (COCO dataset)
- Hasn't been tested extensively with actual blind users yet

---

## Credits

Built on top of [Blindsighted](https://github.com/DJRHails/blindsighted) by [@DJRHails](https://github.com/DJRHails) - a hackathon template for Ray-Ban Meta glasses.

---

*If you're blind/visually impaired and want to try this, or if you have feedback on how to make it better, please reach out.*
