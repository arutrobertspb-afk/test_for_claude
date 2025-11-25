//
//  AzmyAIService.swift
//  AzmyAI
//
//  Main AI Service with Mistral integration, tool calling, and memory
//

import Foundation

// MARK: - System Prompt (500+ words with advanced prompting techniques)
struct AzmySystemPrompt {
    static let prompt = """
    # IDENTITY AND PURPOSE
    You are Azmy, a sophisticated personal AI assistant designed to optimize the user's daily life through intelligent calendar management, personalized advice, and proactive wellbeing support. Your core mission is to help users achieve work-life balance while maximizing their productivity and mental health.

    # PERSONALITY AND COMMUNICATION STYLE
    - Be warm, supportive, and genuinely caring—like a thoughtful friend who happens to be incredibly organized
    - Keep responses CONCISE and ACTIONABLE (2-4 sentences maximum unless detailed analysis requested)
    - Use a conversational tone, avoiding corporate jargon or overly formal language
    - Show empathy when users seem stressed or overwhelmed
    - Celebrate small wins and acknowledge user's efforts
    - Never be preachy or condescending about rest and wellness

    # CHAIN OF THOUGHT REASONING FRAMEWORK
    Before responding to any request, internally follow this reasoning chain (do NOT show this to user):

    STEP 1 - INTENT RECOGNITION:
    → What is the user's primary goal?
    → Is this a question, request, or emotional expression?
    → Does this require calendar action, advice, or acknowledgment?

    STEP 2 - CONTEXT INTEGRATION:
    → What do I know about this user's preferences and history?
    → What time of day is it? (affects energy recommendations)
    → What was our recent conversation about?

    STEP 3 - TOOL DECISION:
    → Does this require calendar access? → Use appropriate tool
    → Is this about schedule analysis? → Use analyze_schedule
    → Is user showing stress signs? → Consider suggest_rest

    STEP 4 - RESPONSE FORMULATION:
    → What is the most helpful, concise answer?
    → Should I proactively offer related advice?
    → Does user need emotional support or just information?

    # PROACTIVE INTELLIGENCE GUIDELINES

    ## Schedule Health Monitoring
    - When user has 5+ meetings in a day, gently suggest breaks
    - If detecting back-to-back meetings (less than 15 min gap), warn about this
    - Notice patterns: "I see you've had meetings during lunch 3 days this week..."
    - Suggest optimal meeting times based on user's energy patterns

    ## Wellbeing Integration
    - Connect calendar data with wellness: busy week → suggest self-care
    - Consider circadian rhythms: morning = high energy tasks, afternoon = creative work
    - Remember user preferences: if they mentioned being a "morning person", schedule accordingly
    - Track and mention positive patterns: "You've been consistent with your exercise schedule!"

    ## Intelligent Recommendations
    When user asks to schedule something:
    1. Check existing schedule for conflicts
    2. Suggest optimal time slots based on workload
    3. If day is heavy, proactively ask: "That day looks packed. Want me to find a calmer slot?"

    # RESPONSE FORMAT RULES

    ## For Calendar Actions:
    - Confirm action taken with specific details
    - Example: "Done! Meeting with Alex is set for Tuesday 2pm."

    ## For Schedule Queries:
    - Lead with the key information
    - Group by relevance, not just chronology
    - Example: "You have 3 meetings tomorrow. The busiest slot is 10am-12pm."

    ## For Advice/Analysis:
    - Start with the insight, then brief explanation
    - Offer one actionable suggestion
    - Example: "Your Wednesday looks overloaded. Consider moving the 4pm sync to Thursday?"

    ## For Emotional Support:
    - Acknowledge feelings first
    - Then offer practical help
    - Example: "That does sound exhausting. Want me to block some recovery time tomorrow?"

    # MEMORY AND CONTEXT USAGE

    You have access to conversation history and user context. Use this to:
    - Remember user's name and preferences
    - Track goals they've mentioned
    - Notice patterns in their requests
    - Personalize recommendations based on past interactions
    - Reference previous conversations naturally: "Last week you mentioned wanting more focus time..."

    # BOUNDARIES AND ETHICS

    - Never make medical diagnoses—suggest consulting professionals for health concerns
    - Respect user's autonomy—suggest, don't demand changes
    - Protect privacy—don't reference specific meeting contents unless user mentions them
    - Be honest about limitations—if you can't do something, say so clearly
    - Don't over-optimize—sometimes "good enough" is perfect

    # EXAMPLE INTERACTIONS

    User: "Schedule a meeting with Sarah tomorrow"
    Azmy: "When works best? I see you have a gap at 11am and another after 3pm."

    User: "What's my week looking like?"
    Azmy: "Moderate week ahead—12 meetings total. Tuesday and Thursday are your busiest days. Friday afternoon is clear if you need focus time."

    User: "I'm so tired of all these meetings"
    Azmy: "I hear you. You've had 8 meetings today alone. Want me to block tomorrow morning for heads-down work?"

    # CURRENT DATE/TIME AWARENESS
    Always consider the current date and time when:
    - Suggesting meeting times
    - Analyzing "today" or "tomorrow"
    - Providing time-sensitive advice
    - Understanding "this week" vs "next week"

    Remember: Your ultimate goal is to make the user's life easier, not to demonstrate how smart you are. Every response should leave them feeling more organized, less stressed, and genuinely supported.
    """
}

// MARK: - Mistral API Models
struct MistralChatRequest: Codable {
    let model: String
    let messages: [MistralMessage]
    let tools: [MistralTool]?
    let tool_choice: String?

    init(model: String, messages: [MistralMessage], tools: [MistralTool]? = nil) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.tool_choice = tools != nil ? "auto" : nil
    }
}

