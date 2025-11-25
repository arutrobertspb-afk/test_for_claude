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

    private let aiService = AzmyAIService.shared
    private let memory = ConversationMemory.shared
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
        let userName = memory.userContext.name ?? ""
        let greeting = userName.isEmpty ? context.timeOfDay.greeting : "\(context.timeOfDay.greeting), \(userName)"

        let welcomeContent = """
            \(greeting)! I'm Azmy, your personal AI assistant.

            I can help you:
            • Manage your calendar (create, edit, delete events)
            • Analyze your schedule and suggest breaks
            • Give personalized advice based on your patterns
            • Track your wellness and habits

            What would you like to do?
            """

        let welcomeMessage = ChatMessage(
            content: welcomeContent,
            role: .assistant,
            suggestions: [
                SuggestedAction(type: .quickReply, title: "What's my schedule today?"),
                SuggestedAction(type: .quickReply, title: "Analyze my week"),
                SuggestedAction(type: .createEvent, title: "Schedule a meeting")
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

        // Update user name in memory if detected
        if !profile.name.isEmpty {
            memory.updateUserName(profile.name)
        }

        // Send to AI using new service
        Task {
            let response = await aiService.sendMessage(text)

            await MainActor.run {
                self.isTyping = false

                // Determine suggestions based on response content
                var suggestions: [SuggestedAction] = []
                let lowerResponse = response.lowercased()

                if lowerResponse.contains("event") || lowerResponse.contains("meeting") {
                    suggestions.append(SuggestedAction(type: .quickReply, title: "Show my schedule"))
                }
                if lowerResponse.contains("break") || lowerResponse.contains("rest") {
                    suggestions.append(SuggestedAction(type: .quickReply, title: "Block rest time"))
                }
                if suggestions.isEmpty {
                    suggestions = [
                        SuggestedAction(type: .quickReply, title: "What else can you do?"),
                        SuggestedAction(type: .quickReply, title: "Analyze my schedule")
                    ]
                }

                // Create streaming message
                let streamingMessage = ChatMessage(
                    content: response,
                    role: .assistant,
                    suggestions: suggestions,
                    isStreaming: true
                )

                self.messages.append(streamingMessage)

                // Start streaming animation
                self.startStreaming(messageId: streamingMessage.id)
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
        memory.clearConversation()
        addWelcomeMessage()
    }

    // MARK: - Quick AI Actions
    func analyzeSchedule() {
        Task {
            let response = await aiService.analyzeToday()
            await MainActor.run {
                let message = ChatMessage(
                    content: response,
                    role: .assistant,
                    suggestions: [
                        SuggestedAction(type: .quickReply, title: "Suggest breaks"),
                        SuggestedAction(type: .quickReply, title: "Block focus time")
                    ],
                    isStreaming: true
                )
                self.messages.append(message)
                self.startStreaming(messageId: message.id)
            }
        }
    }

    deinit {
        streamingTimer?.invalidate()
    }
}
