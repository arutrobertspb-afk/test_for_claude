//
//  ChatView.swift
//  AzmyAI
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
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.md) {
                            ForEach(chatViewModel.messages) { message in
                                MessageBubble(message: message) { action in
                                    chatViewModel.handleSuggestedAction(
                                        action,
                                        profile: userProfile.profile,
                                        calendarEvents: plannerViewModel.events
                                    )
                                }
                                .id(message.id)
                            }

                            if chatViewModel.isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    }
                    .onChange(of: chatViewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(chatViewModel.messages.last?.id ?? "typing", anchor: .bottom)
                        }
                    }
                }

                // Quick prompts (collapsible)
                if showQuickPrompts && chatViewModel.messages.count <= 1 {
                    QuickPromptsBar { prompt in
                        chatViewModel.handleQuickPrompt(
                            prompt,
                            profile: userProfile.profile,
                            calendarEvents: plannerViewModel.events
                        )
                        showQuickPrompts = false
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Input bar
                ChatInputBar(
                    text: $chatViewModel.inputText,
                    isTyping: chatViewModel.isTyping,
                    isFocused: $isInputFocused
                ) {
                    chatViewModel.sendMessage(
                        profile: userProfile.profile,
                        calendarEvents: plannerViewModel.events
                    )
                }
            }
            .navigationTitle("Azmy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            chatViewModel.clearChat()
                            showQuickPrompts = true
                        } label: {
                            Label("New Chat", systemImage: "plus.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    var onAction: ((SuggestedAction) -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: Spacing.xs) {
                // Message content
                if message.role == .assistant {
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        // Avatar
                        Circle()
                            .fill(Color.azuryGradient)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            messageContent
                            suggestedActions
                        }
                    }
                } else {
                    messageContent
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.azuryCaption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, message.role == .assistant ? 40 : 0)
            }

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var messageContent: some View {
        Text(LocalizedStringKey(message.content))
            .font(.azuryBody)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                message.role == .user
                    ? AnyView(Color.azuryGradient)
                    : AnyView(Color.azurySecondaryBackground)
            )
            .foregroundColor(message.role == .user ? .white : .primary)
            .cornerRadius(CornerRadius.large, corners: message.role == .user
                ? [.topLeft, .topRight, .bottomLeft]
                : [.topLeft, .topRight, .bottomRight])
    }

    @ViewBuilder
    private var suggestedActions: some View {
        if let suggestions = message.suggestions, !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(suggestions) { action in
                        Button {
                            onAction?(action)
                        } label: {
                            Text(action.title)
                                .font(.azuryFootnote)
                                .foregroundColor(.azuryBlue)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(Color.azuryBlue.opacity(0.1))
                                .cornerRadius(CornerRadius.circular)
                        }
                    }
                }
                .padding(.leading, 40)
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationOffset = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            Circle()
                .fill(Color.azuryGradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                )

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset == index ? -4 : 0)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.azurySecondaryBackground)
            .cornerRadius(CornerRadius.large, corners: [.topLeft, .topRight, .bottomRight])

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                animationOffset = (animationOffset + 1) % 3
            }
        }
    }
}

// MARK: - Quick Prompts Bar
struct QuickPromptsBar: View {
    let onSelect: (QuickPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Quick actions")
                .font(.azuryFootnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(QuickPrompt.samples) { prompt in
                        QuickPromptChip(prompt: prompt) {
                            onSelect(prompt)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(Color.azurySecondaryBackground.opacity(0.5))
    }
}

struct QuickPromptChip: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 14))

                Text(prompt.title)
                    .font(.azuryFootnote)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.azurySecondaryBackground)
            .foregroundColor(.primary)
            .cornerRadius(CornerRadius.circular)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.circular)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Ask Azmy anything...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused(isFocused)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.azurySecondaryBackground)
                .cornerRadius(CornerRadius.large)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        canSend
                            ? AnyShapeStyle(Color.azuryGradient)
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
            }
            .disabled(!canSend || isTyping)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.azuryBackground)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatViewModel())
        .environmentObject(UserProfileViewModel())
        .environmentObject(PlannerViewModel())
}
