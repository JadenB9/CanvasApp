//
//  AssignmentRowView.swift
//  CanvasApp
//
//  Created by Jaden Butler on 1/24/25.
//

import SwiftUI

struct AssignmentRowView: View {
    let assignment: Assignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(assignment.name)
                    .font(.headline)
                    .lineLimit(2)

                if assignment.omitFromFinalGrade == true {
                    Text("BONUS")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Label {
                    Text(assignment.formattedDueDate)
                } icon: {
                    Image(systemName: "calendar")
                }

                Label {
                    Text("\(String(format: "%.1f", assignment.pointsPossible ?? 0)) pts")
                } icon: {
                    Image(systemName: "star")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let description = assignment.description {
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}
