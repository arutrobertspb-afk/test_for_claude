//
//  HomeView.swift
//  AzmyAI
//
//  Main home screen with dashboard cards and expandable chat
//  TikTok-style vertical swipe between dashboard and chat
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @EnvironmentObject var userProfile: UserProfileViewModel
    @EnvironmentObject var plannerViewModel: PlannerViewModel

    @State private var currentPage: Int = 0  // 0 = dashboard, 1 = chat
    @State private var currentCardPage = 0
    @State private var dragOffset: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Page 0: Dashboard
                    dashboardPage(height: geometry.size.height)
                        .frame(height: geometry.size.height)

                    // Page 1: Full Chat
                    fullChatPage(height: geometry.size.height)
                        .frame(height: geometry.size.height)
                }
                .offset(y: -CGFloat(currentPage) * geometry.size.height + dragOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)
                .animation(.interactiveSpring(), value: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.height
                            // Limit drag based on current page
                            if currentPage == 0 {
                                // On dashboard, only allow drag up (negative)
                                if translation < 0 {
                                    dragOffset = translation * 0.5
                                }
                            } else {
                                // On chat, only allow drag down (positive)
                                if translation > 0 {
                                    dragOffset = translation * 0.5
                                }
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.height - value.translation.height
                            let threshold: CGFloat = 80

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                if currentPage == 0 {
                                    // Swipe up to go to chat
                                    if value.translation.height < -threshold || velocity < -100 {
                                        currentPage = 1
                                    }
                                } else {
                                    // Swipe down to go back to dashboard
                                    if value.translation.height > threshold || velocity > 100 {
                                        currentPage = 0
                                    }
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            Task {
                await plannerViewModel.fetchEventsForMonth(Date())
            }
        }
    }

    // MARK: - Dashboard Page (Page 0)
    private func dashboardPage(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            dashboardContent

            Spacer()

            // Swipe up hint
            VStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .medium))
                Text("Swipe up for chat")
                    .font(.system(size: 12))
            }
            .foregroundColor(AzmyColors.textTertiary)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Full Chat Page (Page 1)
    private func fullChatPage(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Swipe down hint
            VStack(spacing: 4) {
                Text("Swipe down for dashboard")
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(AzmyColors.textTertiary)
            .padding(.top, 50)
            .padding(.bottom, 8)

            // Chat header
            HStack {
                Circle()
                    .fill(AzmyColors.gradientBlue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Azmy AI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Your personal assistant")
                        .font(.system(size: 12))
                        .foregroundColor(AzmyColors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Chat messages
            expandedChatView

            // Input bar
            chatInputBar
        }
        .frame(maxHeight: .infinity)
        .background(AzmyColors.backgroundPrimary)
    }

    // MARK: - Dashboard Content
    private var dashboardContent: some View {
        VStack(spacing: 16) {
            // Top Bar
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // Date Header
            dateHeader
                .padding(.horizontal, 16)

            // Cards Section
            cardsSection

            // Page Indicator
            pageIndicator
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Location
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                Text("Limassol, Cyprus")
                    .font(.system(size: 14))
            }
            .foregroundColor(AzmyColors.textSecondary)

            Spacer()

            // Weather
            HStack(spacing: 4) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 12, height: 12)
                Text("+21°C")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            // Avatar
            Circle()
                .fill(AzmyColors.gradientBlue)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(userProfile.profile.name.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
                .padding(.leading, 12)
        }
    }

    // MARK: - Date Header
    private var dateHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(currentDateFormatted)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(currentDayName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AzmyColors.textSecondary)
                }
            }

            Spacer()

            // Status indicators
            HStack(spacing: 8) {
                StatusIndicator(icon: "moon.fill", value: "3", color: .blue)
                StatusIndicator(icon: "circle.fill", value: "", color: .green)
                StatusIndicator(icon: "mappin", value: "3", color: .white)
            }
        }
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: Date())
    }

    private var currentDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: Date())
    }

    // MARK: - Cards Section
    private var cardsSection: some View {
        TabView(selection: $currentCardPage) {
            // Page 1: Events + Tasks
            eventsAndTasksCard
                .tag(0)

            // Page 2: AI Tips
            aiTipsCard
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 280)
    }

    private var eventsAndTasksCard: some View {
        HStack(alignment: .top, spacing: 12) {
            // Tasks Circle
            tasksCircle
                .frame(width: 100)

            // Events List
            eventsListCard
        }
        .padding(.horizontal, 16)
    }

    private var tasksCircle: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(AzmyColors.separator, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(AzmyColors.accentBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("3/5")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("Tasks")
                        .font(.system(size: 12))
                        .foregroundColor(AzmyColors.textSecondary)
                }
            }

            // More events link
            if !todayEvents.isEmpty {
                Button(action: {}) {
                    Text("\(todayEvents.count) more events >")
                        .font(.system(size: 12))
                        .foregroundColor(AzmyColors.textSecondary)
                }
            }
        }
    }

    private var eventsListCard: some View {
        VStack(spacing: 8) {
            ForEach(todayEvents.prefix(3)) { event in
                EventRowCard(event: event)
            }

            if todayEvents.isEmpty {
                Text("No events today")
                    .font(.system(size: 14))
                    .foregroundColor(AzmyColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(AzmyColors.backgroundCard)
                    .cornerRadius(12)
            }
        }
    }

    private var todayEvents: [CalendarEvent] {
        plannerViewModel.events.filter {
            Calendar.current.isDateInToday($0.startDate)
        }
    }

    private var aiTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sleep card
            SleepTimeCard(hours: 6, minutes: 32)

            // AI Tip
            AITipCard(
                tip: "I'd love to suggest personalized rest or focus blocks — but I need access to your calendar.",
                buttonTitle: "Turn on the alarm"
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == currentCardPage ? AzmyColors.textPrimary : AzmyColors.textTertiary)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var expandedChatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatViewModel.messages.count) { _, _ in
                if let lastId = chatViewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var chatInputBar: some View {
        HStack(spacing: 12) {
            // Attachment button
            Button(action: {}) {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(AzmyColors.textSecondary)
            }

            // Text field
            HStack {
                TextField("Type your message", text: $chatViewModel.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .focused($isInputFocused)

                // Send button
                Button(action: {
                    chatViewModel.sendMessage(
                        profile: userProfile.profile,
                        calendarEvents: plannerViewModel.events
                    )
                }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AzmyColors.accentBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AzmyColors.backgroundPrimary)
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Event Row Card
struct EventRowCard: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // Color bar
            Rectangle()
                .fill(event.color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRange)
                    .font(.system(size: 12))
                    .foregroundColor(AzmyColors.textSecondary)

                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(event.color.opacity(0.15))
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) — \(formatter.string(from: event.endDate))"
    }
}

// MARK: - Sleep Time Card
struct SleepTimeCard: View {
    let hours: Int
    let minutes: Int

    var body: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.textSecondary)

            Text("Sleep time :")
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.textSecondary)

            Text("\(hours) hr \(minutes) min")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green)

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AzmyColors.separator)
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(.green)
                        .frame(width: geo.size.width * 0.7, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(width: 80, height: 4)

            Text("3")
                .font(.system(size: 12))
                .foregroundColor(AzmyColors.textSecondary)

            Image(systemName: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.green)
        }
        .padding(16)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }
}

// MARK: - AI Tip Card
struct AITipCard: View {
    let tip: String
    let buttonTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tip)
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.textSecondary)
                .lineLimit(3)

            Button(action: {}) {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AzmyColors.accentBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AzmyColors.accentBlue.opacity(0.15))
                .cornerRadius(20)
            }
        }
        .padding(16)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }
}

#Preview {
    HomeView()
        .environmentObject(ChatViewModel())
        .environmentObject(UserProfileViewModel())
        .environmentObject(PlannerViewModel())
        .preferredColorScheme(.dark)
}
