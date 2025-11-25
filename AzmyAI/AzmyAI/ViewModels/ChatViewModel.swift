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
    private var streamingTimer: Timer?
    private var currentStreamingIndex: Int = 0

    // Streaming speed (characters per tick)
    private let streamingSpeed: Int = 3
    private let streamingInterval: TimeInterval = 0.02

    init() {
        // Add welcome message with streaming effect
        addWelcomeMessage()
    }

    // MARK: - Welcome Message
    private func addWelcomeMessage() {
        let context = ChatContext()
        let welcomeContent = """
            \(context.timeOfDay.greeting)! I'm Azmy, your personal AI assistant.

            I'm here to help you:
            - Plan your day based on your energy levels
            - Create events and manage your calendar
            - Track your wellness and habits
            - Give you personalized insights

            How can I help you today?
            """

        let welcomeMessage = ChatMessage(
            content: welcomeContent,
            role: .assistant,
            suggestions: [
                SuggestedAction(type: .quickReply, title: "Plan my day"),
                SuggestedAction(type: .quickReply, title: "Log my energy"),
                SuggestedAction(type: .quickReply, title: "What can you do?")
            ],
            isStreaming: true
        )
        messages.append(welcomeMessage)

        // Start streaming animation for welcome message
        startStreaming(messageId: welcomeMessage.id)
    }

    // MARK: - Streaming Animation
    private func startStreaming(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        currentStreamingIndex = 0
        let fullContent = messages[index].content

        streamingTimer?.invalidate()
        streamingTimer = Timer.scheduledTimer(withTimeInterval: streamingInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            DispatchQueue.main.async {
                guard let msgIndex = self.messages.firstIndex(where: { $0.id == messageId }) else {
                    timer.invalidate()
                    return
                }

                let targetIndex = min(self.currentStreamingIndex + self.streamingSpeed, fullContent.count)
                let endIndex = fullContent.index(fullContent.startIndex, offsetBy: targetIndex)
                self.messages[msgIndex].displayedContent = String(fullContent[..<endIndex])
                self.currentStreamingIndex = targetIndex

                // Check if streaming is complete
                if self.currentStreamingIndex >= fullContent.count {
                    self.messages[msgIndex].isStreaming = false
                    timer.invalidate()
                    self.streamingTimer = nil
                }
            }
        }
    }

    // MARK: - Send Message
    func sendMessage(profile: UserProfile, calendarEvents: [CalendarEvent] = []) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Stop any ongoing streaming
        streamingTimer?.invalidate()
        streamingTimer = nil

        // Complete any streaming messages
        for i in messages.indices {
            if messages[i].isStreaming {
                messages[i].displayedContent = messages[i].content
                messages[i].isStreaming = false
            }
        }

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

                    // Create streaming message
                    var streamingMessage = response
                    streamingMessage.isStreaming = true
                    streamingMessage.displayedContent = ""

                    self.messages.append(streamingMessage)

                    // Start streaming animation
                    self.startStreaming(messageId: streamingMessage.id)
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.error = error.localizedDescription

                    // Add error message with streaming
                    let errorMessage = ChatMessage(
                        content: "Sorry, I had trouble processing that. Please try again.",
                        role: .assistant,
                        isStreaming: true
                    )
                    self.messages.append(errorMessage)
                    self.startStreaming(messageId: errorMessage.id)
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

    // MARK: - Skip Streaming
    func skipStreaming() {
        streamingTimer?.invalidate()
        streamingTimer = nil

        for i in messages.indices {
            if messages[i].isStreaming {
                messages[i].displayedContent = messages[i].content
                messages[i].isStreaming = false
            }
        }
    }

    // MARK: - Clear Chat
    func clearChat() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        messages.removeAll()
        addWelcomeMessage()
    }

    deinit {
        streamingTimer?.invalidate()
    }
}
