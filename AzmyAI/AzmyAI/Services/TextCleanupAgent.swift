//
//  TextCleanupAgent.swift
//  AzmyAI
//
//  Agent 2: Cleans and formats raw transcription from Voxtral
//  - Fixes speech recognition errors
//  - Adds proper punctuation and formatting
//  - Handles filler words and pauses
//  - Outputs clean, readable text ready for the main AI agent
//

import Foundation

// MARK: - Text Cleanup Agent

@MainActor
class TextCleanupAgent: ObservableObject {
    static let shared = TextCleanupAgent()

    private let apiKey: String
    private let apiURL = "https://api.mistral.ai/v1/chat/completions"
    private let model = "mistral-small-latest" // Fast model for text processing

    @Published var isProcessing = false
    @Published var cleanedText: String = ""

    init() {
        self.apiKey = ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] ?? "KBMVVuAYB9A0mvM2Qq2VHVwENMMOB6lv"
    }

    // MARK: - Cleanup System Prompt

    private let systemPrompt = """
    You are a text cleanup specialist. Your job is to take raw voice transcriptions and transform them into clean, well-formatted text suitable for an AI assistant to process.

    ## Your Tasks:
    1. Fix obvious speech recognition errors based on context
    2. Add proper punctuation (periods, commas, question marks)
    3. Fix capitalization (start of sentences, proper nouns)
    4. Remove filler words (um, uh, like, you know) unless they add meaning
    5. Clean up repetitions and false starts
    6. Handle pauses marked as "..." appropriately
    7. Resolve [unclear] parts if context makes the word obvious

    ## Rules:
    - Preserve the original MEANING and INTENT
    - Do NOT add, remove, or change the actual request/question
    - Do NOT translate between languages - keep the original language
    - Do NOT summarize - output the full cleaned text
    - Do NOT respond to the content - just clean it up
    - Output ONLY the cleaned text, nothing else

    ## Examples:

    Input: "um so like i wanted to uh schedule a meeting with alex tomorrow at like 3pm or something"
    Output: "I wanted to schedule a meeting with Alex tomorrow at 3pm."

    Input: "what what's my schedule looking like for for today"
    Output: "What's my schedule looking like for today?"

    Input: "привет эм можешь добавить встречу на завтра в 10 утра"
    Output: "Привет, можешь добавить встречу на завтра в 10 утра?"

    Input: "cancel my... no wait delete the meeting with sarah"
    Output: "Delete the meeting with Sarah."
    """

    // MARK: - Cleanup Text

    /// Takes raw transcription and returns clean, formatted text
    /// - Parameter rawText: Raw transcription from Voxtral (may contain errors, filler words, etc.)
    /// - Returns: Clean, properly formatted text ready for AI processing
    func cleanup(_ rawText: String) async -> String? {
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        isProcessing = true
        defer { isProcessing = false }

        print("[TextCleanup] Processing raw text: \(rawText.prefix(100))...")

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": rawText]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.1, // Low temperature for consistent output
            "max_tokens": 500
        ]

        guard let url = URL(string: apiURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("[TextCleanup] API Error: \(httpResponse.statusCode)")
                if let errorText = String(data: data, encoding: .utf8) {
                    print("[TextCleanup] Error details: \(errorText)")
                }
                return rawText // Fall back to raw text on error
            }

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                print("[TextCleanup] Failed to parse response")
                return rawText
            }

            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedText = cleaned

            print("[TextCleanup] Cleaned text: \(cleaned)")

            return cleaned

        } catch {
            print("[TextCleanup] Error: \(error)")
            return rawText // Fall back to raw text on error
        }
    }

    // MARK: - Reset

    func reset() {
        isProcessing = false
        cleanedText = ""
    }
}

// MARK: - Voice Pipeline Manager

/// Orchestrates the full voice-to-text pipeline:
/// 1. Recording → AudioRecordingService
/// 2. Transcription → VoxtralService (Agent 1)
/// 3. Cleanup → TextCleanupAgent (Agent 2)
/// 4. Output → Clean text for main AI agent

@MainActor
class VoicePipelineManager: ObservableObject {
    static let shared = VoicePipelineManager()

    private let voxtralService = VoxtralService.shared
    private let cleanupAgent = TextCleanupAgent.shared

    @Published var state: VoicePipelineState = .idle
    @Published var finalText: String = ""

    // Debug info
    @Published var rawTranscription: String = ""
    @Published var processingStep: String = ""

    // Computed property for UI
    var isProcessing: Bool {
        if case .processing = state {
            return true
        }
        return false
    }

    enum VoicePipelineState {
        case idle
        case recording
        case processing
        case complete
        case error(String)
    }

    // MARK: - Process Audio

    /// Full pipeline: Audio → Transcription → Cleanup → Final Text
    func processAudio(_ audioData: Data) async -> String? {
        state = .processing
        processingStep = "Transcribing audio..."

        // Step 1: Voxtral transcription (Agent 1)
        guard let rawText = await voxtralService.transcribeAudio(audioData) else {
            state = .error("Failed to transcribe audio")
            processingStep = ""
            return nil
        }

        rawTranscription = rawText
        processingStep = "Cleaning up text..."

        // Step 2: Text cleanup (Agent 2)
        guard let cleanedText = await cleanupAgent.cleanup(rawText) else {
            // Fall back to raw text if cleanup fails
            finalText = rawText
            state = .complete
            processingStep = ""
            return rawText
        }

        finalText = cleanedText
        state = .complete
        processingStep = ""

        return cleanedText
    }

    /// Process audio from file
    func processAudioFile(at url: URL) async -> String? {
        guard let audioData = try? Data(contentsOf: url) else {
            state = .error("Failed to read audio file")
            return nil
        }
        return await processAudio(audioData)
    }

    // MARK: - Reset

    func reset() {
        state = .idle
        finalText = ""
        rawTranscription = ""
        processingStep = ""
        voxtralService.reset()
        cleanupAgent.reset()
    }
}
