//
//  RootView.swift
//  TodoAPP
//
//  Created on 2026/02/23
//
//  使用 BottomPillNav 自定义底部胶囊导航

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var odysseyStore = OdysseyStore()   // 全局唯一实例
    @State private var selectedTab: PillNavTab = .dashboard
    @State private var showingAddTask = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主题背景渐变
            LinearGradient(
                colors: theme.current.backgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 页面内容区：根据 selectedTab 切换
            Group {
                switch selectedTab {
                case .dashboard:
                    // 功能开关：改为 false 可回滚到经典 ListDashboardView
                    if FeatureFlags.useTodayDashboard {
                        TodayDashboardView()
                    } else {
                        ListDashboardView()
                    }
                case .myLists:
                    ListDashboardView()
                case .lists:
                    ContentView()
                case .calendar:
                    CalendarView()
                }
            }
            .environmentObject(odysseyStore)
            .environment(\.odysseyStore, odysseyStore)
            // 底部避让透过各页面的可滚动容器直接施加 DS.homeBottomInset 实现，
            // 而非靠 safeAreaInset 天闭個 NavigationStack 传播。

            // 底部胶囊导航 + FAB
            VStack(spacing: 0) {
                // 浮动新增按钮（FAB）——
                // .myLists（规划/奥德赛）标签由各子页面自行管理 FAB，不显示全局 +
                if selectedTab != .myLists {
                    HStack {
                        Spacer()
                        Button {
                            showingAddTask = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(theme.current.accentTextColor)
                                .frame(width: 52, height: 52)
                                .background(theme.current.fabBackground)
                                .clipShape(Circle())
                                .cardShadow(DS.Shadow.card)
                        }
                        .accessibilityLabel("新建任务")
                        .padding(.trailing, DS.paddingScreen)
                        .padding(.bottom, DS.spacingSM)
                    }
                }

                // 胶囊导航
                BottomPillNav(selectedTab: $selectedTab)
                    .padding(.bottom, DS.spacingMD)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
        // 主题对应的 colorScheme，让系统组件（List、NavigationBar等）自动适配
        .preferredColorScheme(theme.current.colorScheme)
        // 防止键盘顶起导航栏
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    RootView()
}
