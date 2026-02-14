//
//  Task.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Task {
    var id: UUID
    var title: String
    var taskDescription: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var order: Int  // 任务排序顺序
    
    // 关系
    var taskList: TaskList?
    var tags: [Tag]?
    
    @Relationship(deleteRule: .cascade, inverse: \Subtask.parentTask)
    var subtasks: [Subtask]?
    
    init(
        title: String,
        taskDescription: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        taskList: TaskList? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.order = 0  // 默认排序值，创建时会被设置为实际值
        self.taskList = taskList
        self.tags = []
        self.subtasks = []
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "低"
        case medium = "中"
        case high = "高"
        case urgent = "紧急"
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .green
            case .high: return .orange
            case .urgent: return .red
            }
        }
    }
}

@Model
final class Subtask {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var parentTask: Task?
    
    init(title: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
    }
}
