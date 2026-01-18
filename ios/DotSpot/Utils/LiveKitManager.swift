import LiveKit
import AVFoundation
import CoreMedia
import LiveKitWebRTC

/// Connection state for LiveKit room
enum LiveKitConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

/// Errors specific to LiveKit operations
enum LiveKitError: Error, LocalizedError {
    case notConnected
    case notConfigured
    case videoPublishFailed
    case audioPublishFailed
    case invalidConfiguration
    case videoSourceCreationFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to LiveKit room"
        case .notConfigured:
            return "LiveKit configuration not provided"
        case .videoPublishFailed:
            return "Failed to publish video track"
        case .audioPublishFailed:
            return "Failed to publish audio track"
        case .invalidConfiguration:
            return "Invalid LiveKit configuration"
        case .videoSourceCreationFailed:
            return "Failed to create custom video source"
        }
    }
}

/// Manages LiveKit room connection and media publishing
@MainActor
class LiveKitManager: ObservableObject {
    // Track naming constants
    private static let videoTrackName = "glasses-video"
    private static let audioTrackName = "microphone"

    @Published var connectionState: LiveKitConnectionState = .disconnected
    @Published var isPublishingVideo: Bool = false
    @Published var isPublishingAudio: Bool = false
    @Published var isMuted: Bool = false
    @Published var isReceivingRemoteAudio: Bool = false
    @Published var remoteParticipantCount: Int = 0


    private var room: Room?
    private var videoTrack: LocalVideoTrack?
    private var audioTrack: LocalAudioTrack?
    private var config: LiveKitConfig?

    // Custom video capturer for glasses frames
    private var bufferCapturer: BufferCapturer?

    // Track management
    private var frameCount: Int64 = 0
    private var lastFrameTime: CMTime = .zero
    private var startTime: CMTime?
    private var videoTrackPendingPublish: Bool = false  // Flag to publish after first frame

    // Remote audio tracks (for monitoring agent speech)
    private var remoteAudioTracks: Set<String> = []

    // MARK: - Room Connection

