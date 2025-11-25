//
//  ChatView.swift
//  AzmyAI
//
//  Dark theme chat interface
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var userProfile: UserProfileViewModel
    @EnvironmentObject var plannerViewModel: PlannerViewModel

    @State private var showQuickPrompts = true
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    messagesScrollView
                    quickPromptsSection
                    inputBarSection
                }
            }
            .navigationTitle("Azmy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menuButton
                }
            }
        }
    }

    // MARK: - Messages ScrollView
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatViewModel.messages) { message in
                        MessageBubble(message: message) { action in
                            handleAction(action)
                        }
                        .id(message.id)
                    }

                    if chatViewModel.isTyping {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Quick Prompts Section
    @ViewBuilder
    private var quickPromptsSection: some View {
        if showQuickPrompts && chatViewModel.messages.count <= 1 {
            QuickPromptsBar { prompt in
                handleQuickPrompt(prompt)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Input Bar Section
    private var inputBarSection: some View {
        ChatInputBar(
            text: $chatViewModel.inputText,
            isTyping: chatViewModel.isTyping,
            isFocused: $isInputFocused,
            onSend: sendMessage
        )
    }

    // MARK: - Menu Button
    private var menuButton: some View {
        Menu {
            Button {
                chatViewModel.clearChat()
                showQuickPrompts = true
            } label: {
                Label("New Chat", systemImage: "plus.bubble")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(AzmyColors.textSecondary)
        }
    }

    // MARK: - Actions
    private func handleAction(_ action: SuggestedAction) {
        chatViewModel.handleSuggestedAction(
            action,
            profile: userProfile.profile,
            calendarEvents: plannerViewModel.events
        )
    }

    private func handleQuickPrompt(_ prompt: QuickPrompt) {
        chatViewModel.handleQuickPrompt(
            prompt,
            profile: userProfile.profile,
            calendarEvents: plannerViewModel.events
        )
        showQuickPrompts = false
    }

    private func sendMessage() {
        chatViewModel.sendMessage(
            profile: userProfile.profile,
            calendarEvents: plannerViewModel.events
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if let lastId = chatViewModel.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    var onAction: ((SuggestedAction) -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                if message.role == .assistant {
                    assistantMessageView
                } else {
                    userMessageView
                }
                timestampView
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var assistantMessageView: some View {
        HStack(alignment: .top, spacing: 8) {
            avatarView
            VStack(alignment: .leading, spacing: 8) {
                messageTextView(isUser: false)
                suggestedActionsView
            }
        }
    }

    private var userMessageView: some View {
        messageTextView(isUser: true)
    }

    private var avatarView: some View {
        Circle()
            .fill(AzmyColors.gradientBlue)
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
    }

    private func messageTextView(isUser: Bool) -> some View {
        Text(message.content)
            .font(AzmyFonts.body())
            .foregroundColor(isUser ? .white : AzmyColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isUser ? AzmyColors.accentBlue : AzmyColors.backgroundCard)
            .cornerRadius(16)
    }

    private var timestampView: some View {
        Text(message.timestamp, style: .time)
            .font(AzmyFonts.caption())
            .foregroundColor(AzmyColors.textTertiary)
            .padding(.horizontal, message.role == .assistant ? 40 : 0)
    }

    @ViewBuilder
    private var suggestedActionsView: some View {
        if let suggestions = message.suggestions, !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { action in
                        SuggestionButton(action: action) {
                            onAction?(action)
                        }
                    }
                }
                .padding(.leading, 40)
            }
        }
    }
}

// MARK: - Suggestion Button
struct SuggestionButton: View {
    let action: SuggestedAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(action.title)
                .font(AzmyFonts.bodySmall())
                .foregroundColor(AzmyColors.accentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AzmyColors.accentBlue.opacity(0.15))
                .cornerRadius(20)
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var dotIndex = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(AzmyColors.gradientBlue)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                )

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AzmyColors.textSecondary)
                        .frame(width: 8, height: 8)
                        .offset(y: dotIndex == index ? -4 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(16)

            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotIndex = (dotIndex + 1) % 3
            }
        }
    }
}

// MARK: - Quick Prompts Bar
struct QuickPromptsBar: View {
    let onSelect: (QuickPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(AzmyFonts.bodySmall())
                .foregroundColor(AzmyColors.textSecondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(QuickPrompt.samples) { prompt in
                        QuickPromptChip(prompt: prompt) {
                            onSelect(prompt)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(AzmyColors.backgroundSecondary)
    }
}

struct QuickPromptChip: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 14))
                Text(prompt.title)
                    .font(AzmyFonts.bodySmall())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AzmyColors.backgroundCard)
            .foregroundColor(AzmyColors.textPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AzmyColors.separator, lineWidth: 1)
            )
        }
    }
}

// MARK: - Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    let isTyping: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    var body: some View {
        HStack(spacing: 12) {
            textField
            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AzmyColors.backgroundPrimary)
    }

    private var textField: some View {
        TextField("Ask Azmy anything...", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(AzmyFonts.body())
            .foregroundColor(AzmyColors.textPrimary)
            .lineLimit(1...5)
            .focused(isFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AzmyColors.backgroundSecondary)
            .cornerRadius(AzmyRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.large)
                    .stroke(AzmyColors.separator, lineWidth: 1)
            )
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(canSend ? AzmyColors.accentBlue : AzmyColors.textTertiary)
        }
        .disabled(!canSend)
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatViewModel())
        .environmentObject(UserProfileViewModel())
        .environmentObject(PlannerViewModel())
        .preferredColorScheme(.dark)
}
