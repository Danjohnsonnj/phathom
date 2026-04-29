//
//  Item.swift
//  Phathom
//
//  Created by Daniel Johnson on 4/29/26.
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
