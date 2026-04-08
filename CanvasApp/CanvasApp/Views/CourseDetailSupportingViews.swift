import SwiftUI

struct CircularGradeView: View {
    let score: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(gradeColor(for: score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.title.bold())
                Text("%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func gradeColor(for score: Double) -> Color {
        switch score {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .yellow
        default: return .red
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EnhancedAssignmentRow: View {
    let assignment: Assignment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with name and status badge
            HStack(alignment: .top, spacing: 8) {
                Text(assignment.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Status badge
                StatusBadgeCompact(assignment: assignment)
            }
            .padding(.bottom, 8)

            // Grade/Score section - ALWAYS show if points exist
            if let possible = assignment.pointsPossible {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // Score display
                    if let submission = assignment.submission, let score = submission.score {
                        Text("\(String(format: "%.1f", score))")
                            .font(.title3.bold())
                            .foregroundColor(scoreColor(score: score, possible: possible))

                        Text("/")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(String(format: "%.1f", possible))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Percentage badge
                        if let percentage = calculatePercentage(score: score, possible: possible) {
                            Text("\(String(format: "%.0f%%", percentage))")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(percentageColor(percentage))
                                .cornerRadius(8)
                        }

                        // Letter grade if available
                        if let grade = submission.grade, !grade.isEmpty, grade != String(format: "%.2f", score) {
                            Text(grade)
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // No score yet
                        Text("—")
                            .font(.title3.bold())
                            .foregroundColor(.secondary)

                        Text("/")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(String(format: "%.1f", possible))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("pts")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if assignment.isSubmitted && !assignment.isGraded {
                            Text("Pending")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 8)
            } else {
                // No points possible defined
                HStack {
                    Text("No points assigned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.bottom, 8)
            }

            // Due date and metadata
            HStack(spacing: 12) {
                if let dueAt = assignment.dueAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dueAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("No due date")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Points deducted indicator
                if let deductions = assignment.submission?.pointsDeducted, deductions > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "minus.circle.fill")
                            .font(.caption2)
                        Text("-\(String(format: "%.1f", deductions)) pts")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                }

                // Late indicator with time
                if let submission = assignment.submission, let seconds = submission.secondsLate, seconds > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.caption2)
                        let hours = seconds / 3600
                        let days = hours / 24
                        let timeText = days > 0 ? "\(days)d late" : "\(hours)h late"
                        Text(timeText)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func calculatePercentage(score: Double, possible: Double) -> Double? {
        guard possible > 0 else { return nil }
        return (score / possible) * 100
    }

    private func scoreColor(score: Double, possible: Double) -> Color {
        if score == 0 { return .red }
        let percentage = (score / possible) * 100
        return percentageColor(percentage)
    }

    private func percentageColor(_ percentage: Double) -> Color {
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .yellow
        default: return .red
        }
    }
}

struct StatusBadgeCompact: View {
    let assignment: Assignment

    var body: some View {
        Group {
            if assignment.isExcused {
                CompactBadge(text: "Excused", color: .purple, icon: "checkmark.circle.fill")
            } else if assignment.isMissing {
                CompactBadge(text: "Missing", color: .red, icon: "exclamationmark.circle.fill")
            } else if assignment.hasZeroScore {
                CompactBadge(text: "Zero", color: .red, icon: "0.circle.fill")
            } else if assignment.needsGrading {
                CompactBadge(text: "Pending", color: .orange, icon: "clock.fill")
            } else if assignment.isLate {
                CompactBadge(text: "Late", color: .yellow, icon: "clock.badge.exclamationmark.fill")
            } else if assignment.isGraded {
                CompactBadge(text: "Graded", color: .green, icon: "checkmark.circle.fill")
            } else if assignment.isSubmitted {
                CompactBadge(text: "Submitted", color: .blue, icon: "paperplane.fill")
            } else {
                CompactBadge(text: "Not Done", color: .secondary, icon: "circle")
            }
        }
    }
}

struct CompactBadge: View {
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(6)
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
        }
    }
}
