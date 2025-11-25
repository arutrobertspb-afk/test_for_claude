//
//  AIService.swift
//  AzmyAI
//

import Foundation

class AIService: ObservableObject {
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private var apiKey: String {
        // In production, use secure storage like Keychain
        UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }

    @Published var isProcessing = false

    // MARK: - System Prompt
    private func buildSystemPrompt(context: ChatContext, profile: UserProfile) -> String {
        var prompt = """
        You are Azmy, a friendly and helpful personal AI assistant. Your role is to help users optimize their daily life by understanding their schedule, health data, and personal preferences.

        PERSONALITY:
        - Warm, supportive, and encouraging
        - Concise but thorough when needed
        - Proactive in offering helpful suggestions
        - Uses casual but professional language

        CAPABILITIES:
        - Help plan and optimize daily schedules
        - Create calendar events from natural language
        - Provide insights based on health data and patterns
        - Suggest optimal times for activities based on energy levels
        - Track and encourage healthy habits
        - Offer personalized recommendations

        CURRENT CONTEXT:
        - Time of day: \(context.timeOfDay.rawValue)
        """

        // Add user preferences
        if let traits = profile.personalityTraits {
            prompt += """

            USER PROFILE:
            - Chronotype: \(traits.chronotype.rawValue)
            - Energy pattern: \(traits.energyPattern.rawValue)
            - Work style: \(traits.workStyle.rawValue)
            """
        }

        // Add health context
        if let health = context.healthSnapshot {
            prompt += "\n\nHEALTH DATA TODAY:"
            if let sleep = health.sleepHours {
                prompt += "\n- Sleep: \(String(format: "%.1f", sleep)) hours"
            }
            if let steps = health.steps {
                prompt += "\n- Steps: \(steps)"
            }
            if let energy = health.energyLevel {
                prompt += "\n- Energy level: \(energy)/10"
            }
        }

        // Add calendar context
        if !context.recentEvents.isEmpty {
            prompt += "\n\nTODAY'S SCHEDULE:"
            for event in context.recentEvents.prefix(5) {
                prompt += "\n- \(event.formattedTime): \(event.title)"
            }
        }

        // Add pending tasks
        if !context.pendingTasks.isEmpty {
            prompt += "\n\nPENDING TASKS:"
            for task in context.pendingTasks.prefix(5) {
                prompt += "\n- \(task.title)"
            }
        }

        prompt += """

        RESPONSE FORMAT:
        - Keep responses concise and actionable
        - When suggesting calendar events, format clearly
        - Use emoji sparingly and appropriately
        - If user wants to create an event, extract: title, date/time, duration
        - Acknowledge health data naturally when relevant

        Remember: You're helping optimize their day, not just answering questions.
        """

        return prompt
    }

    // MARK: - Send Message
    func sendMessage(
        _ message: String,
        context: ChatContext,
        profile: UserProfile,
        conversationHistory: [ChatMessage]
    ) async throws -> ChatMessage {
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }

        // Build messages array
        var messages: [[String: String]] = [
            ["role": "system", "content": buildSystemPrompt(context: context, profile: profile)]
        ]

        // Add conversation history (last 10 messages)
        for msg in conversationHistory.suffix(10) {
            messages.append([
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ])
        }

        // Add current message
        messages.append(["role": "user", "content": message])

