import Foundation
import SwiftUI

struct NeededScore {
    let assignmentId: Int
    let neededScore: Double
    let maxPoints: Double
}

struct GoalGradeResult {
    let isPossible: Bool
    let goalGrade: Double
    let neededScores: [NeededScore]
    let maxPossibleGrade: Double
    let message: String
}

@MainActor
class GradeCalculator: ObservableObject {
    @Published var whatIfScores: [Int: Double] = [:]
    @Published var calculatedScore: Double?

    private var assignments: [Assignment] = []
    private var assignmentGroups: [AssignmentGroup] = []
    private var useWeightedGrades: Bool = false

    func initializeWithAssignments(_ assignments: [Assignment], groups: [AssignmentGroup] = [], useWeights: Bool = false) {
        self.assignments = assignments
        self.assignmentGroups = groups
        self.useWeightedGrades = useWeights

        print("🎯 Grade Calculator initialized:")
        print("   Use Weighted Grading: \(useWeights)")
        print("   Assignment Groups: \(groups.count)")
        for group in groups {
            print("   - \(group.name): \(group.groupWeight ?? 0)%")
        }

        calculateGrade()
    }

    func setWhatIfScore(for assignmentId: Int, score: Double?) {
        // Find the original score for this assignment
        let originalScore = assignments.first(where: { $0.id == assignmentId })?.submission?.score

        if let score = score {
            // If setting score to match original, remove from what-if (it's not a change)
            if let original = originalScore, abs(score - original) < 0.01 {
                whatIfScores.removeValue(forKey: assignmentId)
            } else {
                whatIfScores[assignmentId] = score
            }
        } else {
            whatIfScores.removeValue(forKey: assignmentId)
        }
        calculateGrade()
    }

    func resetWhatIfScores() {
        whatIfScores.removeAll()
        calculateGrade()
    }

    func calculateNeededGrades(goalGrade: Double, assignments: [Assignment], groups: [AssignmentGroup], useWeights: Bool) -> GoalGradeResult {
        print("🎯 Calculating needed grades for goal: \(goalGrade)%")

        if useWeights && !groups.isEmpty {
            return calculateNeededGradesWeighted(goalGrade: goalGrade, assignments: assignments, groups: groups)
        } else {
            return calculateNeededGradesUnweighted(goalGrade: goalGrade, assignments: assignments)
        }
    }

    private func calculateNeededGradesUnweighted(goalGrade: Double, assignments: [Assignment]) -> GoalGradeResult {
        var completedPoints: Double = 0
        var completedEarned: Double = 0
        var uncompletedAssignments: [(assignment: Assignment, points: Double)] = []

        for assignment in assignments {
            guard let possible = assignment.pointsPossible, possible > 0 else { continue }

            // Skip assignments that don't count toward final grade
            if assignment.omitFromFinalGrade == true {
                continue
            }

            if let score = whatIfScores[assignment.id] ?? assignment.submission?.score {
                // Already graded or has what-if score
                completedPoints += possible
                completedEarned += score
            } else if !(assignment.submission?.excused ?? false) {
                // Uncompleted and not excused
                uncompletedAssignments.append((assignment, possible))
            }
        }

        let uncompletedPoints = uncompletedAssignments.reduce(0) { $0 + $1.points }
        let totalPoints = completedPoints + uncompletedPoints

        guard totalPoints > 0 else {
            return GoalGradeResult(
                isPossible: false,
                goalGrade: goalGrade,
                neededScores: [],
                maxPossibleGrade: 0,
                message: "No assignments with valid points found."
            )
        }

        // Calculate needed points
        let targetTotalPoints = (goalGrade / 100) * totalPoints
        let neededPoints = targetTotalPoints - completedEarned

        print("   Total Points: \(totalPoints)")
        print("   Completed: \(completedEarned)/\(completedPoints)")
        print("   Uncompleted: \(uncompletedPoints) points")
        print("   Need: \(neededPoints) points")

        // Check if possible
        if neededPoints > uncompletedPoints {
            let maxPossible = ((completedEarned + uncompletedPoints) / totalPoints) * 100
            return GoalGradeResult(
                isPossible: false,
                goalGrade: goalGrade,
                neededScores: [],
                maxPossibleGrade: maxPossible,
                message: "Even with perfect scores on all remaining assignments, you can only achieve \(String(format: "%.1f%%", maxPossible))."
            )
        }

        if neededPoints < 0 {
            return GoalGradeResult(
                isPossible: true,
                goalGrade: goalGrade,
                neededScores: [],
                maxPossibleGrade: goalGrade,
                message: "You've already achieved your goal grade!"
            )
        }

        // Distribute needed points evenly across uncompleted assignments
        let averagePercentage = neededPoints / uncompletedPoints
        var neededScores: [NeededScore] = []

        for (assignment, maxPoints) in uncompletedAssignments {
            let neededScore = averagePercentage * maxPoints
            neededScores.append(NeededScore(
                assignmentId: assignment.id,
                neededScore: neededScore,
                maxPoints: maxPoints
            ))
        }

        return GoalGradeResult(
            isPossible: true,
            goalGrade: goalGrade,
            neededScores: neededScores,
            maxPossibleGrade: goalGrade,
            message: "Goal is achievable with the calculated scores."
        )
    }

