//
//  TelegramVoiceButton.swift
//  AzmyAI
//
//  Telegram-style voice recording button with beautiful animations
//  - Hold to record
//  - Release to send
//  - Slide left to cancel
//  - First-time onboarding tutorial
//

import SwiftUI
import AVFoundation

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
    @State private var showCancelHint = false
    @State private var recordingCancelled = false
    @State private var showOnboarding = false
    @State private var pulseAnimation = false
    @State private var waveAnimation = false

    private let cancelThreshold: CGFloat = -100

    var body: some View {
        ZStack {
            // Onboarding tooltip (first time)
            if showOnboarding {
                voiceOnboardingTooltip
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            // Main button with animations
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

    // MARK: - Voice Onboarding Tooltip

    private var voiceOnboardingTooltip: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 12) {
                // Animated mic icon
                ZStack {
                    Circle()
                        .fill(AzmyColors.accentBlue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AzmyColors.accentBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Messages")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Hold to record, release to send")
                        .font(.system(size: 12))
                        .foregroundColor(AzmyColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10))
                        Text("Slide left to cancel")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AzmyColors.textTertiary)
                }

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showOnboarding = false
                        onboardingManager.markOnboardingSeen()
                    }
                }) {
                    Text("Got it")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AzmyColors.accentBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AzmyColors.accentBlue.opacity(0.15))
                        .cornerRadius(12)
                }
            }
            .padding(16)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            // Arrow pointing to button
            Triangle()
                .fill(AzmyColors.backgroundCard)
                .frame(width: 16, height: 10)
                .rotationEffect(.degrees(180))
                .offset(x: -20)
        }
        .frame(width: 300)
        .offset(x: -100, y: -90)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Voice Button

    private var voiceButton: some View {
        ZStack {
            // Background pulse animation when pressed
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

            // Main button
            ZStack {
                // Button background
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPressed ? 1.2 : 1.0)

                // Icon with morphing animation
                if isProcessing {
                    // Processing spinner
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: buttonIcon)
                        .font(.system(size: isPressed ? 22 : 20, weight: .medium))
                        .foregroundColor(buttonIconColor)
                        .symbolEffect(.bounce, value: isPressed)
                }
            }
            .offset(x: dragOffset * 0.3)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChange(value)
                }
                .onEnded { value in
                    handleDragEnd(value)
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3), value: dragOffset)
        .onChange(of: audioService.isRecording) { _, isRecording in
            if isRecording {
                startWaveAnimation()
            } else {
                waveAnimation = false
            }
        }
    }

    private var buttonBackgroundColor: Color {
        if recordingCancelled {
            return .red.opacity(0.8)
        } else if isPressed || audioService.isRecording {
            return AzmyColors.accentBlue
        } else {
            return Color.clear
        }
    }

    private var buttonIcon: String {
        if recordingCancelled {
            return "xmark"
        } else if audioService.isRecording {
            return "mic.fill"
        } else {
            return "mic"
        }
    }

    private var buttonIconColor: Color {
        if isPressed || audioService.isRecording || recordingCancelled {
            return .white
        }
        return AzmyColors.textSecondary
    }

    // MARK: - Wave Animation

    private func startWaveAnimation() {
        withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
            waveAnimation = true
        }
    }

    // MARK: - Gesture Handling

    private func handleDragChange(_ value: DragGesture.Value) {
        // Dismiss onboarding on first interaction
        if showOnboarding {
            withAnimation {
                showOnboarding = false
                onboardingManager.markOnboardingSeen()
            }
        }

        let translation = value.translation

        // Start recording on press
        if !isPressed && !isProcessing {
            isPressed = true
            recordingCancelled = false
            startRecording()
        }

        // Track horizontal drag for cancel
        if translation.width < 0 {
            dragOffset = max(translation.width, cancelThreshold * 1.5)
            showCancelHint = dragOffset < cancelThreshold / 2

            // Trigger cancel when threshold reached
            if dragOffset < cancelThreshold && !recordingCancelled {
                recordingCancelled = true
                cancelRecording()
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        isPressed = false
        dragOffset = 0
        showCancelHint = false

        if recordingCancelled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                recordingCancelled = false
            }
            return
        }

        // Stop and process recording
        if audioService.isRecording {
            stopAndProcess()
        }
    }

    // MARK: - Recording Actions

    private func startRecording() {
        Task {
            do {
                try await audioService.startRecording()
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } catch {
                print("[Voice] Failed to start recording: \(error)")
                isPressed = false
            }
        }
    }

    private func cancelRecording() {
        audioService.cancelRecording()
        isPressed = false
        waveAnimation = false
    }

    private func stopAndProcess() {
        guard let audioData = audioService.stopRecording() else {
            return
        }

        isProcessing = true

        Task {
            // Process through voice pipeline (Voxtral + TextCleanup)
            if let result = await voicePipeline.processAudio(audioData) {
                await MainActor.run {
                    onTranscription(result)
                }
            }

            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - Triangle Shape for Tooltip

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Voice Recording Overlay with Beautiful Animations

struct VoiceRecordingOverlay: View {
    @ObservedObject var audioService: AudioRecordingService
    @ObservedObject var voicePipeline: VoicePipelineManager

    @State private var wavePhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 16) {
            // Cancel hint with animated arrow
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .offset(x: sin(wavePhase) * 3)
                Text("Slide to cancel")
                    .font(.system(size: 13))
            }
            .foregroundColor(AzmyColors.textTertiary)

            Spacer()

            // Recording info
            HStack(spacing: 10) {
                // Animated recording dot
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

                // Duration
                Text(formatDuration(audioService.recordingDuration))
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                // Audio waveform
                AudioWaveform(level: audioService.audioLevel)
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
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Waveform Visualization

struct AudioWaveform: View {
    let level: Float

    private let barCount = 8
    @State private var animatedLevel: Float = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    level: animatedLevel,
                    index: index,
                    totalBars: barCount
                )
            }
        }
        .onChange(of: level) { _, newLevel in
            withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) {
                animatedLevel = newLevel
            }
        }
    }
}

