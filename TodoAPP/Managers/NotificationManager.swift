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

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - 前台通知展示（App 在前台时也显示横幅+声音）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
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
                #if DEBUG
                if granted {
                    print("✅ 通知权限已授予")
                } else if let error = error {
                    print("❌ 通知权限请求失败: \(error.localizedDescription)")
                } else {
                    print("⚠️ 用户拒绝了通知权限")
                }
                #endif
                completion(granted, error)
            }
        }
    }
    
    // MARK: - 调度通知（统一使用 reminderDate）
    func scheduleNotification(for task: Task, completion: @escaping (Result<Void, Error>) -> Void) {
        // 只使用 reminderDate 作为触发器
        guard let reminderDate = task.reminderDate else {
            #if DEBUG
            print("⚠️ [Notification] Task '\(task.title)' 无 reminderDate，跳过调度")
            #endif
            completion(.failure(NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "任务没有设置提醒时间"])))
            return
        }
        
        checkAuthorizationStatus { status in
            #if DEBUG
            print("📋 [Notification] 授权状态: \(status.rawValue) for '\(task.title)'")
            #endif
            
            switch status {
            case .authorized, .provisional, .ephemeral:
                // 权限已授予，继续调度通知
                self.performScheduleNotification(for: task, at: reminderDate, completion: completion)
                
            case .denied:
                // 权限被拒绝，返回错误
                #if DEBUG
                print("❌ [Notification] 权限被拒绝 for '\(task.title)'")
                #endif
                completion(.failure(NotificationAuthorizationError.denied))
                
            case .notDetermined:
                // 权限未确定，先请求权限
                #if DEBUG
                print("❓ [Notification] 权限未确定，请求权限 for '\(task.title)'")
                #endif
                self.requestAuthorization { granted, error in
                    if granted {
                        self.performScheduleNotification(for: task, at: reminderDate, completion: completion)
                    } else {
                        completion(.failure(error ?? NotificationAuthorizationError.notDetermined))
                    }
                }
                
            @unknown default:
                #if DEBUG
                print("⚠️ [Notification] 权限状态未知 for '\(task.title)'")
                #endif
                completion(.failure(NotificationAuthorizationError.restricted))
            }
        }
    }
    
    // MARK: - 实际调度通知的私有方法
    private func performScheduleNotification(for task: Task, at date: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let identifier = task.id.uuidString
        
        // 先取消已有通知，确保不重复
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
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
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        #if DEBUG
        print("📌 [Notification] 调度通知:")
        print("   - Task: '\(task.title)'")
        print("   - Identifier: \(identifier)")
        print("   - Trigger: \(date)")
        print("   - Components: \(components)")
        #endif
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("❌ [Notification] 添加通知失败: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } else {
                // 查询 pending 通知数量
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    #if DEBUG
                    print("✅ [Notification] 通知已设置成功")
                    print("   - 当前 Pending 通知数量: \(requests.count)")
                    #endif
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    func cancelNotification(for task: Task) {
        let identifier = task.id.uuidString
        cancelNotifications(withIdentifiers: [identifier], label: task.title)
    }

    /// 按稳定 identifier 列表批量取消通知（删除前已捕获 UUID，无需访问对象）
    func cancelNotifications(withIdentifiers identifiers: [String], label: String = "") {
        guard !identifiers.isEmpty else { return }

        #if DEBUG
        UNUserNotificationCenter.current().getPendingNotificationRequests { before in
            print("🗑️ [Notification] cancelNotifications — 取消前 pending: \(before.count)")
            print("   取消 identifiers(\(identifiers.count)): \(identifiers.joined(separator: ", "))")
            if !label.isEmpty { print("   label: \(label)") }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

            UNUserNotificationCenter.current().getPendingNotificationRequests { after in
                print("   取消后 pending: \(after.count)  (减少 \(before.count - after.count))")
            }
        }
        #else
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        #endif
    }

    func updateNotification(for task: Task, completion: @escaping (Result<Void, Error>) -> Void) {
        cancelNotification(for: task)
        scheduleNotification(for: task, completion: completion)
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
