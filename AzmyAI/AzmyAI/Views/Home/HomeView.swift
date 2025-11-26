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
    @State private var selectedEvent: CalendarEvent?
    @State private var showEventDetail = false
    @State private var showTasksList = false
    @State private var showAllEvents = false
    @State private var dashboardInputText = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isDashboardInputFocused: Bool

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
        .sheet(isPresented: $showEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
            }
        }
        .sheet(isPresented: $showTasksList) {
            TasksListView(tasks: plannerViewModel.tasks)
        }
        .sheet(isPresented: $showAllEvents) {
            AllEventsView(events: todayEvents) { event in
                showAllEvents = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedEvent = event
                    showEventDetail = true
                }
            }
        }
    }

    // MARK: - Swipe to chat from dashboard
    private func swipeToChat() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentPage = 1
        }
    }

    // MARK: - Send message from dashboard and swipe to chat
    private func sendFromDashboard() {
        guard !dashboardInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatViewModel.inputText = dashboardInputText
        dashboardInputText = ""
        isDashboardInputFocused = false

        // First swipe to chat
        swipeToChat()

        // Then send message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            chatViewModel.sendMessage(
                profile: userProfile.profile,
                calendarEvents: plannerViewModel.events
            )
        }
    }

    // MARK: - Dashboard Page (Page 0)
    private func dashboardPage(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            dashboardContent

            Spacer()

            // Chat preview section with AI message and input
            chatPreviewSection

            // Animated swipe hint
            SwipeUpHint()
                .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Full Chat Page (Page 1)
    private func fullChatPage(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Swipe down hint with animation
            SwipeDownHint()
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
            Button(action: {
                showTasksList = true
            }) {
                ZStack {
                    Circle()
                        .stroke(AzmyColors.separator, lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: tasksProgress)
                        .stroke(AzmyColors.accentBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(completedTasksCount)/\(totalTasksCount)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Tasks")
                            .font(.system(size: 12))
                            .foregroundColor(AzmyColors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // More events link
            if todayEvents.count > 3 {
                Button(action: {
                    showAllEvents = true
                }) {
                    Text("\(todayEvents.count - 3) more events >")
                        .font(.system(size: 12))
                        .foregroundColor(AzmyColors.accentBlue)
                }
            }
        }
    }

    private var completedTasksCount: Int {
        plannerViewModel.tasks.filter { $0.isCompleted }.count
    }

    private var totalTasksCount: Int {
        max(plannerViewModel.tasks.count, 5) // Show at least 5 for demo
    }

    private var tasksProgress: CGFloat {
        guard totalTasksCount > 0 else { return 0 }
        return CGFloat(completedTasksCount) / CGFloat(totalTasksCount)
    }

    private var eventsListCard: some View {
        VStack(spacing: 8) {
            ForEach(todayEvents.prefix(3)) { event in
                EventRowCard(event: event) {
                    selectedEvent = event
                    showEventDetail = true
                }
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

    // MARK: - Chat Preview Section
    private var chatPreviewSection: some View {
        VStack(spacing: 12) {
            chatPreviewHeader
            dashboardChatInput
        }
        .padding(.vertical, 12)
    }

    private var chatPreviewHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            chatPreviewAvatar
            chatPreviewContent
            Spacer()
        }
        .padding(.horizontal, 16)
        .onTapGesture {
            swipeToChat()
        }
    }

    private var chatPreviewAvatar: some View {
        Circle()
            .fill(AzmyColors.gradientBlue)
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(AzmyColors.backgroundPrimary, lineWidth: 2)
            )
    }

    private var chatPreviewContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            chatPreviewTimestamp
            chatPreviewGreeting
            chatPreviewMessage
        }
    }

    private var chatPreviewTimestamp: some View {
        HStack {
            Text(lastMessageTime)
                .font(.system(size: 12))
                .foregroundColor(AzmyColors.textTertiary)

            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AzmyColors.textTertiary)
        }
    }

    private var chatPreviewGreeting: some View {
        Text(greetingText)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
    }

    private var chatPreviewMessage: some View {
        Text(lastAIMessagePreview)
            .font(.system(size: 14))
            .foregroundColor(AzmyColors.textSecondary)
            .lineLimit(2)
    }

    private var greetingText: String {
        let firstName = userProfile.profile.name.components(separatedBy: " ").first ?? "there"
        return "Good morning, \(firstName)."
    }

    private var lastMessageTime: String {
        if let lastMessage = chatViewModel.messages.last(where: { $0.role == .assistant }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, HH:mm a"
            return formatter.string(from: lastMessage.timestamp)
        }
        return "yesterday, 08:32 AM"
    }

    private var lastAIMessagePreview: String {
        if let lastMessage = chatViewModel.messages.last(where: { $0.role == .assistant }) {
            let contentPrefix = String(lastMessage.content.prefix(100))
            let suffix = lastMessage.content.count > 100 ? "..." : ""
            return contentPrefix + suffix
        }
        return "I'd like to remind you that tomorrow, according to the forecast, there will be no waves. And you haven't been wakesurfing in a while - maybe it's ti..."
    }

    private var dashboardChatInput: some View {
        HStack(spacing: 12) {
            // Attachment button
            Button(action: {}) {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(AzmyColors.textSecondary)
            }

            // Text field
            HStack {
                TextField("Type your message", text: $dashboardInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .focused($isDashboardInputFocused)
                    .onSubmit {
                        sendFromDashboard()
                    }

                // Send button
                Button(action: sendFromDashboard) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(dashboardInputText.isEmpty ? AzmyColors.textTertiary : AzmyColors.accentBlue)
                }
                .disabled(dashboardInputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AzmyColors.backgroundCard)
            .cornerRadius(24)
        }
        .padding(.horizontal, 16)
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
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: {
            onTap?()
        }) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AzmyColors.textTertiary)
            }
            .padding(12)
            .background(event.color.opacity(0.15))
            .background(AzmyColors.backgroundCard)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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

