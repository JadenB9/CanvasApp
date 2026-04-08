import Foundation

struct AssignmentGroup: Codable, Identifiable {
    let id: Int
    let name: String
    let position: Int
    let groupWeight: Double?
    let sisSourceId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, position
        case groupWeight = "group_weight"
        case sisSourceId = "sis_source_id"
    }
}