        // Create request
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 1000,
            "temperature": 0.7
        ]

        guard let url = URL(string: baseURL) else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // For demo purposes, if no API key, return simulated response
        if apiKey.isEmpty {
            return try await simulateResponse(for: message, context: context)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = decoded.choices.first?.message.content else {
            throw AIServiceError.emptyResponse
        }

        // Parse for suggested actions
        let suggestions = parseActionsFromResponse(content)

        return ChatMessage(
            content: content,
            role: .assistant,
            suggestions: suggestions
        )
    }

    // MARK: - Simulate Response (Demo Mode)
    private func simulateResponse(for message: String, context: ChatContext) async throws -> ChatMessage {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let lowercaseMessage = message.lowercased()

        // Morning planning
        if lowercaseMessage.contains("plan") && lowercaseMessage.contains("day") {
            return ChatMessage(
                content: """
                \(context.timeOfDay.greeting)! Let me help you plan your day.

                Based on your schedule, here's what I suggest:

                **Morning Focus Block** (9-11 AM)
                Your peak energy time - perfect for deep work.

                **Quick Wins** (11 AM - 12 PM)
                Tackle smaller tasks before lunch.

                **Afternoon Sessions**
                Schedule meetings after 2 PM when energy naturally dips.

                Would you like me to block focus time on your calendar?
                """,
                role: .assistant,
                suggestions: [
                    SuggestedAction(
                        type: .createEvent,
                        title: "Block Focus Time",
                        description: "Add 2-hour focus block"
                    ),
                    SuggestedAction(
                        type: .quickReply,
                        title: "Show free slots"
                    )
                ]
            )
        }

        // Energy/Mood tracking
        if lowercaseMessage.contains("energy") || lowercaseMessage.contains("mood") || lowercaseMessage.contains("tired") {
            return ChatMessage(
                content: """
                I'd love to log how you're feeling!

                On a scale of 1-10:
                - **Energy level**: How physically energized do you feel?
                - **Mood**: How's your emotional state?

                This helps me give you better recommendations throughout the day.
                """,
                role: .assistant,
                suggestions: [
                    SuggestedAction(type: .quickReply, title: "Energy: 7/10"),
                    SuggestedAction(type: .quickReply, title: "Energy: 5/10"),
                    SuggestedAction(type: .quickReply, title: "Energy: 3/10")
                ]
            )
        }

        // Scheduling
        if lowercaseMessage.contains("schedule") || lowercaseMessage.contains("meeting") || lowercaseMessage.contains("event") {
            return ChatMessage(
                content: """
                I can help you schedule that!

                Just tell me:
                - What's the event about?
                - When should it happen?
                - How long will it take?

                For example: "Team standup tomorrow at 10am for 30 minutes"
                """,
                role: .assistant,
                suggestions: [
                    SuggestedAction(
                        type: .createEvent,
                        title: "Create Event",
                        description: "Open event creator"
                    )
                ]
            )
        }

        // Sleep
        if lowercaseMessage.contains("sleep") {
            return ChatMessage(
                content: """
                Sleep is crucial for productivity!

                Based on your chronotype, I recommend:
                - **Bedtime**: 10:30 PM - 11:00 PM
                - **Wake time**: 6:30 AM - 7:00 AM

                Want me to set up bedtime reminders?
                """,
                role: .assistant,
                suggestions: [
                    SuggestedAction(type: .setReminder, title: "Set bedtime reminder"),
                    SuggestedAction(type: .viewInsight, title: "View sleep trends")
                ]
            )
        }

        // Default response
        return ChatMessage(
            content: """
            I'm here to help you optimize your day! I can:

            - **Plan your day** based on your energy patterns
            - **Schedule events** from natural language
            - **Track your energy & mood** throughout the day
            - **Suggest breaks** when you need them
            - **Analyze your patterns** and give insights

            What would you like to do?
            """,
            role: .assistant,
            suggestions: [
                SuggestedAction(type: .quickReply, title: "Plan my day"),
                SuggestedAction(type: .quickReply, title: "Log energy"),
                SuggestedAction(type: .quickReply, title: "Schedule something")
            ]
        )
    }

    // MARK: - Parse Actions
    private func parseActionsFromResponse(_ content: String) -> [SuggestedAction]? {
        var actions: [SuggestedAction] = []

        // Detect if response suggests creating an event
        if content.lowercased().contains("create") && content.lowercased().contains("event") ||
           content.lowercased().contains("schedule") && content.lowercased().contains("calendar") {
            actions.append(SuggestedAction(
                type: .createEvent,
                title: "Create Event",
                description: "Add to calendar"
            ))
        }

        // Detect reminder suggestions
        if content.lowercased().contains("reminder") || content.lowercased().contains("remind you") {
            actions.append(SuggestedAction(
                type: .setReminder,
                title: "Set Reminder"
            ))
        }

        return actions.isEmpty ? nil : actions
    }
}

// MARK: - OpenAI Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

// MARK: - Errors
enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case emptyResponse
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code):
            return "API error: \(code)"
        case .emptyResponse:
            return "Empty response from AI"
        case .encodingError:
            return "Failed to encode request"
        }
    }
}
