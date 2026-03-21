// ThemeManager.swift
// TickTick — Theme System
// 主题管理器：持久化当前主题，全局 EnvironmentObject

import SwiftUI
import Combine

// MARK: - ThemeManager

@MainActor
final class ThemeManager: ObservableObject {

    /// 当前激活的主题，变化时所有订阅视图自动更新
    @Published private(set) var current: AppTheme

    private static let storageKey = "selectedThemeId"

    // MARK: - Init

    init() {
        let savedId = UserDefaults.standard.string(forKey: Self.storageKey)
            ?? AppTheme.classicPurple.id
        self.current = AppTheme.all.first { $0.id == savedId }
            ?? AppTheme.classicPurple
    }

    // MARK: - API

    /// 切换主题（立即更新 UI + 持久化到 UserDefaults）
    func select(_ theme: AppTheme) {
        guard current.id != theme.id else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            current = theme
        }
        UserDefaults.standard.set(theme.id, forKey: Self.storageKey)
    }
}