// MARK: - Swipe Up Hint with Animation
struct SwipeUpHint: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .medium))
                .offset(y: isAnimating ? -4 : 0)
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .medium))
                .offset(y: isAnimating ? -4 : 0)
                .opacity(isAnimating ? 0.5 : 0.3)
            Text("Swipe up for chat")
                .font(.system(size: 12))
        }
        .foregroundColor(AzmyColors.textTertiary)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Swipe Down Hint with Animation
struct SwipeDownHint: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            Text("Swipe down for dashboard")
                .font(.system(size: 12))
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .offset(y: isAnimating ? 4 : 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .offset(y: isAnimating ? 4 : 0)
                .opacity(isAnimating ? 0.5 : 0.3)
        }
        .foregroundColor(AzmyColors.textTertiary)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Event Detail View
struct EventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        eventHeader
                        timeSection
                        locationSection
                        notesSection
                        aiGeneratedBadge
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    menuButton
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private var eventHeader: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(event.color)
                .frame(width: 6)
                .cornerRadius(3)

            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                categoryBadge
            }
        }
        .frame(height: 80)
    }

    private var categoryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: event.category.icon)
                .font(.system(size: 12))
            Text(event.category.rawValue)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(event.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(event.color.opacity(0.2))
        .cornerRadius(12)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Time", icon: "clock")
            timeContent
        }
    }

    private var timeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            timeRow(label: "Start:", value: formattedDateTime(event.startDate))
            timeRow(label: "End:", value: formattedDateTime(event.endDate))
            timeRow(label: "Duration:", value: formattedDuration)
        }
        .padding(16)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }

    private func timeRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AzmyColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if let location = event.location, !location.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Location", icon: "mappin.circle")
                locationContent(location)
            }
        }
    }

    private func locationContent(_ location: String) -> some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 16))
                .foregroundColor(AzmyColors.accentBlue)

            Text(location)
                .font(.system(size: 14))
                .foregroundColor(.white)

            Spacer()

            Button(action: {}) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(AzmyColors.accentBlue)
            }
        }
        .padding(16)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = event.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Notes", icon: "note.text")

                Text(notes)
                    .font(.system(size: 14))
                    .foregroundColor(AzmyColors.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AzmyColors.backgroundCard)
                    .cornerRadius(12)
            }
        }
    }

    @ViewBuilder
    private var aiGeneratedBadge: some View {
        if event.isAIGenerated {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                Text("Generated by Azmy AI")
                    .font(.system(size: 12))
            }
            .foregroundColor(AzmyColors.accentBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AzmyColors.accentBlue.opacity(0.15))
            .cornerRadius(20)
        }
    }

    private var closeButton: some View {
        Button("Close") {
            dismiss()
        }
        .foregroundColor(AzmyColors.accentBlue)
    }

    private var menuButton: some View {
        Menu {
            Button(action: {}) {
                Label("Edit", systemImage: "pencil")
            }
            Button(action: {}) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive, action: {}) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(AzmyColors.textSecondary)
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm"
        return formatter.string(from: date)
    }

    private var formattedDuration: String {
        let duration = event.duration
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)min"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AzmyColors.accentBlue)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Tasks List View
struct TasksListView: View {
    let tasks: [PlannerTask]
    @Environment(\.dismiss) var dismiss

