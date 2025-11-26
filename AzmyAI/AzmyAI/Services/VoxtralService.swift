//
//  VoxtralService.swift
//  AzmyAI
//
//  Voice-to-Text service using Mistral Voxtral
//  Agent 1: Converts audio to raw text transcription
//

import Foundation
import AVFoundation

// MARK: - Voxtral Transcription Response

struct VoxtralTranscriptionResponse: Codable {
    let text: String
}

// MARK: - Voice Processing State

enum VoiceProcessingState: Equatable {
    case idle
    case recording
    case transcribing
    case cleaningUp
    case complete(text: String)
    case error(message: String)

    static func == (lhs: VoiceProcessingState, rhs: VoiceProcessingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.recording, .recording): return true
        case (.transcribing, .transcribing): return true
        case (.cleaningUp, .cleaningUp): return true
        case (.complete(let l), .complete(let r)): return l == r
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - Voxtral Service (Agent 1: Audio → Raw Text)

@MainActor
class VoxtralService: ObservableObject {
    static let shared = VoxtralService()

    // Mistral Voxtral transcription endpoint
    private let apiKey: String
    private let apiURL = "https://api.mistral.ai/v1/audio/transcriptions"
    private let model = "voxtral-mini-latest"

    @Published var state: VoiceProcessingState = .idle
    @Published var rawTranscription: String = ""

    init() {
        self.apiKey = ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] ?? "KBMVVuAYB9A0mvM2Qq2VHVwENMMOB6lv"
    }

    // MARK: - Transcribe Audio

    /// Converts audio data to raw text transcription using Mistral's dedicated transcription API
    /// - Parameter audioData: WAV audio data
    /// - Returns: Raw transcribed text
    func transcribeAudio(_ audioData: Data) async -> String? {
        state = .transcribing

        guard let url = URL(string: apiURL) else {
            state = .error(message: "Invalid API URL")
            return nil
        }

        // Create multipart form data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // Audio processing may take time

        // Build multipart body
        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            print("[Voxtral] Sending audio transcription request to \(apiURL)...")
            print("[Voxtral] Audio size: \(audioData.count) bytes")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("[Voxtral] HTTP Status: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("[Voxtral] Error: \(errorString)")
                    }
                    state = .error(message: "API returned status \(httpResponse.statusCode)")
                    return nil
                }
            }

            // Parse response
            let transcriptionResponse = try JSONDecoder().decode(VoxtralTranscriptionResponse.self, from: data)
            let transcription = transcriptionResponse.text

            print("[Voxtral] Transcription received: \(transcription.prefix(100))...")

            rawTranscription = transcription
            return transcription

        } catch {
            print("[Voxtral] API Error: \(error)")
            state = .error(message: "Transcription failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Transcribe audio from a file URL
    func transcribeAudioFile(at url: URL) async -> String? {
        guard let audioData = try? Data(contentsOf: url) else {
            state = .error(message: "Failed to read audio file")
            return nil
        }
        return await transcribeAudio(audioData)
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        rawTranscription = ""
    }
}
