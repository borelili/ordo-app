//
//  NotificationPermissionHelper.swift
//  TodoAPP
//
//  Created on 2026/02/14
//

import SwiftUI

// MARK: - 权限提示配置
struct NotificationPermissionAlert {
    var isPresented: Bool = false
    var onOpenSettings: () -> Void = {}
    var onDismiss: () -> Void = {}
}

// MARK: - View Extension for Permission Alert
extension View {
    func notificationPermissionAlert(
        isPresented: Binding<Bool>,
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        self.alert("需要通知权限", isPresented: isPresented) {
            Button("去设置开启", role: nil) {
                onOpenSettings()
                onDismiss()
            }
            Button("取消", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text("TodoAPP 需要通知权限才能在指定时间提醒你完成任务。\n\n请在系统设置中开启通知权限。")
        }
    }
}

// MARK: - 便捷调用的 ViewModifier
struct NotificationPermissionModifier: ViewModifier {
    @Binding var showPermissionAlert: Bool
    var onSettingsOpened: () -> Void
    var onDismissed: () -> Void
    
    func body(content: Content) -> some View {
        content
            .notificationPermissionAlert(
                isPresented: $showPermissionAlert,
                onOpenSettings: {
                    NotificationManager.shared.openNotificationSettings()
                    onSettingsOpened()
                },
                onDismiss: onDismissed
            )
    }
}

extension View {
    func handleNotificationPermission(
        showAlert: Binding<Bool>,
        onSettingsOpened: @escaping () -> Void = {},
        onDismissed: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(NotificationPermissionModifier(
            showPermissionAlert: showAlert,
            onSettingsOpened: onSettingsOpened,
            onDismissed: onDismissed
        ))
    }
}
