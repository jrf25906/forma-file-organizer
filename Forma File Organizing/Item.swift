//
//  Item.swift
//  Forma File Organizing
//
//  Created by James Farmer on 11/17/25.
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
