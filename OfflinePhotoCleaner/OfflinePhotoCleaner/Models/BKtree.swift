import SwiftData
import Foundation
import SwiftPhashBKtree

@Model
final class BKtreePersistent {
    var bkTree: String
    var timestamp: Date?
    
    init(bktree: String) {
        self.bkTree = bktree
        self.timestamp = Date()
    }
}

class BKtreeInMemory {
    var bkTree: SwiftPhashBKTree
    init() {
        self.bkTree = SwiftPhashBKTree()
    }
}

@Model
final class PhashMap {
    @Attribute(.unique) var phash: String
    @Relationship(deleteRule: .cascade, inverse: \PhotoInfo.phash)
    var photoInfoList = [PhotoInfo]()
    
    init(phash: String) {
        self.phash = phash
    }
}

@Model
final class PhotoInfo {
    @Attribute(.unique) var localID: String
    var timestamp: Date
    var isSelected: Bool
    var phash: PhashMap?
    
    init(id: String, timestamp: Date) {
        self.localID = id
        self.timestamp = timestamp
        self.isSelected = false
    }
}