struct WaveformBar: View {
    let level: Float
    let index: Int
    let totalBars: Int

    @State private var randomOffset: CGFloat = 0

    private var barHeight: CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 24
        let position = Float(index) / Float(totalBars)

        // Create wave-like pattern
        let waveOffset = sin(Double(index) * 0.8 + Double(level) * 10) * 0.3
        let adjustedLevel = max(0, min(1, Double(level) + waveOffset))

        return baseHeight + CGFloat(adjustedLevel) * (maxHeight - baseHeight)
    }

    private var barColor: Color {
        let threshold = Float(index) / Float(totalBars)
        if level > threshold * 0.8 {
            if threshold > 0.7 {
                return .orange
            }
            return AzmyColors.accentBlue
        }
        return AzmyColors.textTertiary.opacity(0.5)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 3, height: barHeight)
            .animation(.spring(response: 0.15, dampingFraction: 0.5), value: level)
    }
}

// MARK: - Text Transformation Animation

struct AnimatedTextTransition: View {
    let text: String
    @State private var displayedText = ""
    @State private var animationComplete = false

    var body: some View {
        Text(displayedText)
            .onAppear {
                animateText()
            }
            .onChange(of: text) { _, newValue in
                animateText()
            }
    }

    private func animateText() {
        displayedText = ""
        animationComplete = false

        for (index, character) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.02) {
                displayedText += String(character)
                if index == text.count - 1 {
                    animationComplete = true
                }
            }
        }
    }
}

// MARK: - Processing Animation View

struct VoiceProcessingView: View {
    let processingStep: String

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            // Animated processing icon
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

            // Animated text
            Text(processingStep.isEmpty ? "Processing..." : processingStep)
                .font(.system(size: 13))
                .foregroundColor(AzmyColors.textSecondary)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(processingStep)

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
    VStack {
        Spacer()

        TelegramVoiceButton(
            audioService: AudioRecordingService.shared,
            voicePipeline: VoicePipelineManager.shared
        ) { _ in }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AzmyColors.backgroundPrimary)
    .preferredColorScheme(.dark)
}
