import Foundation
import SwiftUI

struct CourseGrades: Codable {
    let currentGrade: String?
    let finalGrade: String?
    let currentScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case currentGrade = "computed_current_grade"
        case finalGrade = "computed_final_grade"
        case currentScore = "computed_current_score"
    }
    
    init(currentGrade: String?, finalGrade: String?, currentScore: Double?) {
        self.currentGrade = currentGrade
        self.finalGrade = finalGrade
        self.currentScore = currentScore
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentGrade = try container.decodeIfPresent(String.self, forKey: .currentGrade)
        finalGrade = try container.decodeIfPresent(String.self, forKey: .finalGrade)
        currentScore = try container.decodeIfPresent(Double.self, forKey: .currentScore)
    }
}
