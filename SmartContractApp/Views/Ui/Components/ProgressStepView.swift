//
//  ProgressStepView.swift
//  SmartContractApp
//
//  Created by Kiro on 11/12/25.
//

import SwiftUI

// MARK: - Task State

/// Represents the state of a task in a progress flow
public enum TaskState: Equatable {
    case idle
    case inProgress
    case success
    case failed(String)
}

// MARK: - Progress Step View

/// A simple, native-looking progress step indicator
struct ProgressStepView: View {
    // MARK: - Properties

    let title: String
    let state: TaskState
    let systemImage: String

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Step indicator circle
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                if state == .inProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }

            // Title
            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            // Status label
            if let label = statusLabel {
                Text(label)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch state {
        case .idle:
            return systemImage
        case .inProgress:
            return systemImage
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle:
            return .secondary
        case .inProgress:
            return .blue
        case .success:
            return .green
        case .failed:
            return .red
        }
    }

    private var statusLabel: String? {
        switch state {
        case .idle:
            return nil
        case .inProgress:
            return "In progress"
        case .success:
            return "Done"
        case .failed(let message):
            return message.isEmpty ? "Failed" : message
        }
    }
}

// MARK: - Preview

#Preview("Progress Steps") {
    Form {
        List {
            ProgressStepView(
                title: "Idle Step",
                state: .idle,
                systemImage: "doc.text"
            )

            ProgressStepView(
                title: "In Progress Step",
                state: .inProgress,
                systemImage: "network"
            )

            ProgressStepView(
                title: "Success Step",
                state: .success,
                systemImage: "checkmark.circle"
            )

            ProgressStepView(
                title: "Failed Step",
                state: .failed("Something went wrong with the operation"),
                systemImage: "xmark.circle"
            )
        }
    }
    .formStyle(.grouped)
}
