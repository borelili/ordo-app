// PillButton.swift
// TickTick — Design System
// 胶囊选择按钮（未选中：半透明；选中：AccentPurple 填充）

import SwiftUI

// MARK: - PillButton

struct PillButton: View {
    @EnvironmentObject private var theme: ThemeManager

    let title: String
    var icon: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.spacingXS + 2) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                }
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? theme.current.accentTextColor : theme.current.textSecondary)
            .padding(.horizontal, DS.paddingCard)
            .padding(.vertical, DS.spacingSM + 2)
            .background(pillBackground)
            .clipShape(Capsule())
            .cardShadow(isSelected ? DS.Shadow.pill : DS.Shadow.subtle)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // VoiceOver
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var pillBackground: some View {
        if isSelected {
            theme.current.primaryAccent
        } else {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().strokeBorder(theme.current.cardBorderColor, lineWidth: 1)
            }
        }
    }
}

// MARK: - Previews

#Preview("PillButton States") {
    ZStack {
        AppBackgroundGradient()
        HStack(spacing: 10) {
            PillButton(title: "全部", icon: "tray.fill", isSelected: true, action: {})
            PillButton(title: "今天", icon: "clock", isSelected: false, action: {})
            PillButton(title: "已完成", icon: "checkmark", isSelected: false, action: {})
        }
        .padding()
    }
}

#Preview("PillButton Dark") {
    ZStack {
        AppBackgroundGradient()
        HStack(spacing: 10) {
            PillButton(title: "日历", icon: "calendar", isSelected: false, action: {})
            PillButton(title: "清单", icon: "list.bullet", isSelected: true, action: {})
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("PillButton Large Text") {
    ZStack {
        AppBackgroundGradient()
        PillButton(title: "动态字体测试", isSelected: true, action: {})
            .padding()
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