    private func calculateNeededGradesWeighted(goalGrade: Double, assignments: [Assignment], groups: [AssignmentGroup]) -> GoalGradeResult {
        print("🎯 Calculating WEIGHTED needed grades...")

        // Group assignments by their group
        var groupData: [Int: (weight: Double, completedEarned: Double, completedTotal: Double, uncompleted: [(Assignment, Double)])] = [:]

        for group in groups {
            guard let weight = group.groupWeight, weight > 0 else { continue }
            groupData[group.id] = (weight, 0, 0, [])
        }

        // Categorize assignments
        for assignment in assignments {
            guard let possible = assignment.pointsPossible, possible > 0,
                  let groupId = assignment.assignmentGroupId,
                  groupData[groupId] != nil else { continue }

            // Skip assignments that don't count toward final grade
            if assignment.omitFromFinalGrade == true {
                continue
            }

            if let score = whatIfScores[assignment.id] ?? assignment.submission?.score {
                groupData[groupId]!.completedTotal += possible
                groupData[groupId]!.completedEarned += score
            } else if !(assignment.submission?.excused ?? false) {
                groupData[groupId]!.uncompleted.append((assignment, possible))
            }
        }

        // Calculate current weighted contribution from each group
        var fixedContribution: Double = 0
        var totalWeight: Double = 0
        var groupsWithUncompleted: [(groupId: Int, weight: Double, completedEarned: Double, completedTotal: Double, uncompletedPoints: Double, uncompleted: [(Assignment, Double)])] = []

        for (groupId, data) in groupData {
            totalWeight += data.weight

            if data.uncompleted.isEmpty {
                // Group is complete - fixed contribution
                if data.completedTotal > 0 {
                    let groupPercentage = (data.completedEarned / data.completedTotal) * 100
                    let contribution = (groupPercentage / 100) * data.weight
                    fixedContribution += contribution
                    print("   Group \(groupId): Complete at \(groupPercentage)%, contributes \(contribution)%")
                }
            } else {
                // Group has uncompleted - can be adjusted
                let uncompletedPoints = data.uncompleted.reduce(0) { $0 + $1.1 }
                groupsWithUncompleted.append((groupId, data.weight, data.completedEarned, data.completedTotal, uncompletedPoints, data.uncompleted))
            }
        }

        let currentGrade = totalWeight > 0 ? (fixedContribution / totalWeight) * 100 : 0

        // Add contribution from partially completed groups
        var currentContributionFromVariable: Double = 0
        for (_, weight, earned, total, _, _) in groupsWithUncompleted {
            if total > 0 {
                let groupPercentage = (earned / total) * 100
                currentContributionFromVariable += (groupPercentage / 100) * weight
            }
        }

        let actualCurrentGrade = totalWeight > 0 ? ((fixedContribution + currentContributionFromVariable) / totalWeight) * 100 : 0
        print("   Current Grade: \(actualCurrentGrade)%")
        print("   Goal Grade: \(goalGrade)%")

        if actualCurrentGrade >= goalGrade {
            return GoalGradeResult(
                isPossible: true,
                goalGrade: goalGrade,
                neededScores: [],
                maxPossibleGrade: goalGrade,
                message: "You've already achieved your goal grade!"
            )
        }

        // Calculate needed variable contribution
        let targetTotalContribution = (goalGrade / 100) * totalWeight
        let neededVariableContribution = targetTotalContribution - fixedContribution

        print("   Need total contribution: \(targetTotalContribution)")
        print("   Fixed contribution: \(fixedContribution)")
        print("   Variable contribution needed: \(neededVariableContribution)")

        // Calculate max possible
        var maxVariableContribution: Double = 0
        for (_, weight, _, _, _, _) in groupsWithUncompleted {
            maxVariableContribution += weight
        }

        if neededVariableContribution > maxVariableContribution {
            let maxPossibleGrade = ((fixedContribution + maxVariableContribution) / totalWeight) * 100
            return GoalGradeResult(
                isPossible: false,
                goalGrade: goalGrade,
                neededScores: [],
                maxPossibleGrade: maxPossibleGrade,
                message: "Even with perfect scores on all remaining assignments, you can only achieve \(String(format: "%.1f%%", maxPossibleGrade))."
            )
        }

        // For each group with uncompleted, calculate needed group percentage
        var neededScores: [NeededScore] = []

        for (groupId, weight, completedEarned, completedTotal, uncompletedPoints, uncompleted) in groupsWithUncompleted {
            // Calculate what percentage this group needs to be
            // contribution = (group_percentage / 100) * weight
            // We want to distribute neededVariableContribution proportionally by weight

            let groupShare = weight / groupsWithUncompleted.reduce(0) { $0 + $1.weight }
            let groupNeededContribution = neededVariableContribution * groupShare

            // group_percentage = (groupNeededContribution / weight) * 100
            let neededGroupPercentage = (groupNeededContribution / weight) * 100

            print("   Group \(groupId): needs \(neededGroupPercentage)% overall")

            // Now calculate what points are needed in uncompleted assignments
            let totalGroupPoints = completedTotal + uncompletedPoints
            let targetGroupEarned = (neededGroupPercentage / 100) * totalGroupPoints
            let neededFromUncompleted = targetGroupEarned - completedEarned

            print("      Total group points: \(totalGroupPoints)")
            print("      Target earned: \(targetGroupEarned)")
            print("      Already earned: \(completedEarned)")
            print("      Need from uncompleted: \(neededFromUncompleted)")

            if neededFromUncompleted < 0 {
                // Already exceeds goal in this group - set to 0 or distribute remainder
                for (assignment, maxPoints) in uncompleted {
                    neededScores.append(NeededScore(
                        assignmentId: assignment.id,
                        neededScore: 0,
                        maxPoints: maxPoints
                    ))
                }
            } else {
                // Distribute evenly across uncompleted assignments
                let averagePercentage = neededFromUncompleted / uncompletedPoints

                for (assignment, maxPoints) in uncompleted {
                    let neededScore = min(averagePercentage * maxPoints, maxPoints)
                    neededScores.append(NeededScore(
                        assignmentId: assignment.id,
                        neededScore: neededScore,
                        maxPoints: maxPoints
                    ))
                    print("      \(assignment.name): need \(neededScore)/\(maxPoints) = \(neededScore/maxPoints * 100)%")
                }
            }
        }

        return GoalGradeResult(
            isPossible: true,
            goalGrade: goalGrade,
            neededScores: neededScores,
            maxPossibleGrade: goalGrade,
            message: "Goal is achievable with the calculated scores."
        )
    }

