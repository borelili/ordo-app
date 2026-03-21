// WeekStrip.swift
// TickTick — Design System
// 横向周历条，支持选中某天

import SwiftUI

// MARK: - WeekStripDay Model（轻量，避免 body 重计算）

private struct WeekDay: Identifiable {
    let id: Int          // weekday index 0-6
    let date: Date
    let weekdayShort: String
    let dayNumber: String
    let a11yLabel: String
}

// MARK: - WeekStrip

struct WeekStrip: View {
    @Binding var selectedDate: Date
    var onSelect: ((Date) -> Void)? = nil

    // 缓存：只在 selectedDate 所在周变化时重算
    @State private var days: [WeekDay] = []
    @State private var weekStart: Date = .distantPast

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.spacingMD) {
                    ForEach(days) { day in
                        DayCell(
                            day: day,
                            isToday: Calendar.current.isDateInToday(day.date),
                            isSelected: Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
                        )
                        .id(day.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedDate = day.date
                            }
                            onSelect?(day.date)
                        }
                        .accessibilityLabel(day.a11yLabel)
                        .accessibilityAddTraits(
                            Calendar.current.isDate(day.date, inSameDayAs: selectedDate) ? [.isSelected] : []
                        )
                    }
                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.vertical, DS.spacingSM)
            }
            .onChange(of: selectedDate) { newDate in
                let newWeekStart = weekStartDate(for: newDate)
                if days.isEmpty || !Calendar.current.isDate(newWeekStart, inSameDayAs: weekStart) {
                    weekStart = newWeekStart
                    days = buildDays(from: weekStart)
                }
                // 滚动使选中日可见
                if let selected = days.first(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: newDate)
                }) {
                    withAnimation {
                        proxy.scrollTo(selected.id, anchor: .center)
                    }
                }
            }
            .onAppear {
                weekStart = weekStartDate(for: selectedDate)
                days = buildDays(from: weekStart)
            }
        }
    }

    // MARK: - Helpers

    private func weekStartDate(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 周一起始
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    private func buildDays(from start: Date) -> [WeekDay] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let a11yFormatter = DateFormatter()
        a11yFormatter.locale = Locale(identifier: "zh_CN")
        a11yFormatter.dateFormat = "M月d日"

        return (0..<7).compactMap { offset -> WeekDay? in
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            formatter.dateFormat = "EEE"
            let weekdayShort = formatter.string(from: date)
            formatter.dateFormat = "d"
            let dayNumber = formatter.string(from: date)
            formatter.dateFormat = "EEEE"
            let fullWeekday = formatter.string(from: date)
            let a11y = "\(fullWeekday)，\(a11yFormatter.string(from: date))"
            return WeekDay(id: offset, date: date, weekdayShort: weekdayShort,
                           dayNumber: dayNumber, a11yLabel: a11y)
        }
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let day: WeekDay
    let isToday: Bool
    let isSelected: Bool
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: DS.spacingXS) {
            Text(day.weekdayShort)
                .font(.caption2.weight(.medium))
                .foregroundStyle(labelColor)

            ZStack {
                if isSelected {
                    Capsule()
                        .fill(theme.current.primaryAccent)
                        .frame(width: 36, height: 44)
                } else if isToday {
                    Capsule()
                        .fill(theme.current.primaryAccent.opacity(0.25))
                        .frame(width: 36, height: 44)
                }

                Text(day.dayNumber)
                    .font(.callout.weight(isSelected ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isSelected ? theme.current.accentTextColor : labelColor)
            }
        }
    }

    private var labelColor: Color {
        if isSelected  { return theme.current.accentTextColor }
        if isToday     { return theme.current.primaryAccent }
        return theme.current.textSecondary
    }
}

// MARK: - Previews

#Preview("WeekStrip") {
    ZStack {
        AppBackgroundGradient()
        WeekStrip(selectedDate: .constant(Date()))
    }
}

#Preview("WeekStrip Dark") {
    ZStack {
        AppBackgroundGradient()
        WeekStrip(selectedDate: .constant(Date()))
    }
    .preferredColorScheme(.dark)
}

#Preview("WeekStrip Large Text") {
    ZStack {
        AppBackgroundGradient()
        WeekStrip(selectedDate: .constant(Date()))
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