    // Sample tasks for demo
    private var displayTasks: [PlannerTask] {
        if tasks.isEmpty {
            return [
                PlannerTask(title: "Morning workout", isCompleted: true, category: .health),
                PlannerTask(title: "Review project proposal", isCompleted: true, category: .work),
                PlannerTask(title: "Call mom", isCompleted: true, category: .personal),
                PlannerTask(title: "Team meeting at 3 PM", isCompleted: false, category: .work),
                PlannerTask(title: "Prepare dinner", isCompleted: false, category: .personal)
            ]
        }
        return tasks
    }

    private var completedCount: Int {
        displayTasks.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        displayTasks.count
    }

    private var progressValue: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(completedCount) / CGFloat(totalCount)
    }

    private var progressPercent: Int {
        Int(progressValue * 100)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        progressHeader
                        tasksList
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AzmyColors.accentBlue)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AzmyColors.accentBlue)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text("\(completedCount) of \(totalCount) completed")
                    .font(.system(size: 14))
                    .foregroundColor(AzmyColors.textSecondary)
            }

            Spacer()

            progressCircle
        }
        .padding(16)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }

    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(AzmyColors.separator, lineWidth: 6)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: progressValue)
                .stroke(AzmyColors.accentBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))

            Text("\(progressPercent)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var tasksList: some View {
        ForEach(displayTasks) { task in
            TaskRowView(task: task)
        }
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    let task: PlannerTask
    @State private var isCompleted: Bool

    init(task: PlannerTask) {
        self.task = task
        _isCompleted = State(initialValue: task.isCompleted)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isCompleted.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? AzmyColors.accentBlue : AzmyColors.separator, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isCompleted {
                        Circle()
                            .fill(AzmyColors.accentBlue)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCompleted ? AzmyColors.textTertiary : .white)
                    .strikethrough(isCompleted)

                HStack(spacing: 8) {
                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: task.category.icon)
                            .font(.system(size: 10))
                        Text(task.category.rawValue)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(AzmyColors.textTertiary)

                    // Priority
                    if task.priority != .medium {
                        HStack(spacing: 4) {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 10))
                            Text(task.priority.title)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(priorityColor)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AzmyColors.textTertiary)
        }
        .padding(12)
        .background(AzmyColors.backgroundCard)
        .cornerRadius(12)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .low: return .gray
        case .medium: return AzmyColors.accentBlue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - All Events View
struct AllEventsView: View {
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(events) { event in
                            EventRowCard(event: event) {
                                onEventTap(event)
                            }
                        }

                        if events.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(AzmyColors.textTertiary)

                                Text("No events today")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AzmyColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Today's Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AzmyColors.accentBlue)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AzmyColors.accentBlue)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    HomeView()
        .environmentObject(ChatViewModel())
        .environmentObject(UserProfileViewModel())
        .environmentObject(PlannerViewModel())
        .preferredColorScheme(.dark)
}
