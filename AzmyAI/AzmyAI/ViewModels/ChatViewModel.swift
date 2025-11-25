//
//  ChatViewModel.swift
//  AzmyAI
//

import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var error: String?

    private let aiService = AIService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Add welcome message
        addWelcomeMessage()
    }

    // MARK: - Welcome Message
    private func addWelcomeMessage() {
        let context = ChatContext()
        let welcomeMessage = ChatMessage(
            content: """
            \(context.timeOfDay.greeting)! I'm Azmy, your personal AI assistant.

            I'm here to help you:
            - Plan your day based on your energy levels
            - Create events and manage your calendar
            - Track your wellness and habits
            - Give you personalized insights

            How can I help you today?
            """,
            role: .assistant,
            suggestions: [
                SuggestedAction(type: .quickReply, title: "Plan my day"),
                SuggestedAction(type: .quickReply, title: "Log my energy"),
                SuggestedAction(type: .quickReply, title: "What can you do?")
            ]
        )
        messages.append(welcomeMessage)
    }

    // MARK: - Send Message
    func sendMessage(profile: UserProfile, calendarEvents: [CalendarEvent] = []) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(content: text, role: .user)
        messages.append(userMessage)
        inputText = ""

        // Show typing indicator
        isTyping = true

        // Build context
        var context = ChatContext()
        context.recentEvents = calendarEvents
        context.healthSnapshot = profile.healthData

        // Send to AI
        Task {
            do {
                let response = try await aiService.sendMessage(
                    text,
                    context: context,
                    profile: profile,
                    conversationHistory: messages
                )

                await MainActor.run {
                    self.isTyping = false
                    self.messages.append(response)
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.error = error.localizedDescription

                    // Add error message
                    let errorMessage = ChatMessage(
                        content: "Sorry, I had trouble processing that. Please try again.",
                        role: .assistant
                    )
                    self.messages.append(errorMessage)
                }
            }
        }
    }

    // MARK: - Quick Actions
    func handleQuickPrompt(_ prompt: QuickPrompt, profile: UserProfile, calendarEvents: [CalendarEvent] = []) {
        inputText = prompt.prompt
        sendMessage(profile: profile, calendarEvents: calendarEvents)
    }

    func handleSuggestedAction(_ action: SuggestedAction, profile: UserProfile, calendarEvents: [CalendarEvent] = []) {
        switch action.type {
        case .quickReply:
            inputText = action.title
            sendMessage(profile: profile, calendarEvents: calendarEvents)
        case .createEvent:
            // This would trigger event creation flow
            inputText = "I want to create an event"
            sendMessage(profile: profile, calendarEvents: calendarEvents)
        case .setReminder:
            inputText = "Set a reminder for me"
            sendMessage(profile: profile, calendarEvents: calendarEvents)
        case .viewInsight:
            inputText = "Show me my insights"
            sendMessage(profile: profile, calendarEvents: calendarEvents)
        case .openQuiz:
            // Would navigate to quiz
            break
        case .suggestTask:
            inputText = "Suggest tasks for today"
            sendMessage(profile: profile, calendarEvents: calendarEvents)
        }
    }

    // MARK: - Clear Chat
    func clearChat() {
        messages.removeAll()
        addWelcomeMessage()
    }
}
