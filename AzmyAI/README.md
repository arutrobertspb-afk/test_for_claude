# Azmy.ai - Personal AI Assistant

<p align="center">
  <img src="docs/logo.png" alt="Azmy Logo" width="120"/>
</p>

Azmy.ai is a personal AI assistant that combines your calendar, health data, and behavioral quizzes to provide accurate, personalized recommendations for daily life.

## Features

- **AI Chat** - Context-aware conversations that understand your schedule, sleep, activity, and preferences
- **Smart Planner** - AI-powered daily planning with automatic event creation from natural language
- **Behavioral Quizzes** - Build your psychological and behavioral profile for better recommendations
- **Health Insights** - Correlate sleep, activity, and energy patterns
- **Calendar Integration** - Sync with Apple Calendar for seamless scheduling

## Screenshots

| Chat | Planner | Insights | Profile |
|------|---------|----------|---------|
| ![Chat](docs/chat.png) | ![Planner](docs/planner.png) | ![Insights](docs/insights.png) | ![Profile](docs/profile.png) |

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Using XcodeGen (Recommended)

1. Install XcodeGen if you haven't already:
   ```bash
   brew install xcodegen
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/azmy-ai.git
   cd azmy-ai/AzmyAI
   ```

3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

4. Open the generated project:
   ```bash
   open AzmyAI.xcodeproj
   ```

### Manual Setup

1. Open Xcode and create a new iOS App project
2. Copy all files from `AzmyAI/` folder into your project
3. Add HealthKit capability in Signing & Capabilities
4. Add Calendar (EventKit) capability

## Configuration

### API Key Setup

The app uses OpenAI's GPT-4 for AI chat functionality. To use your own API key:

1. Open the app
2. Go to Profile > API Settings
3. Enter your OpenAI API key

**Note**: Without an API key, the app runs in demo mode with simulated responses.

### Permissions

The app requires the following permissions:

- **Calendar**: To read and create events
- **HealthKit**: To access sleep, steps, heart rate, and HRV data
- **Notifications**: For reminders and check-ins (optional)

## Architecture

```
AzmyAI/
├── App/
│   ├── AzmyAIApp.swift      # App entry point
│   └── ContentView.swift     # Main container view
├── Models/
│   ├── UserProfile.swift     # User profile & quiz models
│   ├── ChatModels.swift      # Chat & message models
│   └── PlannerModels.swift   # Calendar & task models
├── ViewModels/
│   ├── UserProfileViewModel.swift
│   ├── ChatViewModel.swift
│   └── PlannerViewModel.swift
├── Views/
│   ├── Onboarding/           # Onboarding flow
│   ├── Chat/                 # AI chat interface
│   ├── Planner/              # Calendar & tasks
│   └── Profile/              # Settings & insights
├── Services/
│   ├── AIService.swift       # OpenAI integration
│   ├── HealthKitService.swift
│   └── CalendarService.swift
└── Utilities/
    └── Theme.swift           # Design system
```

## Key Technologies

- **SwiftUI** - Declarative UI framework
- **Combine** - Reactive programming
- **HealthKit** - Health data access
- **EventKit** - Calendar integration
- **Charts** - Data visualization (iOS 16+)
- **OpenAI API** - AI chat functionality

## Target Audience (ICP)

Based on research, the primary target audience is:

**Overwhelmed Young Professionals (25-35)**
- Early career professionals juggling multiple life areas
- Pain points: decision fatigue, no "system" for life management
- Value proposition: AI-guided daily planning, reducing mental load

## Pricing Model

Recommended pricing tiers:
- **Free**: Basic features, limited AI interactions
- **Premium ($19-29/month)**: Full AI chat, advanced insights
- **Pro ($39-49/month)**: API access, custom integrations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenAI for GPT-4 API
- Apple for HealthKit and EventKit frameworks
- The SwiftUI community for inspiration

---

Made with care by the Azmy.ai team
