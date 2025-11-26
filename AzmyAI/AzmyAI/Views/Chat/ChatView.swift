//
//  ChatView.swift
//  AzmyAI
//
//  Dark theme chat interface with streaming text
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
                        } onTap: {
                            // Tap to skip streaming
                            if message.isStreaming {
                                chatViewModel.skipStreaming()
                            }
                        }
                        .id(message.id)
                    }

                    // Show thinking indicator with retry info (always visible while AI is processing)
                    if chatViewModel.isThinking {
                        ThinkingIndicator(
                            retryAttempt: chatViewModel.currentRetryAttempt,
                            maxRetries: chatViewModel.maxRetryAttempts
                        )
                        .id("thinking")
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatViewModel.messages.last?.displayedContent) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatViewModel.isThinking) { _, _ in
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
            isProcessing: chatViewModel.isThinking,
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
    var onTap: (() -> Void)?

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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private var assistantMessageView: some View {
        HStack(alignment: .top, spacing: 8) {
            avatarView
            VStack(alignment: .leading, spacing: 8) {
                StreamingTextView(message: message)
                suggestedActionsView
            }
        }
    }

    private var userMessageView: some View {
        messageTextView(content: message.content, isUser: true)
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

    private func messageTextView(content: String, isUser: Bool) -> some View {
        Text(content)
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
        // Only show suggestions when streaming is complete
        if let suggestions = message.suggestions, !suggestions.isEmpty, !message.isStreaming {
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

// MARK: - Streaming Text View
struct StreamingTextView: View {
    let message: ChatMessage
    @State private var showCursor = true

    let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(message.displayedContent)
                .font(AzmyFonts.body())
                .foregroundColor(AzmyColors.textPrimary)

            // Blinking cursor while streaming
            if message.isStreaming {
                Text("|")
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.accentBlue)
                    .opacity(showCursor ? 1 : 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(16)
        .onReceive(cursorTimer) { _ in
            if message.isStreaming {
                showCursor.toggle()
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

// MARK: - Thinking Indicator (with retry info)
struct ThinkingIndicator: View {
    let retryAttempt: Int
    let maxRetries: Int

    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Animated avatar with pulse effect
            Circle()
                .fill(AzmyColors.gradientBlue)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotationAngle))
                )
                .scaleEffect(pulseScale)

            VStack(alignment: .leading, spacing: 4) {
                // Main thinking message
                HStack(spacing: 6) {
                    // Animated thinking dots
                    ThinkingDots()

                    Text(thinkingText)
                        .font(AzmyFonts.bodySmall())
                        .foregroundColor(AzmyColors.textSecondary)
                }

                // Show retry info if retrying
                if retryAttempt > 1 {
                    Text("Attempt \(retryAttempt) of \(maxRetries)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AzmyColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(16)

            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                rotationAngle = (rotationAngle + 5).truncatingRemainder(dividingBy: 360)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }

    private var thinkingText: String {
        if retryAttempt > 1 {
            return "Reconnecting..."
        }
        return "Thinking..."
    }
}

// MARK: - Thinking Dots Animation
struct ThinkingDots: View {
    @State private var phase: Int = 0
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == index ? 1.3 : 1.0)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = (phase + 1) % 3
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if phase == index {
            return AzmyColors.accentBlue
        }
        return AzmyColors.textTertiary
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

// MARK: - Chat Input Bar (Telegram-style voice with beautiful animations)
struct ChatInputBar: View {
    @Binding var text: String
    let isProcessing: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    @StateObject private var audioService = AudioRecordingService.shared
    @StateObject private var voicePipeline = VoicePipelineManager.shared

    // Can send if text is not empty
    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Recording overlay with beautiful animations
            if audioService.isRecording {
                VoiceRecordingOverlay(
                    audioService: audioService,
                    voicePipeline: voicePipeline
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .padding(.bottom, 8)
            }

            // Processing overlay
            if voicePipeline.isProcessing && !audioService.isRecording {
                VoiceProcessingView(processingStep: voicePipeline.processingStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .padding(.bottom, 8)
            }

            HStack(alignment: .bottom, spacing: 12) {
                // Text field with smooth border animation
                TextField("Message", text: $text, axis: .vertical)
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
                            .stroke(
                                audioService.isRecording ? AzmyColors.accentBlue :
                                    (isFocused.wrappedValue ? AzmyColors.accentBlue.opacity(0.5) : AzmyColors.separator),
                                lineWidth: audioService.isRecording ? 2 : 1
                            )
                            .animation(.easeInOut(duration: 0.2), value: audioService.isRecording)
                    )

                // Send OR Voice button with morph animation
                ZStack {
                    if hasText {
                        Button(action: onSend) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AzmyColors.accentBlue)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Telegram-style voice button with onboarding
                        TelegramVoiceButton(
                            audioService: audioService,
                            voicePipeline: voicePipeline
                        ) { transcribedText in
                            // Animate text appearing character by character
                            animateTextInput(transcribedText)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AzmyColors.backgroundPrimary)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioService.isRecording)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: voicePipeline.isProcessing)
    }

    // Animate text appearing with typing effect
    private func animateTextInput(_ fullText: String) {
        text = ""
        var currentIndex = 0
        let characters = Array(fullText)

        Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { timer in
            if currentIndex < characters.count {
                text += String(characters[currentIndex])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Voice Recording View
struct VoiceRecordingView: View {
    @ObservedObject var audioService: AudioRecordingService
    @ObservedObject var voicePipeline: VoicePipelineManager

    let onComplete: (String?) -> Void
    let onCancel: () -> Void

    @State private var isProcessingVoice = false

    var body: some View {
        VStack(spacing: 16) {
            // Status text
            HStack {
                if isProcessingVoice {
                    Text(voicePipeline.processingStep.isEmpty ? "Processing..." : voicePipeline.processingStep)
                        .font(AzmyFonts.bodySmall())
                        .foregroundColor(AzmyColors.accentBlue)
                } else if audioService.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Recording...")
                        .font(AzmyFonts.bodySmall())
                        .foregroundColor(AzmyColors.textSecondary)
                    Spacer()
                    Text(formatDuration(audioService.recordingDuration))
                        .font(AzmyFonts.caption())
                        .foregroundColor(AzmyColors.textTertiary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            // Audio level visualization
            if audioService.isRecording {
                AudioLevelView(level: audioService.audioLevel)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
            }

            // Processing indicator
            if isProcessingVoice {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Transcribing with Voxtral...")
                        .font(AzmyFonts.bodySmall())
                        .foregroundColor(AzmyColors.textSecondary)
                }
            }

            // Action buttons
            HStack(spacing: 20) {
                // Cancel button
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AzmyColors.textTertiary)
                }
                .disabled(isProcessingVoice)

                Spacer()

                // Done button (stop and process)
                Button(action: stopAndProcess) {
                    ZStack {
                        Circle()
                            .fill(AzmyColors.accentBlue)
                            .frame(width: 60, height: 60)

                        if isProcessingVoice {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isProcessingVoice || !audioService.isRecording)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 16)
        .background(AzmyColors.backgroundSecondary)
        .cornerRadius(AzmyRadius.large)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func stopAndProcess() {
        guard let audioData = audioService.stopRecording() else {
            onComplete(nil)
            return
        }

        isProcessingVoice = true

        Task {
            // Process through voice pipeline (Voxtral + TextCleanup)
            let result = await voicePipeline.processAudio(audioData)

            await MainActor.run {
                isProcessingVoice = false
                onComplete(result)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Level Visualization
struct AudioLevelView: View {
    let level: Float

    private let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4)
                    .frame(height: barHeight(for: index))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        let active = level > threshold
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 40

        if active {
            // Add some randomness for visual interest
            let randomFactor = CGFloat.random(in: 0.7...1.0)
            return min(maxHeight, baseHeight + CGFloat(level) * (maxHeight - baseHeight) * randomFactor)
        } else {
            return baseHeight
        }
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        if level > threshold {
            if threshold > 0.8 {
                return .red
            } else if threshold > 0.6 {
                return .orange
            } else {
                return AzmyColors.accentBlue
            }
        } else {
            return AzmyColors.backgroundTertiary
        }
    }
}

// MARK: - Voice Onboarding Manager

class VoiceOnboardingManager: ObservableObject {
    static let shared = VoiceOnboardingManager()

    @Published var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "hasSeenVoiceOnboarding")
        }
    }

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenVoiceOnboarding")
    }

    func markOnboardingSeen() {
        hasSeenOnboarding = true
    }
}

// MARK: - Telegram Voice Button

struct TelegramVoiceButton: View {
    @ObservedObject var audioService: AudioRecordingService
    @ObservedObject var voicePipeline: VoicePipelineManager
    @StateObject private var onboardingManager = VoiceOnboardingManager.shared

    let onTranscription: (String) -> Void

    @State private var isPressed = false
    @State private var dragOffset: CGFloat = 0
    @State private var isProcessing = false
    @State private var recordingCancelled = false
    @State private var showOnboarding = false
    @State private var pulseAnimation = false
    @State private var waveAnimation = false

    private let cancelThreshold: CGFloat = -100

    var body: some View {
        ZStack {
            if showOnboarding {
                voiceOnboardingTooltip
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            voiceButton
        }
        .onAppear {
            if !onboardingManager.hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showOnboarding = true
                    }
                }
            }
        }
    }

    private var voiceOnboardingTooltip: some View {
        VStack(spacing: 0) {
            // Tooltip content
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AzmyColors.accentBlue)
                    Text("Voice Input")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Instructions
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AzmyColors.accentBlue)
                            .frame(width: 20)
                        Text("Hold to record")
                            .font(.system(size: 13))
                            .foregroundColor(AzmyColors.textSecondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AzmyColors.accentBlue)
                            .frame(width: 20)
                        Text("Release to send")
                            .font(.system(size: 13))
                            .foregroundColor(AzmyColors.textSecondary)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text("Slide left to cancel")
                            .font(.system(size: 13))
                            .foregroundColor(AzmyColors.textTertiary)
                    }
                }

                // Got it button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showOnboarding = false
                        onboardingManager.markOnboardingSeen()
                    }
                }) {
                    Text("Got it!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AzmyColors.accentBlue)
                        .cornerRadius(10)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(14)

            // Arrow pointing to mic button
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.backgroundCard)
                .offset(x: 60, y: -2)
        }
        .frame(width: 200)
        .offset(x: -80, y: -160)
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    private var voiceButton: some View {
        ZStack {
            // Pulse animation when onboarding is showing
            if showOnboarding {
                Circle()
                    .fill(AzmyColors.accentBlue.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.6)
            }

            if isPressed || audioService.isRecording {
                Circle()
                    .fill(AzmyColors.accentBlue.opacity(0.15))
                    .frame(width: 60, height: 60)
                    .scaleEffect(waveAnimation ? 1.8 : 1.0)
                    .opacity(waveAnimation ? 0 : 0.5)
                Circle()
                    .fill(AzmyColors.accentBlue.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .scaleEffect(waveAnimation ? 1.4 : 1.0)
                    .opacity(waveAnimation ? 0.3 : 0.5)
            }
            ZStack {
                Circle()
                    .fill(showOnboarding ? AzmyColors.accentBlue.opacity(0.15) : buttonBackgroundColor)
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPressed ? 1.2 : 1.0)
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: buttonIcon)
                        .font(.system(size: isPressed ? 22 : 20, weight: .medium))
                        .foregroundColor(showOnboarding ? AzmyColors.accentBlue : buttonIconColor)
                }
            }
            .offset(x: dragOffset * 0.3)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleDragChange(value) }
                .onEnded { value in handleDragEnd(value) }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3), value: dragOffset)
        .onChange(of: audioService.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                    waveAnimation = true
                }
            } else {
                waveAnimation = false
            }
        }
    }

    private var buttonBackgroundColor: Color {
        if recordingCancelled { return .red.opacity(0.8) }
        else if isPressed || audioService.isRecording { return AzmyColors.accentBlue }
        else { return Color.clear }
    }

    private var buttonIcon: String {
        if recordingCancelled { return "xmark" }
        else if audioService.isRecording { return "mic.fill" }
        else { return "mic" }
    }

    private var buttonIconColor: Color {
        if isPressed || audioService.isRecording || recordingCancelled { return .white }
        return AzmyColors.textSecondary
    }

    private func handleDragChange(_ value: DragGesture.Value) {
        if showOnboarding {
            withAnimation {
                showOnboarding = false
                onboardingManager.markOnboardingSeen()
            }
        }
        if !isPressed && !isProcessing {
            isPressed = true
            recordingCancelled = false
            Task {
                do {
                    try await audioService.startRecording()
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } catch {
                    isPressed = false
                }
            }
        }
        if value.translation.width < 0 {
            dragOffset = max(value.translation.width, cancelThreshold * 1.5)
            if dragOffset < cancelThreshold && !recordingCancelled {
                recordingCancelled = true
                audioService.cancelRecording()
                isPressed = false
                waveAnimation = false
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        isPressed = false
        dragOffset = 0
        if recordingCancelled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { recordingCancelled = false }
            return
        }
        if audioService.isRecording {
            guard let audioData = audioService.stopRecording() else { return }
            isProcessing = true
            Task {
                if let result = await voicePipeline.processAudio(audioData) {
                    await MainActor.run { onTranscription(result) }
                }
                await MainActor.run { isProcessing = false }
            }
        }
    }
}

