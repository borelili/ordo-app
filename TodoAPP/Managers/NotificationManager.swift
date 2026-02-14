//
//  NotificationManager.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("通知权限已授予")
            } else if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for task: Task, at date: Date) {
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
            if let error = error {
                print("添加通知失败: \(error.localizedDescription)")
            } else {
                print("通知已设置: \(task.title) 在 \(date)")
            }
        }
    }
    
    func cancelNotification(for task: Task) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    func updateNotification(for task: Task, at date: Date) {
        cancelNotification(for: task)
        scheduleNotification(for: task, at: date)
    }
}
