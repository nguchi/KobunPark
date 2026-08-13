//
//  Item.swift
//  KobunPark
//
//  Created by 野口真吾 on 2026/08/14.
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
