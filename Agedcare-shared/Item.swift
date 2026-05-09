//
//  Item.swift
//  Agedcare-shared
//
//  Created by Christopher Appiah-Thompson  on 10/5/2026.
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