// MARK: - Voice Recording Overlay

struct VoiceRecordingOverlay: View {
    @ObservedObject var audioService: AudioRecordingService
    @ObservedObject var voicePipeline: VoicePipelineManager
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .offset(x: sin(wavePhase) * 3)
                Text("Slide to cancel")
                    .font(.system(size: 13))
            }
            .foregroundColor(AzmyColors.textTertiary)
            Spacer()
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .scaleEffect(audioService.isRecording ? 1.5 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: audioService.isRecording)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                Text(formatDuration(audioService.recordingDuration))
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                VoiceWaveform(level: audioService.audioLevel)
                    .frame(width: 50, height: 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AzmyColors.backgroundCard)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}

// MARK: - Voice Waveform

struct VoiceWaveform: View {
    let level: Float
    private let barCount = 8

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(index))
                    .frame(width: 3, height: barHeight(index))
                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: level)
            }
        }
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 24
        let waveOffset = sin(Double(index) * 0.8 + Double(level) * 10) * 0.3
        let adjustedLevel = max(0, min(1, Double(level) + waveOffset))
        return baseHeight + CGFloat(adjustedLevel) * (maxHeight - baseHeight)
    }

    private func barColor(_ index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        if level > threshold * 0.8 {
            return threshold > 0.7 ? .orange : AzmyColors.accentBlue
        }
        return AzmyColors.textTertiary.opacity(0.5)
    }
}

// MARK: - Voice Processing View

struct VoiceProcessingView: View {
    let processingStep: String
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AzmyColors.accentBlue.opacity(0.3), lineWidth: 3)
                    .frame(width: 24, height: 24)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AzmyColors.accentBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(rotation))
            }
            Text(processingStep.isEmpty ? "Processing..." : processingStep)
                .font(.system(size: 13))
                .foregroundColor(AzmyColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(ChatViewModel())
        .environmentObject(UserProfileViewModel())
        .environmentObject(PlannerViewModel())
        .preferredColorScheme(.dark)
}
