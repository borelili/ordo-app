//
//  NotificationManager.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum NotificationAuthorizationError: LocalizedError {
    case denied
    case notDetermined
    case restricted
    
    var errorDescription: String? {
        switch self {
        case .denied:
            return "通知权限已被拒绝"
        case .notDetermined:
            return "通知权限未确定"
        case .restricted:
            return "通知权限受限"
        }
    }
}

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - 权限检查（同步返回当前状态）
    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - 请求权限（首次请求或未确定时）
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 通知权限已授予")
                } else if let error = error {
                    print("❌ 通知权限请求失败: \(error.localizedDescription)")
                } else {
                    print("⚠️ 用户拒绝了通知权限")
                }
                completion(granted, error)
            }
        }
    }
    
    // MARK: - 调度通知（带权限检查）
    func scheduleNotification(for task: Task, at date: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        checkAuthorizationStatus { status in
            switch status {
            case .authorized, .provisional, .ephemeral:
                // 权限已授予，继续调度通知
                self.performScheduleNotification(for: task, at: date, completion: completion)
                
            case .denied:
                // 权限被拒绝，返回错误
                completion(.failure(NotificationAuthorizationError.denied))
                
            case .notDetermined:
                // 权限未确定，先请求权限
                self.requestAuthorization { granted, error in
                    if granted {
                        self.performScheduleNotification(for: task, at: date, completion: completion)
                    } else {
                        completion(.failure(error ?? NotificationAuthorizationError.notDetermined))
                    }
                }
                
            @unknown default:
                completion(.failure(NotificationAuthorizationError.restricted))
            }
        }
    }
    
    // MARK: - 实际调度通知的私有方法
    private func performScheduleNotification(for task: Task, at date: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "待办提醒"
        content.body = task.title
        content.sound = .default
        
        if !task.taskDescription.isEmpty {
            content.subtitle = task.taskDescription
        }
        
        // 设置触发器
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 添加通知失败: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ 通知已设置: \(task.title) 在 \(date)")
                    completion(.success(()))
                }
            }
        }
    }
    
    func cancelNotification(for task: Task) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
        print("🗑️ 已取消通知: \(task.title)")
    }
    
    func updateNotification(for task: Task, at date: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        cancelNotification(for: task)
        scheduleNotification(for: task, at: date, completion: completion)
    }
    
    // MARK: - 打开系统设置
    #if os(iOS)
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    #elseif os(macOS)
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    #endif
}