    /// Connect to LiveKit room with credentials
    func connect(credentials: LiveKitSessionCredentials, config: LiveKitConfig) async throws {
        self.config = config
        connectionState = .connecting

        // Always configure audio session for duplex audio (mic + speaker)
        try AudioManager.shared.configureAudioSession(enableRecording: true)

        let room = Room()
        self.room = room

        // Setup room event handlers
        setupRoomHandlers(room)

        do {
            // Connect to room with auto-subscribe enabled to receive agent audio
            try await room.connect(
                url: credentials.serverURL,
                token: credentials.token,
                connectOptions: ConnectOptions(
                    autoSubscribe: true  // Automatically subscribe to remote tracks (agent speech)
                )
            )

            connectionState = .connected
            NSLog("[LiveKit] Connected to room: \(credentials.roomName)")

            // Always enable microphone immediately after connection
            try await startPublishingAudio()
            NSLog("[LiveKit] Microphone enabled and publishing")
        } catch {
            connectionState = .error("Connection failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Disconnect from LiveKit room
    func disconnect() async {
        await stopPublishingVideo()
        await stopPublishingAudio()
        await room?.disconnect()
        room = nil
        config = nil
        connectionState = .disconnected
        videoTrackPendingPublish = false
    }

    // MARK: - Video Publishing

    /// Start publishing video from glasses with custom video source
    func startPublishingVideo(videoSize: CGSize, frameRate: Int32 = 24) async throws {
        guard let room = room else {
            NSLog("[LiveKit] Cannot start video publishing: no room")
            throw LiveKitError.notConnected
        }
        guard connectionState == .connected else {
            NSLog("[LiveKit] Cannot start video publishing: not connected (state: \(connectionState))")
            throw LiveKitError.notConnected
        }

        guard let config = config else {
            NSLog("[LiveKit] Cannot start video publishing: no config")
            return
        }
        guard config.enableVideo else {
            NSLog("[LiveKit] Cannot start video publishing: video disabled in config")
            return
        }

        NSLog("[LiveKit] Setting up video track at \(videoSize.width)x\(videoSize.height), \(frameRate)fps")
        do {
            // Create custom video track from buffer for glasses frames
            let track = try LocalVideoTrack.createBufferTrack(
                name: Self.videoTrackName,
                source: .camera,
                options: BufferCaptureOptions(
                    dimensions: Dimensions(
                        width: Int32(videoSize.width),
                        height: Int32(videoSize.height)
                    ),
                    fps: Int(frameRate)
                ),
                reportStatistics: true
            )

            // Get the buffer capturer from the track
            guard let bufferCapturer = track.capturer as? BufferCapturer else {
                NSLog("[LiveKit] Failed to get buffer capturer from track")
                throw LiveKitError.videoSourceCreationFailed
            }

            self.bufferCapturer = bufferCapturer
            self.videoTrack = track
            self.startTime = nil
            self.frameCount = 0
            self.videoTrackPendingPublish = true  // Will publish after first frame

            NSLog("[LiveKit] Video track created, waiting for first frame before publishing...")
        } catch {
            NSLog("[LiveKit] Failed to create video track: \(error)")
            throw LiveKitError.videoPublishFailed
        }
    }

    /// Publish a video frame from glasses to LiveKit
    /// Always accepts frames; silently drops them if track isn't ready yet
    func publishVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // Silently drop frames if we don't have a buffer capturer yet
        guard let bufferCapturer = bufferCapturer else {
            return
        }

        // Initialize start time on first frame
        if startTime == nil {
            startTime = timestamp
            NSLog("[LiveKit] First frame captured for '\(Self.videoTrackName)', starting timestamp tracking")
        }

        // Calculate frame timestamp relative to start (in nanoseconds)
        let relativeTime = CMTimeSubtract(timestamp, startTime ?? .zero)
        let timeStampNs = Int64(CMTimeGetSeconds(relativeTime) * 1_000_000_000)

        // Push frame to buffer capturer
        bufferCapturer.capture(
            pixelBuffer,
            timeStampNs: timeStampNs,
            rotation: ._0
        )

        frameCount += 1

        // Publish track to room after first frame has been captured
        if videoTrackPendingPublish && frameCount == 1 {
            Task { @MainActor in
                await publishVideoTrackToRoom()
            }
        }

        // Log progress periodically (every 100 frames)
        if frameCount % 100 == 0 {
            NSLog("[LiveKit] Published \(frameCount) frames to '\(Self.videoTrackName)'")
        }
    }

    /// Publish the prepared video track to the room (called after first frame)
    private func publishVideoTrackToRoom() async {
        guard let room = room, let track = videoTrack else {
            NSLog("[LiveKit] Cannot publish track: missing room or track")
            videoTrackPendingPublish = false
            return
        }

        guard connectionState == .connected else {
            NSLog("[LiveKit] Cannot publish track: not connected")
            videoTrackPendingPublish = false
            return
        }

        NSLog("[LiveKit] Publishing video track to room (after first frame)...")
        NSLog("[LiveKit] Room state: connectionState=\(room.connectionState), participants=\(room.allParticipants.count)")

        // Publish the custom video track with options
        let publishOptions = VideoPublishOptions(
            simulcast: false,
        )

        do {
            try await room.localParticipant.publish(videoTrack: track, options: publishOptions)
            isPublishingVideo = true
            videoTrackPendingPublish = false
            NSLog("[LiveKit] Successfully published video track '\(Self.videoTrackName)'")
        } catch let error as NSError {
            NSLog("[LiveKit] Failed to publish video track '\(Self.videoTrackName)'")
            NSLog("[LiveKit] Error domain: \(error.domain), code: \(error.code)")
            NSLog("[LiveKit] Error description: \(error.localizedDescription)")
            NSLog("[LiveKit] Error userInfo: \(error.userInfo)")

            // Clean up on failure
            self.videoTrack = nil
            self.bufferCapturer = nil
            self.videoTrackPendingPublish = false
        }
    }

    /// Stop publishing video
    func stopPublishingVideo() async {
        // Cancel pending publish if it hasn't happened yet
        if videoTrackPendingPublish {
            NSLog("[LiveKit] Cancelling pending video track publish")
            videoTrackPendingPublish = false
        }

        guard let room = room, let track = videoTrack else {
            // Clean up state even if no track/room
            videoTrack = nil
            bufferCapturer = nil
            isPublishingVideo = false
            startTime = nil
            frameCount = 0
            return
        }

        do {
            // Find the publication for this track (only if it was actually published)
            if let publication = room.localParticipant.localVideoTracks.first(where: { $0.track === track }) {
                try await room.localParticipant.unpublish(publication: publication)
            }

            videoTrack = nil
            bufferCapturer = nil
            isPublishingVideo = false
            startTime = nil
            frameCount = 0
            NSLog("[LiveKit] Stopped publishing video track '\(Self.videoTrackName)'")
        } catch {
            NSLog("[LiveKit] Error stopping video publishing for track '\(Self.videoTrackName)': \(error)")
        }
    }

    // MARK: - Audio Publishing

    /// Start publishing audio from glasses microphone
    func startPublishingAudio() async throws {
        guard let room = room, connectionState == .connected else {
            NSLog("[LiveKit] Cannot start audio publishing: not connected")
            throw LiveKitError.notConnected
        }

        do {
            // Enable microphone track
            try await room.localParticipant.setMicrophone(enabled: true)

            // Get the published microphone track
            if let publication = room.localParticipant.localAudioTracks.first {
                self.audioTrack = publication.track as? LocalAudioTrack
                isPublishingAudio = true
                isMuted = false
                NSLog("[LiveKit] Started publishing audio track '\(Self.audioTrackName)'")
            }
        } catch {
            NSLog("[LiveKit] Failed to start audio publishing: \(error)")
            throw LiveKitError.audioPublishFailed
        }
    }

    /// Mute the microphone (stop sending audio)
    func mute() async throws {
        guard let audioTrack = audioTrack else {
            NSLog("[LiveKit] Cannot mute: no audio track")
            return
        }

        try await audioTrack.mute()
        isMuted = true
        NSLog("[LiveKit] Audio track '\(Self.audioTrackName)' muted")
    }

    /// Unmute the microphone (resume sending audio)
    func unmute() async throws {
        guard let audioTrack = audioTrack else {
            NSLog("[LiveKit] Cannot unmute: no audio track")
            return
        }

        try await audioTrack.unmute()
        isMuted = false
        NSLog("[LiveKit] Audio track '\(Self.audioTrackName)' unmuted")
    }

    /// Toggle mute state
    func toggleMute() async throws {
        if isMuted {
            try await unmute()
        } else {
            try await mute()
        }
    }

    /// Publish an audio buffer to LiveKit
    func publishAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isPublishingAudio else { return }

        // For LiveKit's built-in microphone track, audio is automatically captured
        // Custom audio publishing would require a custom audio source

        // TODO: Implement custom audio source if needed for Bluetooth routing
    }

    /// Stop publishing audio
    func stopPublishingAudio() async {
        guard let room = room else { return }

        do {
            try await room.localParticipant.setMicrophone(enabled: false)
            audioTrack = nil
            isPublishingAudio = false
        } catch {
            print("Error stopping audio publishing: \(error)")
        }
    }

    // MARK: - Room Event Handling

    private func setupRoomHandlers(_ room: Room) {
        // Add room delegate
        room.add(delegate: self)
    }

    // MARK: - Helper Methods

    /// Get room participants count
    var participantCount: Int {
        guard let room = room else { return 0 }
        return room.allParticipants.count
    }

    /// Get current room name
    var currentRoomName: String? {
        return room?.name
    }

    /// Check if connected to room
    var isConnected: Bool {
        return connectionState == .connected && room != nil
    }
}

// MARK: - RoomDelegate

extension LiveKitManager: RoomDelegate {
    nonisolated func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldValue: ConnectionState) {
        Task { @MainActor in
            switch connectionState {
            case .disconnected:
                self.connectionState = .disconnected
            case .connected:
                self.connectionState = .connected
            case .connecting, .reconnecting:
                self.connectionState = .connecting
            case .disconnecting:
                self.connectionState = .connecting
            @unknown default:
                break
            }
        }
    }

