//
//  AudioRecordingService.swift
//  AzmyAI
//
//  Handles microphone recording for voice input
//  Records audio in WAV format for Voxtral processing
//

import Foundation
import AVFoundation

// MARK: - Recording State

enum RecordingState {
    case idle
    case requestingPermission
    case recording
    case processing
    case error(String)
}

// MARK: - Audio Recording Service

@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    static let shared = AudioRecordingService()

    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var recordingURL: URL?

    @Published var state: RecordingState = .idle
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0 // For visual feedback (0-1)

    private var levelTimer: Timer?
    private var durationTimer: Timer?

    // Audio settings for WAV format (compatible with Voxtral)
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16000, // 16kHz is standard for speech recognition
        AVNumberOfChannelsKey: 1, // Mono
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    override init() {
        super.init()
    }

    // MARK: - Permission

    func requestMicrophonePermission() async -> Bool {
        state = .requestingPermission

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    if granted {
                        self.state = .idle
                    } else {
                        self.state = .error("Microphone access denied")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    var hasMicrophonePermission: Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }

    // MARK: - Recording

    func startRecording() async throws {
        // Check permission first
        if !hasMicrophonePermission {
            let granted = await requestMicrophonePermission()
            guard granted else {
                throw RecordingError.permissionDenied
            }
        }

        // Setup audio session
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession?.setActive(true)
        } catch {
            state = .error("Failed to setup audio session")
            throw RecordingError.sessionSetupFailed
        }

        // Create recording URL
        let documentsPath = FileManager.default.temporaryDirectory
        let fileName = "voice_recording_\(Date().timeIntervalSince1970).wav"
        recordingURL = documentsPath.appendingPathComponent(fileName)

        guard let url = recordingURL else {
            throw RecordingError.invalidURL
        }

        // Initialize recorder
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: audioSettings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            state = .error("Failed to initialize recorder: \(error.localizedDescription)")
            throw RecordingError.initializationFailed
        }

        // Start recording
        guard audioRecorder?.record() == true else {
            state = .error("Failed to start recording")
            throw RecordingError.recordingFailed
        }

        state = .recording
        isRecording = true
        recordingDuration = 0

        // Start timers for level and duration updates
        startTimers()

        print("[AudioRecording] Recording started: \(url.lastPathComponent)")
    }

    func stopRecording() -> Data? {
        guard isRecording, let recorder = audioRecorder else {
            return nil
        }

        // Stop timers
        stopTimers()

        // Stop recording
        recorder.stop()
        isRecording = false
        state = .processing

        print("[AudioRecording] Recording stopped. Duration: \(recordingDuration)s")

        // Read audio data
        guard let url = recordingURL,
              let audioData = try? Data(contentsOf: url) else {
            state = .error("Failed to read recorded audio")
            return nil
        }

        print("[AudioRecording] Audio data size: \(audioData.count) bytes")

        // Clean up file
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil

        // Deactivate audio session
        try? audioSession?.setActive(false)

        state = .idle
        return audioData
    }

    func cancelRecording() {
        stopTimers()

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        // Clean up file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        try? audioSession?.setActive(false)
        state = .idle
        recordingDuration = 0
        audioLevel = 0

        print("[AudioRecording] Recording cancelled")
    }

    // MARK: - Timers

    private func startTimers() {
        // Level meter timer (update audio level visualization)
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }

        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0
            return
        }

        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)

        // Convert dB to 0-1 range
        // Typical range: -160 dB (silence) to 0 dB (max)
        let normalizedLevel = max(0, (level + 50) / 50) // Map -50...0 to 0...1
        audioLevel = normalizedLevel
    }

    // MARK: - Max Recording Duration

    var maxRecordingDuration: TimeInterval { 60 } // 1 minute max

    var isNearMaxDuration: Bool {
        recordingDuration >= maxRecordingDuration - 5 // Last 5 seconds
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                state = .error("Recording finished unexpectedly")
            }
            print("[AudioRecording] Did finish recording. Success: \(flag)")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            state = .error(error?.localizedDescription ?? "Encoding error")
            print("[AudioRecording] Encode error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case permissionDenied
    case sessionSetupFailed
    case invalidURL
    case initializationFailed
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access was denied. Please enable it in Settings."
        case .sessionSetupFailed:
            return "Failed to setup audio session."
        case .invalidURL:
            return "Invalid recording file path."
        case .initializationFailed:
            return "Failed to initialize audio recorder."
        case .recordingFailed:
            return "Failed to start recording."
        }
    }
}
