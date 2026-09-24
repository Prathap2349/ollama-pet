import Foundation
import SwiftUI
import AppKit

// MARK: - Action Confirmation Manager

@MainActor
public class ActionConfirmationManager: ObservableObject {
    public static let shared = ActionConfirmationManager()

    @Published public var pendingAction: MacAction? = nil
    @Published public var isPresenting: Bool = false

    private var confirmationContinuation: CheckedContinuation<Bool, Never>?

    public func requestConfirmation(for action: MacAction) async -> Bool {
        self.pendingAction = action
        self.isPresenting = true

        PetState.shared.showBubble("Waiting for confirmation... ✋", duration: 6.0)

        return await withCheckedContinuation { continuation in
            self.confirmationContinuation = continuation
        }
    }

    public func confirm() {
        guard let action = pendingAction else { return }
        isPresenting = false
        pendingAction = nil
        confirmationContinuation?.resume(returning: true)
        confirmationContinuation = nil

        // Execute action via MacActionExecutor
        Task {
            await MacActionExecutor.shared.executeConfirmedAction(action)
        }
    }

    public func cancel() {
        guard let action = pendingAction else { return }
        isPresenting = false
        pendingAction = nil
        confirmationContinuation?.resume(returning: false)
        confirmationContinuation = nil

        ActionHistoryManager.shared.record(
            actionType: action.type.rawValue,
            summary: action.summaryDescription,
            status: .cancelled,
            detail: "User cancelled the confirmation prompt."
        )

        PetState.shared.showBubble("Action cancelled. ❌", duration: 2.0)
    }
}

// MARK: - Action Confirmation View

public struct ActionConfirmationView: View {
    @ObservedObject var manager = ActionConfirmationManager.shared
    @ObservedObject var petState = PetState.shared

    public var body: some View {
        if let action = manager.pendingAction, manager.isPresenting {
            ZStack {
                Color.black.opacity(0.65)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 16) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("Confirm Mac Action")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    // Content Box
                    VStack(alignment: .leading, spacing: 8) {
                        if action.type == .sendMessage {
                            HStack {
                                Text("Service:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(action.service ?? "Messages")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            HStack {
                                Text("To:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(action.recipient ?? "Unknown")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Message:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("\"\(action.messageText ?? "")\"")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                            }
                        } else if action.type == .runApprovedShortcut {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shortcut Name:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(action.shortcutName ?? "")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text(action.summaryDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            manager.cancel()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            manager.confirm()
                        }) {
                            Text("Confirm & Execute")
                                .font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(petState.currentSpecies.accentColor))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(width: 320)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 8)
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: manager.isPresenting)
        }
    }
}
