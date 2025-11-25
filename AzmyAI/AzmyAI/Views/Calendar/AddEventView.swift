//
//  AddEventView.swift
//  AzmyAI
//
//  Add/Edit event with color selection
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let onCreate: (String, Date, Date, Bool, EventColor) -> Void

    @State private var title: String = ""
    @State private var isAllDay: Bool = false
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedColor: EventColor = .orange

    init(
        selectedDate: Date,
        onCreate: @escaping (String, Date, Date, Bool, EventColor) -> Void
    ) {
        self.selectedDate = selectedDate
        self.onCreate = onCreate

        // Initialize with selected date at current time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let now = Date()
        components.hour = calendar.component(.hour, from: now)
        components.minute = 0

        let start = calendar.date(from: components) ?? selectedDate
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AzmyColors.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AzmySpacing.lg) {
                        // Title input
                        VStack(alignment: .leading, spacing: AzmySpacing.xs) {
                            TextField("Add title", text: $title)
                                .font(AzmyFonts.headline2())
                                .foregroundColor(AzmyColors.textPrimary)
                                .padding(AzmySpacing.md)
                                .background(AzmyColors.backgroundCard)
                                .cornerRadius(AzmyRadius.medium)
                        }

                        // All day toggle
                        Toggle(isOn: $isAllDay) {
                            Text("All day")
                                .font(AzmyFonts.body())
                                .foregroundColor(AzmyColors.textPrimary)
                        }
                        .tint(AzmyColors.accentBlue)
                        .padding(AzmySpacing.md)
                        .background(AzmyColors.backgroundCard)
                        .cornerRadius(AzmyRadius.medium)

                        // Date/Time pickers
                        VStack(spacing: AzmySpacing.sm) {
                            // Start
                            HStack {
                                Text("Start")
                                    .font(AzmyFonts.body())
                                    .foregroundColor(AzmyColors.textPrimary)

                                Spacer()

                                DatePicker(
                                    "",
                                    selection: $startDate,
                                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .tint(AzmyColors.accentBlue)
                                .colorScheme(.dark)
                            }
                            .padding(AzmySpacing.md)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(AzmyRadius.medium)

                            // End
                            HStack {
                                Text("End")
                                    .font(AzmyFonts.body())
                                    .foregroundColor(AzmyColors.textPrimary)

                                Spacer()

                                DatePicker(
                                    "",
                                    selection: $endDate,
                                    in: startDate...,
                                    displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .tint(AzmyColors.accentBlue)
                                .colorScheme(.dark)
                            }
                            .padding(AzmySpacing.md)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(AzmyRadius.medium)
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: AzmySpacing.sm) {
                            HStack {
                                Circle()
                                    .fill(selectedColor.color)
                                    .frame(width: 16, height: 16)

                                Text("Color: \(selectedColor.name)")
                                    .font(AzmyFonts.body())
                                    .foregroundColor(AzmyColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .foregroundColor(AzmyColors.textTertiary)
                            }
                            .padding(AzmySpacing.md)
                            .background(AzmyColors.backgroundCard)
                            .cornerRadius(AzmyRadius.medium)

                            // Color options
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: AzmySpacing.sm) {
                                ForEach(EventColor.allCases, id: \.self) { color in
                                    ColorOptionButton(
                                        color: color,
                                        isSelected: selectedColor == color
                                    ) {
                                        selectedColor = color
                                    }
                                }
                            }
                        }
                    }
                    .padding(AzmySpacing.lg)
                }
            }
            .navigationTitle("Add title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AzmyColors.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AzmyColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalEnd = isAllDay
                            ? Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? endDate
                            : endDate
                        onCreate(title, startDate, finalEnd, isAllDay, selectedColor)
                        dismiss()
                    }
                    .foregroundColor(title.isEmpty ? AzmyColors.textTertiary : AzmyColors.accentBlue)
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct ColorOptionButton: View {
    let color: EventColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AzmySpacing.sm) {
                Circle()
                    .fill(color.color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )

                Text(color.name)
                    .font(AzmyFonts.body())
                    .foregroundColor(AzmyColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AzmyColors.accentBlue)
                }
            }
            .padding(AzmySpacing.md)
            .background(
                isSelected
                    ? AzmyColors.accentBlue.opacity(0.1)
                    : AzmyColors.backgroundCard
            )
            .cornerRadius(AzmyRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AzmyRadius.medium)
                    .stroke(isSelected ? AzmyColors.accentBlue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Color
enum EventColor: String, CaseIterable {
    case orange = "Orange"
    case pink = "Pink"
    case green = "Green"
    case blue = "Blue"
    case yellow = "Yellow"
    case red = "Red"

    var name: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return Color.orange
        case .pink: return Color.pink
        case .green: return Color.green
        case .blue: return Color.blue
        case .yellow: return Color.yellow
        case .red: return Color.red
        }
    }
}

#Preview {
    AddEventView(selectedDate: Date()) { _, _, _, _, _ in }
        .preferredColorScheme(.dark)
}
