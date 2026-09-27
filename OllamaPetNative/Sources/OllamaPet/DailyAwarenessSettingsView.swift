import Foundation
import SwiftUI
import EventKit

// MARK: - Daily Awareness Settings Section

public struct DailyAwarenessSettingsSection: View {
    @ObservedObject var dataManager = DataManager.shared
    @ObservedObject var petState = PetState.shared
    @ObservedObject var dailyAwareness = DailyAwarenessService.shared
    @ObservedObject var scheduler = DailyAwarenessScheduler.shared

    @State private var isEnabled: Bool = true
    @State private var selectedHour: Int = 8
    @State private var selectedMinute: Int = 30
    @State private var speakAloud: Bool = false

    @State private var finnhubKeyInput: String = ""
    @State private var gnewsKeyInput: String = ""
    @State private var calendarStatus: EKAuthorizationStatus = .notDetermined

    @State private var isTestingFetch: Bool = false
    @State private var testResultSnippet: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    Text("Daily Awareness")
                        .font(.system(size: 18, weight: .bold))
                }
                Text("Your pet gathers a small amount of factual data (calendar, top news, market watch) and summarizes it using local Ollama.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. Morning Scheduling Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scheduled Morning Briefing")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Delivers a short notification when your briefing is ready. Resilient to Mac sleep.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { dataManager.savedData.dailyAwarenessEnabled ?? true },
                        set: { val in
                            dataManager.savedData.dailyAwarenessEnabled = val
                            dataManager.saveData()
                            scheduler.updateNextScheduledTimeString()
                        }
                    ))
                    .toggleStyle(.switch)
                }

                if dataManager.savedData.dailyAwarenessEnabled ?? true {
                    Divider().opacity(0.4)

                    // Time Picker
                    HStack(spacing: 16) {
                        Text("Scheduled Time:")
                            .font(.system(size: 12, weight: .medium))

                        HStack(spacing: 6) {
                            Picker("Hour", selection: Binding(
                                get: { dataManager.savedData.dailyAwarenessHour ?? 8 },
                                set: { val in
                                    dataManager.savedData.dailyAwarenessHour = val
                                    dataManager.saveData()
                                    scheduler.updateNextScheduledTimeString()
                                }
                            )) {
                                ForEach(0..<24, id: \.self) { h in
                                    let period = h >= 12 ? "PM" : "AM"
                                    let displayH = h % 12 == 0 ? 12 : h % 12
                                    Text("\(displayH) \(period)").tag(h)
                                }
                            }
                            .frame(width: 90)

                            Text(":")
                                .font(.system(size: 13, weight: .bold))

                            Picker("Minute", selection: Binding(
                                get: { dataManager.savedData.dailyAwarenessMinute ?? 30 },
                                set: { val in
                                    dataManager.savedData.dailyAwarenessMinute = val
                                    dataManager.saveData()
                                    scheduler.updateNextScheduledTimeString()
                                }
                            )) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .frame(width: 70)
                        }

                        Spacer()

                        Text("Next run: \(scheduler.nextScheduledTimeString)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Spoken Briefing Toggle
                    Toggle("Speak morning awareness digest aloud", isOn: Binding(
                        get: { dataManager.savedData.dailyAwarenessSpeak ?? false },
                        set: { val in
                            dataManager.savedData.dailyAwarenessSpeak = val
                            dataManager.saveData()
                        }
                    ))
                    .font(.system(size: 12))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // 2. Data Sources Configuration
            VStack(alignment: .leading, spacing: 14) {
                Text("Awareness Data Sources")
                    .font(.system(size: 13, weight: .semibold))

                // Apple Calendar
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Calendar (Local EventKit)")
                            .font(.system(size: 12, weight: .medium))
                        Text(calendarStatusText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !isCalendarGranted {
                        Button("Request Access") {
                            Task {
                                _ = await dailyAwareness.requestCalendarPermission()
                                updateCalendarStatus()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Divider().opacity(0.4)

                // News Source
                HStack(alignment: .top) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("World & Tech News (Public RSS)")
                            .font(.system(size: 12, weight: .medium))
                        Text("Uses BBC World and BBC Tech RSS feeds by default. Zero API key needed.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        // Optional GNews API key field
                        HStack(spacing: 8) {
                            SecureField(
                                APIKeyManager.shared.hasKey(for: "gnews")
                                    ? "GNews Key Configured (\(APIKeyManager.shared.maskedKey(for: "gnews")))"
                                    : "Optional: GNews API Key",
                                text: $gnewsKeyInput
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))

                            if !gnewsKeyInput.isEmpty {
                                Button("Save") {
                                    APIKeyManager.shared.setKey(gnewsKeyInput, for: "gnews")
                                    gnewsKeyInput = ""
                                }
                                .controlSize(.small)
                            } else if APIKeyManager.shared.hasKey(for: "gnews") {
                                Button("Remove") {
                                    APIKeyManager.shared.deleteKey(for: "gnews")
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Divider().opacity(0.4)

                // Market / Earnings Source
                HStack(alignment: .top) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Earnings & Markets")
                            .font(.system(size: 12, weight: .medium))
                        Text("Watches key benchmark tickers (AAPL, NVDA, MSFT, GOOGL). 15-minute delayed data.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        // Optional Finnhub Key field
                        HStack(spacing: 8) {
                            SecureField(
                                APIKeyManager.shared.hasKey(for: "finnhub")
                                    ? "Finnhub Key Configured (\(APIKeyManager.shared.maskedKey(for: "finnhub")))"
                                    : "Optional: Finnhub API Key (for Live Earnings Calendar)",
                                text: $finnhubKeyInput
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))

                            if !finnhubKeyInput.isEmpty {
                                Button("Save") {
                                    APIKeyManager.shared.setKey(finnhubKeyInput, for: "finnhub")
                                    finnhubKeyInput = ""
                                }
                                .controlSize(.small)
                            } else if APIKeyManager.shared.hasKey(for: "finnhub") {
                                Button("Remove") {
                                    APIKeyManager.shared.deleteKey(for: "finnhub")
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // 3. Diagnostics & Test Action
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Awareness Snapshot Cache & Test")
                            .font(.system(size: 13, weight: .semibold))
                        if let lastTime = dailyAwareness.lastFetchTime {
                            Text("Last fetched: \(DateFormatter.localizedString(from: lastTime, dateStyle: .short, timeStyle: .medium))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No snapshot fetched yet today.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()

                    Button(action: {
                        isTestingFetch = true
                        Task {
                            let snap = await dailyAwareness.fetchFreshSnapshot()
                            let calCount = snap.calendarEvents.count
                            let newsCount = snap.news.count
                            let marketCount = snap.earnings.count
                            testResultSnippet = "✓ Snapshot updated: \(calCount) calendar events, \(newsCount) news headlines, \(marketCount) market items."
                            isTestingFetch = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isTestingFetch {
                                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh Snapshot Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isTestingFetch)
                }

                if let result = testResultSnippet {
                    Text(result)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04)))

            // 4. Local-Only Privacy Badge
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("100% Local AI Privacy Guarantee")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                    Text("Daily Awareness operates strictly via your local Ollama model. Calendar items, personal schedule, and news snapshots are NEVER sent to cloud AI providers.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2), lineWidth: 1))
        }
        .onAppear {
            updateCalendarStatus()
            scheduler.updateNextScheduledTimeString()
        }
    }

    private var isCalendarGranted: Bool {
        if #available(macOS 14.0, *) {
            if calendarStatus == .fullAccess { return true }
        }
        return calendarStatus == .authorized
    }

    private var calendarStatusText: String {
        if #available(macOS 14.0, *) {
            if calendarStatus == .fullAccess {
                return "Permission granted. Reading today's scheduled events."
            } else if calendarStatus == .writeOnly {
                return "Write-only permission granted. Reading schedule requires full access."
            }
        }
        switch calendarStatus {
        case .authorized:
            return "Permission granted. Reading today's scheduled events."
        case .denied:
            return "Access denied in macOS System Settings -> Privacy -> Calendars."
        case .restricted:
            return "Restricted by parental or system profile."
        case .notDetermined:
            return "Permission not requested yet."
        default:
            return "Permission status unavailable."
        }
    }

    private func updateCalendarStatus() {
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
    }
}
