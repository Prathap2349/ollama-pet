import Foundation
import SwiftUI

// MARK: - Action Execution Status

public enum ActionExecutionStatus: String, Codable, CaseIterable {
    case success = "Success"
    case partial = "Partial Success"
    case blocked = "Blocked for Safety"
    case cancelled = "Cancelled by User"
    case failed = "Execution Failed"
    case needsConfirmation = "Pending Confirmation"
    case needsClarification = "Needs Clarification"
    case needsPermission = "Permission Required"

    public var badgeColor: Color {
        switch self {
        case .success: return .green
        case .partial: return .orange
        case .blocked: return .orange
        case .cancelled: return .gray
        case .failed: return .red
        case .needsConfirmation: return .yellow
        case .needsClarification: return .blue
        case .needsPermission: return .purple
        }
    }

    public var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .blocked: return "shield.slash.fill"
        case .cancelled: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .needsConfirmation: return "questionmark.circle.fill"
        case .needsClarification: return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .needsPermission: return "lock.fill"
        }
    }
}

// MARK: - Action History Item

public struct ActionHistoryItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let actionType: String
    public let summary: String
    public let status: ActionExecutionStatus
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionType: String,
        summary: String,
        status: ActionExecutionStatus,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.summary = summary
        self.status = status
        self.detail = detail
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }

    public var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Action History Manager

@MainActor
public class ActionHistoryManager: ObservableObject {
    public static let shared = ActionHistoryManager()

    @Published public var items: [ActionHistoryItem] = []

    public init() {
        loadHistory()
    }

    public func loadHistory() {
        if let saved = DataManager.shared.savedData.actionHistory {
            self.items = saved
        }
    }

    public func record(
        actionType: String,
        summary: String,
        status: ActionExecutionStatus,
        detail: String? = nil
    ) {
        let item = ActionHistoryItem(
            actionType: actionType,
            summary: summary,
            status: status,
            detail: detail
        )
        items.insert(item, at: 0)

        // Cap history to 50 items to minimize memory and storage
        if items.count > 50 {
            items = Array(items.prefix(50))
        }

        saveHistory()
    }

    public func clearHistory() {
        items.removeAll()
        saveHistory()
    }

    private func saveHistory() {
        DataManager.shared.savedData.actionHistory = items
        DataManager.shared.saveData()
    }
}
