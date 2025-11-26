//
//  VoxtralService.swift
//  AzmyAI
//
//  Voice-to-Text service using Mistral Voxtral
//  Agent 1: Converts audio to raw text transcription
//

import Foundation
import AVFoundation

// MARK: - Voxtral API Models

struct VoxtralRequest: Codable {
    let model: String
    let messages: [VoxtralMessage]
}

struct VoxtralMessage: Codable {
    let role: String
    let content: [VoxtralContent]
}

struct VoxtralContent: Codable {
    let type: String
    let text: String?
    let data: String?       // Base64 encoded audio
    let mimeType: String?   // e.g., "audio/wav"

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case data
        case mimeType = "mime_type"
    }

    init(type: String, text: String? = nil, data: String? = nil, mimeType: String? = nil) {
        self.type = type
        self.text = text
        self.data = data
        self.mimeType = mimeType
    }
}

struct VoxtralResponse: Codable {
    let choices: [VoxtralChoice]
}

struct VoxtralChoice: Codable {
    let message: VoxtralResponseMessage
}

struct VoxtralResponseMessage: Codable {
    let content: String
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

    // Mistral Voxtral model for audio transcription
    private let apiKey: String
    private let apiURL = "https://api.mistral.ai/v1/chat/completions"
    private let model = "mistral-large-latest" // Voxtral-capable model

    @Published var state: VoiceProcessingState = .idle
    @Published var rawTranscription: String = ""

    init() {
        self.apiKey = ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] ?? "KBMVVuAYB9A0mvM2Qq2VHVwENMMOB6lv"
    }

    // MARK: - Transcribe Audio

    /// Converts audio data to raw text transcription
    /// - Parameter audioData: WAV audio data
    /// - Returns: Raw transcribed text (may contain errors, pauses, etc.)
    func transcribeAudio(_ audioData: Data) async -> String? {
        state = .transcribing

        // Convert audio to base64
        let base64Audio = audioData.base64EncodedString()

        // Build the request with audio content
        let content: [VoxtralContent] = [
            VoxtralContent(
                type: "audio",
                data: base64Audio,
                mimeType: "audio/wav"
            ),
            VoxtralContent(
                type: "text",
                text: "Transcribe this audio accurately. Output ONLY the transcription, nothing else. Preserve all words exactly as spoken, including filler words, pauses (as '...'), and any unclear parts (mark as [unclear]). Do not add punctuation or formatting."
            )
        ]

        let message = VoxtralMessage(role: "user", content: content)
        let request = VoxtralRequest(model: model, messages: [message])

        guard let result = await callVoxtralAPI(request) else {
            state = .error(message: "Failed to transcribe audio")
            return nil
        }

        rawTranscription = result
        return result
    }

    /// Transcribe audio from a file URL
    func transcribeAudioFile(at url: URL) async -> String? {
        guard let audioData = try? Data(contentsOf: url) else {
            state = .error(message: "Failed to read audio file")
            return nil
        }
        return await transcribeAudio(audioData)
    }

    // MARK: - API Call

    private func callVoxtralAPI(_ voxtralRequest: VoxtralRequest) async -> String? {
        guard let url = URL(string: apiURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Audio processing may take time

        do {
            let jsonData = try JSONEncoder().encode(voxtralRequest)
            request.httpBody = jsonData

            print("[Voxtral] Sending audio transcription request...")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("[Voxtral] HTTP Status: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("[Voxtral] Error: \(errorString)")
                    }
                    return nil
                }
            }

            let voxtralResponse = try JSONDecoder().decode(VoxtralResponse.self, from: data)
            let transcription = voxtralResponse.choices.first?.message.content ?? ""

            print("[Voxtral] Transcription received: \(transcription.prefix(100))...")

            return transcription

        } catch {
            print("[Voxtral] API Error: \(error)")
            return nil
        }
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        rawTranscription = ""
    }
}
