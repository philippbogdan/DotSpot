# Blindsighted API

**Part of the Blindsighted hackathon template** - optional backend for session management and storage.

This FastAPI backend handles LiveKit room creation, token generation, session management, and R2 storage for life logs. It's useful but not required - you can run the iOS app and agents without it if you manage LiveKit credentials yourself.

## What This Component Does

- Creates LiveKit rooms and generates access tokens for iOS app
- Manages session lifecycle (start, stop, metadata)
- Stores session data and conversation segments to database
- Uploads life logs and replays to R2 storage (Cloudflare object storage)
- Provides REST API for session history and replay

**See [../ARCHITECTURE.md](../ARCHITECTURE.md) for how this fits into the overall system.**

## When You Need This

- You want automatic LiveKit token generation for iOS
- You want to store session history and metadata
- You want to upload/replay life logs
- You need ad hoc backend features (auth, analytics, etc.)

## When You Don't Need This

- You're testing agents with hardcoded LiveKit tokens
- You just want to experiment with the glasses SDK
- You have your own backend infrastructure

## Setup

### 1. Install Dependencies

Install dependencies using uv:
```bash
uv pip install -e ".[dev]"
```

Or install just the production dependencies:
```bash
uv pip install -e .
```

### 2. Configure Environment

Copy the example environment file:
```bash
cp .env.example .env
```

Edit `.env` and add your OpenRouter API key:
```bash
OPENROUTER_API_KEY=your_api_key_here
```

Get an API key from [OpenRouter](https://openrouter.ai/)

## Development

Format and lint code:
```bash
ruff check --fix .
ruff format .
```

Type check:
```bash
ty .
```

## Running the API

Start the development server:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at:
- **API**: `http://localhost:8000`
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## API Endpoints

### `POST /process-frame`

Process a video frame and generate an audio description.

**Request:**
```json
{
  "image": "base64_encoded_image_string",
  "timestamp": 1704300000000
}
```

**Response:**
```json
{
  "description": "You are looking at a street scene with cars and pedestrians...",
  "timestamp": 1704300000000,
  "processing_time_ms": 1234.5
}
```

## How It Works

1. **App captures frame**: Meta AI Glasses capture a photo every 2 seconds (configurable)
2. **Frame sent to API**: Base64 encoded image sent to `/process-frame`
3. **Gemini vision analysis**: OpenRouter routes request to Gemini 2.0 Flash for image description
4. **Audio generation**: Description converted to speech using pyttsx3
5. **Real-time playback**: Audio played immediately to assist the user
