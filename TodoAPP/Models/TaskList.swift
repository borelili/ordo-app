//
//  TaskList.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class TaskList {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \Task.taskList)
    var tasks: [Task]?

    init(name: String, icon: String = "list.bullet", color: String = "blue", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.tasks = []
    }
    
    var colorValue: Color {
        switch color {
        case "blue":   return .blue
        case "cyan":   return .cyan
        case "teal":   return Color(.systemTeal)
        case "green":  return .green
        case "mint":   return Color(.systemMint)
        case "yellow": return .yellow
        case "orange": return .orange
        case "red":    return .red
        case "pink":   return .pink
        case "purple": return .purple
        case "indigo": return .indigo
        case "brown":  return .brown
        case "gray":   return .gray
        default:       return .blue
        }
    }
}
