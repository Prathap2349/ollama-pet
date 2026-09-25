import Foundation
import SwiftUI
import AppKit

struct PetStageView: View {
    @ObservedObject var petState = PetState.shared
    @ObservedObject var sysMon = SystemMonitor.shared
    @ObservedObject var motion = CharacterMotionStateMachine.shared
    @ObservedObject var weatherService = WeatherService.shared
    @ObservedObject var perf = PerformanceManager.shared

    var body: some View {
        ZStack(alignment: petAlignment) {
            // Main Window Content container
            if petState.isChatOpen {
                VStack(spacing: 0) {
                    if petState.activeAnchor.isTop {
                        // Pet is at top: Stage on top, Panel below
                        petStageArea
                        ChatView()
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                    } else {
                        // Pet is at bottom: Panel on top, Stage at bottom
                        Spacer(minLength: 0)
                        ChatView()
                            .padding(.bottom, 4)
                        petStageArea
                    }
                }
                .frame(width: 360, height: 620)
            } else {
                // Closed state: exactly 140x140
                petStageArea
                    .frame(width: 140, height: 140)
            }
        }
        .frame(
            width: petState.isChatOpen ? 360 : 140,
            height: petState.isChatOpen ? 620 : 140
        )
    }

    private var petAlignment: Alignment {
        if !petState.isChatOpen {
            return .center
        }
        let horizontal: HorizontalAlignment = petState.activeAnchor.isLeft ? .leading : .trailing
        let vertical: VerticalAlignment = petState.activeAnchor.isTop ? .top : .bottom
        return Alignment(horizontal: horizontal, vertical: vertical)
    }

    private var petStageArea: some View {
        HStack(spacing: 0) {
            if !petState.activeAnchor.isLeft && petState.isChatOpen {
                Spacer(minLength: 0)
            }

            ZStack(alignment: .center) {
                // Celebration Glowing Ring / Pulse
                if petState.isCelebrationPulsing {
                    Circle()
                        .stroke(petState.celebrationPulseColor.opacity(0.85), lineWidth: 3.5)
                        .frame(width: 122, height: 122)
                        .shadow(color: petState.celebrationPulseColor, radius: 12, x: 0, y: 0)
                        .scaleEffect(1.0 + CGFloat(sin(petState.animTime * 6.0)) * 0.05)
                }

                // High-Framerate Procedural Physics Canvas with Adaptive Refresh Rate
                canvasView

                // Mood Indicator & Cycle Button
                VStack {
                    HStack {
                        Button(action: {
                            petState.cycleMood()
                        }) {
                            Text(petState.currentSpecies.moodEmoji(for: petState.currentMood))
                                .font(.system(size: 15))
                                .padding(4)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Status Dot with Glow (Online / Offline / Power Saving)
                        Circle()
                            .fill(
                                petState.isThinking ? Color.orange :
                                (sysMon.isPowerSavingMode ? Color.yellow :
                                (OllamaClient.shared.isOnline ? Color.green : Color.red))
                            )
                            .frame(width: 8, height: 8)
                            .shadow(color: (OllamaClient.shared.isOnline ? Color.green : Color.orange).opacity(0.8), radius: 3)
                    }
                    Spacer()
                }
                .frame(width: 116, height: 116)

                // Atmospheric Indicator (if raining/snowing/golden hour)
                if weatherService.activeAtmosphere != .clearDay {
                    VStack {
                        Spacer()
                        HStack {
                            Text(weatherAtmosphereIcon(weatherService.activeAtmosphere))
                                .font(.system(size: 11))
                                .padding(3)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                            Spacer()
                        }
                    }
                    .frame(width: 116, height: 116)
                }

                // Speech Bubble
                if petState.isBubbleVisible {
                    VStack {
                        Text(petState.bubbleText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 24/255, green: 24/255, blue: 37/255).opacity(0.95))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(petState.currentSpecies.accentColor.opacity(0.5), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                            )
                            .offset(y: -58)
                        Spacer()
                    }
                }

                // Dream Bubble (when sleeping)
                if petState.isDreamVisible {
                    VStack {
                        Text(petState.dreamText)
                            .font(.system(size: 14))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                            )
                            .offset(y: -58)
                        Spacer()
                    }
                }

                // CPU Load Thermal Mini Bar
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                            Capsule()
                                .fill(
                                    sysMon.cpuPercent > 70 ? Color.red :
                                    (sysMon.cpuPercent > 40 ? Color.orange : Color.green)
                                )
                                .frame(width: geo.size.width * CGFloat(min(1.0, sysMon.cpuPercent / 100.0)))
                        }
                    }
                    .frame(width: 44, height: 3)
                    .offset(y: 52)
                }
            }
            .frame(width: 140, height: 140)

            if petState.activeAnchor.isLeft && petState.isChatOpen {
                Spacer(minLength: 0)
            }
        }
        .frame(width: petState.isChatOpen ? 360 : 140, height: 140)
    }

    private var canvasView: some View {
        TimelineView(.animation(minimumInterval: perf.minimumRenderInterval)) { (timeline: TimelineViewDefaultContext) in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let snapshot = motion.evaluateSnapshot(
                    at: t,
                    animState: petState.animState,
                    mood: petState.currentMood,
                    atmosphere: perf.weatherEffectsEnabled ? weatherService.activeAtmosphere : .clearDay,
                    isSafeMode: perf.isSafeMode
                )
                let model = CharacterStructuralModel.model(for: petState.currentSpecies)

                PetCanvasRenderer.draw(
                    context: &context,
                    size: size,
                    species: petState.currentSpecies,
                    model: model,
                    animState: petState.animState,
                    mood: petState.currentMood,
                    snapshot: snapshot,
                    perf: perf
                )
            }
            .frame(width: 120, height: 120)
        }
    }

    private func weatherAtmosphereIcon(_ atmo: WeatherAtmosphere) -> String {
        switch atmo {
        case .rain: return "🌧"
        case .snow: return "❄️"
        case .goldenHour: return "🌅"
        case .nightClear: return "🌙"
        case .thunderstorm: return "⛈"
        case .fog: return "🌫"
        case .clearDay: return "☀️"
        }
    }
}
