import Foundation
import SwiftUI

enum BranchStyle: String, CaseIterable, Identifiable {
    case `default` = "default"
    case curved = "curved"
    case straight = "straight"
    
    var id: String { self.rawValue }
}