struct MistralMessage: Codable {
    let role: String
    let content: String
    let tool_calls: [ToolCall]?
    let tool_call_id: String?

    init(role: String, content: String, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.tool_calls = toolCalls
        self.tool_call_id = toolCallId
    }
}

struct MistralChatResponse: Codable {
    let choices: [MistralChoice]
}

struct MistralChoice: Codable {
    let message: MistralResponseMessage
    let finish_reason: String?
}

struct MistralResponseMessage: Codable {
    let role: String
    let content: String?
    let tool_calls: [ToolCall]?
}

// MARK: - Azmy AI Service
class AzmyAIService: ObservableObject {
    static let shared = AzmyAIService()

    private let apiKey: String
    private let apiURL = "https://api.mistral.ai/v1/chat/completions"
    private let model = "mistral-large-latest"

    private let memory = ConversationMemory.shared
    private let toolExecutor = CalendarToolExecutor()

    @Published var isProcessing = false

    init() {
        // Load API key from environment or config
        self.apiKey = ProcessInfo.processInfo.environment["MISTRAL_API_KEY"] ?? "KBMVVuAYB9A0mvM2Qq2VHVwENMMOB6lv"
    }

    // MARK: - Send Message
    func sendMessage(_ userMessage: String) async -> String {
        await MainActor.run { isProcessing = true }
        defer { Task { @MainActor in isProcessing = false } }

        // Add user message to memory
        memory.addMessage(role: "user", content: userMessage, importance: 5)

        // Build messages array with context
        var messages = buildMessagesWithContext(userMessage: userMessage)

        // First API call with tools
        guard let response = await callMistralAPI(messages: messages, includeTools: true) else {
            return "I'm having trouble connecting right now. Please try again."
        }

        // Check for tool calls
        if let toolCalls = response.tool_calls, !toolCalls.isEmpty {
            // Execute tools and get results
            var toolResults: [MistralMessage] = []

            for toolCall in toolCalls {
                let result = await executeToolCall(toolCall)
                toolResults.append(MistralMessage(
                    role: "tool",
                    content: result,
                    toolCallId: toolCall.id
                ))
            }

            // Add assistant message with tool calls
            messages.append(MistralMessage(
                role: "assistant",
                content: response.content ?? "",
                toolCalls: toolCalls
            ))

            // Add tool results
            messages.append(contentsOf: toolResults)

            // Second API call for final response
            if let finalResponse = await callMistralAPI(messages: messages, includeTools: false) {
                let reply = finalResponse.content ?? "Done!"
                memory.addMessage(role: "assistant", content: reply, importance: 5)
                return reply
            }
        }

        // No tool calls, return direct response
        let reply = response.content ?? "I'm not sure how to help with that."
        memory.addMessage(role: "assistant", content: reply, importance: 5)
        return reply
    }

    // MARK: - Build Messages with Context
    private func buildMessagesWithContext(userMessage: String) -> [MistralMessage] {
        var messages: [MistralMessage] = []

        // System message with context
        let contextInfo = memory.getContextForLLM()
        let systemContent = """
        \(AzmySystemPrompt.prompt)

        # CURRENT CONTEXT
        Current date and time: \(formatCurrentDateTime())

        # USER CONTEXT AND RECENT HISTORY
        \(contextInfo)
        """

        messages.append(MistralMessage(role: "system", content: systemContent))

        // Add recent conversation history
        for entry in memory.shortTermMemory.suffix(6) {
            messages.append(MistralMessage(role: entry.role, content: entry.content))
        }

        // Add current user message
        messages.append(MistralMessage(role: "user", content: userMessage))

        return messages
    }

    // MARK: - Call Mistral API
    private func callMistralAPI(messages: [MistralMessage], includeTools: Bool) async -> MistralResponseMessage? {
        guard let url = URL(string: apiURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = MistralChatRequest(
            model: model,
            messages: messages,
            tools: includeTools ? CalendarTools.allTools : nil
        )

        do {
            let jsonData = try JSONEncoder().encode(body)
            request.httpBody = jsonData

            // Debug: print request
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Mistral Request: \(jsonString.prefix(500))...")
            }

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            // Debug: print response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 Mistral Response: \(jsonString.prefix(1000))...")
            }

            if let httpResp = httpResponse as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResp.statusCode)")
                if httpResp.statusCode != 200 {
                    print("❌ API Error: \(String(data: data, encoding: .utf8) ?? "unknown")")
                    return nil
                }
            }

            let response = try JSONDecoder().decode(MistralChatResponse.self, from: data)

            // Debug: check for tool calls
            if let toolCalls = response.choices.first?.message.tool_calls {
                print("🔧 Tool calls found: \(toolCalls.count)")
                for tc in toolCalls {
                    print("   - \(tc.function.name): \(tc.function.arguments)")
                }
            } else {
                print("ℹ️ No tool calls in response")
            }

            return response.choices.first?.message
        } catch {
            print("❌ Mistral API error: \(error)")
            return nil
        }
    }

    // MARK: - Execute Tool Call
    private func executeToolCall(_ toolCall: ToolCall) async -> String {
        print("🔧 Executing tool: \(toolCall.function.name)")
        print("   Arguments: \(toolCall.function.arguments)")

        guard let argsData = toolCall.function.arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            print("❌ Failed to parse tool arguments")
            return "Failed to parse tool arguments"
        }

        let result = await toolExecutor.execute(toolName: toolCall.function.name, arguments: args)
        print("✅ Tool result: \(result)")
        return result
    }

    // MARK: - Helper
    private func formatCurrentDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - Quick Actions
    func analyzeToday() async -> String {
        return await sendMessage("Analyze my schedule for today and let me know if I need any breaks")
    }

    func suggestNextAction() async -> String {
        return await sendMessage("Based on my schedule and current time, what should I focus on next?")
    }
}
