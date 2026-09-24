import Foundation
import SwiftUI
import AppKit

struct PetStageView: View {
    @ObservedObject var petState = PetState.shared
    @ObservedObject var sysMon = SystemMonitor.shared

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
                .frame(width: 340, height: 620)
            } else {
                // Closed state: exactly 140x140
                petStageArea
                    .frame(width: 140, height: 140)
            }
        }
        .frame(
            width: petState.isChatOpen ? 340 : 140,
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
                // Background Glow Ring
                Circle()
                    .fill(petState.currentSpecies.accentColor.opacity(petState.isThinking ? 0.35 : 0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: petState.isThinking ? 12 : 8)

                // SVG Character Graphic
                PetSVGView(
                    species: petState.currentSpecies,
                    state: petState.animState,
                    animTime: petState.animTime
                )
                .frame(width: 100, height: 100)

                // Mood Indicator & Cycle Button
                VStack {
                    HStack {
                        Button(action: {
                            petState.cycleMood()
                        }) {
                            Text(petState.currentSpecies.moodEmoji(for: petState.currentMood))
                                .font(.system(size: 16))
                                .padding(3)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Status Dot
                        Circle()
                            .fill(petState.isThinking ? Color.orange : (OllamaClient.shared.isOnline ? Color.green : Color.red))
                            .frame(width: 7, height: 7)
                    }
                    Spacer()
                }
                .frame(width: 110, height: 110)

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

                // CPU Load Mini Bar
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                            Capsule()
                                .fill(sysMon.cpuPercent > 70 ? Color.red : (sysMon.cpuPercent > 40 ? Color.orange : Color.green))
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
        .frame(width: petState.isChatOpen ? 340 : 140, height: 140)
    }
}