    nonisolated func room(_ room: Room, didFailToConnectWithError error: LiveKit.LiveKitError?) {
        Task { @MainActor in
            self.connectionState = .error("Connection failed: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    nonisolated func room(_ room: Room, participant: LocalParticipant, didPublishTrack publication: LocalTrackPublication) {
        Task { @MainActor in
            if publication.kind == .video {
                self.isPublishingVideo = true
            } else if publication.kind == .audio {
                self.isPublishingAudio = true
            }
        }
    }

    nonisolated func room(_ room: Room, participant: LocalParticipant, didUnpublishTrack publication: LocalTrackPublication) {
        Task { @MainActor in
            if publication.kind == .video {
                self.isPublishingVideo = false
            } else if publication.kind == .audio {
                self.isPublishingAudio = false
            }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            if publication.kind == .audio {
                NSLog("[LiveKit] Subscribed to remote audio track from participant: \(participant.identity)")
                self.remoteAudioTracks.insert(publication.sid.stringValue)
                self.isReceivingRemoteAudio = !self.remoteAudioTracks.isEmpty

                // Audio playback is automatic for subscribed remote audio tracks
                // The LiveKit SDK will route audio to the system audio output
                if let audioTrack = publication.track as? RemoteAudioTrack {
                    NSLog("[LiveKit] Remote audio track enabled, playback is automatic")
                }
            } else if publication.kind == .video {
                NSLog("[LiveKit] Subscribed to remote video track from participant: \(participant.identity)")
            }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        Task { @MainActor in
            if publication.kind == .audio {
                NSLog("[LiveKit] Unsubscribed from remote audio track from participant: \(participant.identity)")
                self.remoteAudioTracks.remove(publication.sid.stringValue)
                self.isReceivingRemoteAudio = !self.remoteAudioTracks.isEmpty
            } else if publication.kind == .video {
                NSLog("[LiveKit] Unsubscribed from remote video track from participant: \(participant.identity)")
            }
        }
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            NSLog("[LiveKit] Remote participant connected: \(participant.identity)")
            self.remoteParticipantCount = room.remoteParticipants.count
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            NSLog("[LiveKit] Remote participant disconnected: \(participant.identity)")
            self.remoteParticipantCount = room.remoteParticipants.count

            // Clean up audio tracks from disconnected participant
            for publication in participant.audioTracks {
                self.remoteAudioTracks.remove(publication.sid.stringValue)
            }
            self.isReceivingRemoteAudio = !self.remoteAudioTracks.isEmpty
        }
    }
}
