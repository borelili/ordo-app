// BottomPillNav.swift
// TickTick — Design System
// 底部胶囊导航栏（纯导航 Tab，不含 FAB "+"）

import SwiftUI

// MARK: - Tab Definition

enum PillNavTab: Int, CaseIterable {
    case dashboard = 0
    case myLists   = 1
    case lists     = 2
    case calendar  = 3

    var icon: String {
        switch self {
        case .dashboard: return "sun.max.fill"
        case .myLists:   return "square.grid.2x2.fill"
        case .lists:     return "checklist"
        case .calendar:  return "calendar"
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "今天"
        case .myLists:   return "我的列表"
        case .lists:     return "清单"
        case .calendar:  return "日历"
        }
    }
}

// MARK: - BottomPillNav

struct BottomPillNav: View {
    @Binding var selectedTab: PillNavTab
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PillNavTab.allCases, id: \.rawValue) { tab in
                Spacer()
                TabItem(tab: tab, isSelected: selectedTab == tab) {
                    selectedTab = tab
                }
                Spacer()
            }
        }
        .padding(.vertical, DS.spacingMD)
        .padding(.horizontal, DS.paddingScreen)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(theme.current.tabBarBackground)
                Capsule()
                    .strokeBorder(theme.current.cardBorderColor, lineWidth: 1)
            }
        )
        .cardShadow(DS.Shadow.card)
        .padding(.horizontal, DS.paddingScreen)
    }
}

// MARK: - TabItem

private struct TabItem: View {
    let tab: PillNavTab
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.spacingXS) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? theme.current.primaryAccent : theme.current.textSecondary)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(tab.label)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.current.primaryAccent : theme.current.textSecondary)
            }
            .frame(minWidth: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Previews

#Preview("BottomPillNav") {
    ZStack {
        AppBackgroundGradient()
        VStack {
            Spacer()
            BottomPillNav(selectedTab: .constant(.dashboard))
                .padding(.bottom, 8)
        }
    }
}

#Preview("BottomPillNav — Lists Selected Dark") {
    ZStack {
        AppBackgroundGradient()
        VStack {
            Spacer()
            BottomPillNav(selectedTab: .constant(.lists))
                .padding(.bottom, 8)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("BottomPillNav Large Text") {
    ZStack {
        AppBackgroundGradient()
        VStack {
            Spacer()
            BottomPillNav(selectedTab: .constant(.calendar))
                .padding(.bottom, 8)
        }
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
