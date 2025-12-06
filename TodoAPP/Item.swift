//
//  Item.swift
//  TodoAPP
//
//  Created by bore lili on 2025/12/6.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
