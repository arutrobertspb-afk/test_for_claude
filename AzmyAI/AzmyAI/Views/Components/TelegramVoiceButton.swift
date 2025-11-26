//
//  TelegramVoiceButton.swift
//  AzmyAI
//
//  Telegram-style voice recording button
//  - Hold to record
//  - Release to send
//  - Slide left to cancel
//

import SwiftUI
import AVFoundation

// MARK: - Telegram Voice Button

struct TelegramVoiceButton: View {
    @ObservedObject var audioService: AudioRecordingService
    @ObservedObject var voicePipeline: VoicePipelineManager

    let onTranscription: (String) -> Void

    @State private var isPressed = false
    @State private var dragOffset: CGFloat = 0
    @State private var isProcessing = false
    @State private var showCancelHint = false
    @State private var recordingCancelled = false

    private let cancelThreshold: CGFloat = -100

    var body: some View {
        ZStack {
            // Recording overlay (appears when recording)
            if audioService.isRecording || isProcessing {
                recordingOverlay
            }

            // Main button
            voiceButton
        }
    }

    // MARK: - Voice Button

    private var voiceButton: some View {
        Image(systemName: buttonIcon)
            .font(.system(size: isPressed ? 32 : 24))
            .foregroundColor(buttonColor)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(isPressed ? AzmyColors.accentBlue.opacity(0.2) : Color.clear)
                    .scaleEffect(isPressed ? 1.5 : 1.0)
            )
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChange(value)
                    }
                    .onEnded { value in
                        handleDragEnd(value)
                    }
            )
            .animation(.spring(response: 0.3), value: isPressed)
            .animation(.spring(response: 0.3), value: dragOffset)
    }

    private var buttonIcon: String {
        if isProcessing {
            return "waveform.circle"
        } else if audioService.isRecording {
            return "mic.fill"
        } else {
            return "mic"
        }
    }

    private var buttonColor: Color {
        if recordingCancelled {
            return .red
        } else if isProcessing {
            return AzmyColors.accentBlue
        } else if audioService.isRecording {
            return .red
        } else {
            return AzmyColors.textSecondary
        }
    }

    // MARK: - Recording Overlay

    private var recordingOverlay: some View {
        HStack(spacing: 12) {
            // Cancel hint (slide left)
            if audioService.isRecording && !isProcessing {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                    Text("Slide to cancel")
                        .font(.system(size: 12))
                }
                .foregroundColor(showCancelHint ? .red : AzmyColors.textTertiary)
                .opacity(max(0, 1 + (dragOffset / 50)))

                Spacer()

                // Recording indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(recordingPulse ? 1 : 0.5)

                    Text(formatDuration(audioService.recordingDuration))
                        .font(.system(size: 14, weight: .medium).monospacedDigit())
                        .foregroundColor(.white)

                    // Audio level indicator
                    audioLevelBars
                }
            }

            // Processing indicator
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)

                    Text(voicePipeline.processingStep.isEmpty ? "Processing..." : voicePipeline.processingStep)
                        .font(.system(size: 12))
                        .foregroundColor(AzmyColors.textSecondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(AzmyRadius.medium)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    @State private var recordingPulse = false

    private var audioLevelBars: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barActive(index) ? AzmyColors.accentBlue : AzmyColors.textTertiary)
                    .frame(width: 3, height: barHeight(index))
            }
        }
        .frame(height: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                recordingPulse = true
            }
        }
    }

    private func barActive(_ index: Int) -> Bool {
        let threshold = Float(index) / 5.0
        return audioService.audioLevel > threshold
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 16
        let threshold = Float(index) / 5.0

        if audioService.audioLevel > threshold {
            return baseHeight + CGFloat(audioService.audioLevel - threshold) * (maxHeight - baseHeight)
        }
        return baseHeight
    }

    // MARK: - Gesture Handling

    private func handleDragChange(_ value: DragGesture.Value) {
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
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        isPressed = false
        dragOffset = 0
        showCancelHint = false

        if recordingCancelled {
            recordingCancelled = false
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
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } catch {
                print("[Voice] Failed to start recording: \(error)")
            }
        }
    }

    private func cancelRecording() {
        audioService.cancelRecording()
        isPressed = false
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

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Updated Chat Input Bar with Telegram-style Voice

struct TelegramChatInputBar: View {
    @Binding var text: String
    let isProcessing: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onVoiceTranscription: (String) -> Void

    @StateObject private var audioService = AudioRecordingService.shared
    @StateObject private var voicePipeline = VoicePipelineManager.shared

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text field
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
                        .stroke(audioService.isRecording ? AzmyColors.accentBlue : AzmyColors.separator, lineWidth: 1)
                )

            // Send button OR Voice button
            if hasText {
                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AzmyColors.accentBlue)
                }
            } else {
                // Telegram-style voice button
                TelegramVoiceButton(
                    audioService: audioService,
                    voicePipeline: voicePipeline
                ) { transcribedText in
                    onVoiceTranscription(transcribedText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AzmyColors.backgroundPrimary)
        .animation(.spring(response: 0.3), value: hasText)
    }
}

#Preview {
    VStack {
        Spacer()

        TelegramChatInputBar(
            text: .constant(""),
            isProcessing: false,
            isFocused: FocusState<Bool>().projectedValue,
            onSend: {},
            onVoiceTranscription: { _ in }
        )
    }
    .background(AzmyColors.backgroundPrimary)
    .preferredColorScheme(.dark)
}
