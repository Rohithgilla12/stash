import Foundation

struct LinkPreview: Codable, Sendable, Equatable {
    var title: String?
    var domain: String?
    var imagePath: String?
    var failed: Bool = false
}
