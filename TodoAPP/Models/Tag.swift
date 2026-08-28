//
//  Tag.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "gray"
    
    @Relationship(deleteRule: .nullify, inverse: \Task.tags)
    var tasks: [Task]?
    
    init(name: String, color: String = "gray") {
        self.id = UUID()
        self.name = name
        self.color = color
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