    private func calculateGrade() {
        if useWeightedGrades && !assignmentGroups.isEmpty {
            // Weighted grade calculation - matches Canvas LMS algorithm
            print("📊 Calculating WEIGHTED grade...")
            var totalWeightWithScores: Double = 0
            var weightedSum: Double = 0
            var hasAnyScores = false

            for group in assignmentGroups {
                guard let weight = group.groupWeight, weight > 0 else {
                    print("⚠️ Skipping group \(group.name) - no weight")
                    continue
                }

                // Get all assignments in this group
                let groupAssignments = assignments.filter { $0.assignmentGroupId == group.id }
                var groupTotal: Double = 0
                var groupEarned: Double = 0
                var groupHasScores = false

                print("   📁 Group: \(group.name) (Weight: \(weight)%)")

                for assignment in groupAssignments {
                    guard let possible = assignment.pointsPossible, possible > 0 else {
                        print("      ⚠️ Skipping \(assignment.name) - no points_possible")
                        continue
                    }

                    // Skip assignments that don't count toward final grade
                    if assignment.omitFromFinalGrade == true {
                        print("      ⚠️ Skipping \(assignment.name) - omitted from final grade")
                        continue
                    }

                    let score = whatIfScores[assignment.id] ?? assignment.submission?.score

                    if let score = score, !(assignment.submission?.excused ?? false) {
                        groupTotal += possible
                        groupEarned += score
                        groupHasScores = true
                        hasAnyScores = true
                        print("      ✅ \(assignment.name): \(score)/\(possible)")
                    }
                }

                // Calculate this group's contribution
                // IMPORTANT: Only count weight if group has scores (Canvas behavior)
                if groupHasScores && groupTotal > 0 {
                    let groupPercentage = (groupEarned / groupTotal) * 100
                    // Canvas formula: percentage * weight (not divided by 100)
                    let weightedContribution = groupPercentage * weight
                    weightedSum += weightedContribution
                    totalWeightWithScores += weight

                    print("      📊 Group Score: \(String(format: "%.2f%%", groupPercentage)) (Earned: \(groupEarned)/\(groupTotal))")
                    print("      ⚖️ Weighted Contribution: \(String(format: "%.2f", weightedContribution)) (= \(groupPercentage)% × \(weight))")
                } else {
                    print("      ⚠️ No scores in this group - NOT counted in weight total")
                }
            }

            if hasAnyScores && totalWeightWithScores > 0 {
                // Canvas divides by the sum of weights that have scores
                calculatedScore = weightedSum / totalWeightWithScores
                print("📊 Final Weighted Grade: \(String(format: "%.2f%%", calculatedScore!)) = \(String(format: "%.2f", weightedSum)) / \(totalWeightWithScores)")
            } else {
                calculatedScore = nil
                print("📊 No valid scores to calculate weighted grade")
            }
        } else {
            // Non-weighted (point-based) calculation
            print("📊 Calculating NON-WEIGHTED grade...")
            var totalPoints: Double = 0
            var earnedPoints: Double = 0
            var hasScores = false

            for assignment in assignments {
                // Only use assignments with valid pointsPossible
                guard let possible = assignment.pointsPossible, possible > 0 else {
                    print("⚠️ Skipping assignment \(assignment.name) - no points_possible")
                    continue
                }

                // Skip assignments that don't count toward final grade
                if assignment.omitFromFinalGrade == true {
                    print("⚠️ Skipping assignment \(assignment.name) - omitted from final grade")
                    continue
                }

                let score = whatIfScores[assignment.id] ?? assignment.submission?.score

                if let score = score, !(assignment.submission?.excused ?? false) {
                    totalPoints += possible
                    earnedPoints += score
                    hasScores = true
                }
            }

            if hasScores && totalPoints > 0 {
                calculatedScore = (earnedPoints / totalPoints) * 100
                print("📊 Calculated grade: \(String(format: "%.2f%%", calculatedScore!)) (\(earnedPoints)/\(totalPoints))")
            } else {
                calculatedScore = nil
                print("📊 No valid scores to calculate grade")
            }
        }
    }
}
