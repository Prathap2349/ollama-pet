import Foundation
import SwiftUI
import AppKit

public struct PetSVGProvider {
    public static func svgString(for species: PetSpecies, state: PetAnimState, t: Double = 0.0) -> String {
        switch species {
        case .cat:
            return catSvg(state: state, t: t)
        case .dragon:
            return dragonSvg(state: state, t: t)
        case .robot:
            return robotSvg(state: state, t: t)
        case .robotcat:
            return robotcatSvg(state: state, t: t)
        case .ghost:
            return ghostSvg(state: state, t: t)
        case .fox:
            return foxSvg(state: state, t: t)
        case .bunny:
            return bunnySvg(state: state, t: t)
        }
    }

    public static func walkSvg(for species: PetSpecies) -> String {
        let inner: String
        switch species {
        case .cat:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(139,92,246,0.15)"/>
            <ellipse cx="30" cy="38" rx="14" ry="12" fill="#c4b5fd"/>
            <circle cx="30" cy="24" r="13" fill="#ddd6fe"/>
            <polygon points="18,14 13,4 23,13" fill="#c4b5fd"/>
            <polygon points="42,14 47,4 37,13" fill="#c4b5fd"/>
            <ellipse cx="24" cy="23" rx="4" ry="5" fill="#1e1b4b"/>
            <ellipse cx="36" cy="23" rx="4" ry="5" fill="#1e1b4b"/>
            <circle cx="25" cy="22" r="1.5" fill="white"/>
            <circle cx="37" cy="22" r="1.5" fill="white"/>
            <ellipse cx="30" cy="29" rx="2.5" ry="2" fill="#f9a8d4"/>
            <path d="M27,31 Q30,34 33,31" stroke="#9333ea" stroke-width="1.2" fill="none"/>
            <ellipse cx="30" cy="47" rx="10" ry="8" fill="#c4b5fd"/>
            """
        case .dragon:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(249,115,22,0.15)"/>
            <path d="M10,28 Q6,20 12,30 Q8,22 14,28" fill="#b45309" opacity="0.8"/>
            <path d="M50,28 Q54,20 48,30 Q52,22 46,28" fill="#b45309" opacity="0.8"/>
            <ellipse cx="30" cy="36" rx="14" ry="11" fill="#f97316"/>
            <ellipse cx="30" cy="36" rx="9" ry="7" fill="#fed7aa"/>
            <circle cx="30" cy="24" r="13" fill="#f97316"/>
            <ellipse cx="30" cy="30" rx="6" ry="4" fill="#ea580c"/>
            <ellipse cx="22" cy="21" rx="5" ry="6" fill="#1c1917"/>
            <ellipse cx="38" cy="21" rx="5" ry="6" fill="#1c1917"/>
            <ellipse cx="22" cy="21" rx="3" ry="4" fill="#fbbf24"/>
            <ellipse cx="38" cy="21" rx="3" ry="4" fill="#fbbf24"/>
            <path d="M23,14 Q20,8 22,4" stroke="#b45309" stroke-width="3" fill="none" stroke-linecap="round"/>
            <path d="M37,14 Q40,8 38,4" stroke="#b45309" stroke-width="3" fill="none" stroke-linecap="round"/>
            """
        case .robot:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(6,182,212,0.15)"/>
            <line x1="30" y1="6" x2="30" y2="14" stroke="#94a3b8" stroke-width="2"/>
            <circle cx="30" cy="4" r="4" fill="#06b6d4"/>
            <rect x="14" y="14" width="32" height="22" rx="5" fill="#1e293b"/>
            <rect x="16" y="16" width="28" height="18" rx="4" fill="#0f172a"/>
            <rect x="19" y="20" width="10" height="8" rx="2" fill="#06b6d4"/>
            <rect x="31" y="20" width="10" height="8" rx="2" fill="#06b6d4"/>
            <rect x="21" y="30" width="18" height="4" rx="2" fill="#0f172a"/>
            <rect x="23" y="31" width="5" height="2" rx="1" fill="#06b6d4"/>
            <rect x="12" y="19" width="4" height="9" rx="2" fill="#1e293b"/>
            <rect x="44" y="19" width="4" height="9" rx="2" fill="#1e293b"/>
            <rect x="16" y="38" width="28" height="20" rx="5" fill="#1e293b"/>
            """
        case .robotcat:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(16,185,129,0.15)"/>
            <line x1="30" y1="6" x2="30" y2="14" stroke="#6ee7b7" stroke-width="2"/>
            <circle cx="30" cy="4" r="3" fill="#10b981"/>
            <polygon points="17,18 13,6 23,16" fill="#1e293b"/>
            <polygon points="43,18 47,6 37,16" fill="#1e293b"/>
            <rect x="15" y="16" width="30" height="22" rx="7" fill="#1e293b"/>
            <rect x="17" y="18" width="26" height="18" rx="6" fill="#0f172a"/>
            <ellipse cx="23" cy="26" rx="4" ry="5" fill="#10b981"/>
            <ellipse cx="37" cy="26" rx="4" ry="5" fill="#10b981"/>
            <ellipse cx="23" cy="26" rx="1.5" ry="3.5" fill="#022c22"/>
            <ellipse cx="37" cy="26" rx="1.5" ry="3.5" fill="#022c22"/>
            <rect x="27" y="33" width="6" height="3" rx="1.5" fill="#10b981"/>
            <rect x="15" y="40" width="30" height="20" rx="5" fill="#1e293b"/>
            """
        case .ghost:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(148,163,184,0.08)"/>
            <ellipse cx="30" cy="26" rx="16" ry="18" fill="rgba(226,232,240,0.88)"/>
            <path d="M14,30 Q14,48 18,50 Q22,52 22,48 Q22,52 26,50 Q30,52 30,48 Q30,52 34,50 Q38,52 38,48 Q38,52 42,50 Q46,48 46,30" fill="rgba(226,232,240,0.88)"/>
            <ellipse cx="24" cy="24" rx="4" ry="5" fill="#1e1b4b"/>
            <ellipse cx="36" cy="24" rx="4" ry="5" fill="#1e1b4b"/>
            <circle cx="25" cy="23" r="1.5" fill="white"/>
            <circle cx="37" cy="23" r="1.5" fill="white"/>
            <ellipse cx="30" cy="34" rx="5" ry="3.5" fill="#475569" opacity="0.5"/>
            """
        case .fox:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(251,146,60,0.15)"/>
            <polygon points="18,20 12,4 24,18" fill="#fb923c"/>
            <polygon points="42,20 48,4 36,18" fill="#fb923c"/>
            <polygon points="19,19 14,8 24,18" fill="#f472b6" opacity="0.5"/>
            <polygon points="41,19 46,8 36,18" fill="#f472b6" opacity="0.5"/>
            <ellipse cx="30" cy="34" rx="13" ry="11" fill="#fb923c"/>
            <ellipse cx="30" cy="37" rx="8" ry="7" fill="#fde8d0"/>
            <circle cx="30" cy="22" r="12" fill="#fb923c"/>
            <ellipse cx="30" cy="28" rx="9" ry="7" fill="#fde8d0"/>
            <ellipse cx="24" cy="20" rx="3.5" ry="4.5" fill="#1c1917"/>
            <ellipse cx="36" cy="20" rx="3.5" ry="4.5" fill="#1c1917"/>
            <ellipse cx="24" cy="20" rx="1.5" ry="3" fill="#fbbf24"/>
            <ellipse cx="36" cy="20" rx="1.5" ry="3" fill="#fbbf24"/>
            <ellipse cx="30" cy="28" rx="2.5" ry="2" fill="#1c1917"/>
            """
        case .bunny:
            inner = """
            <circle cx="30" cy="30" r="28" fill="rgba(244,114,182,0.12)"/>
            <ellipse cx="22" cy="10" rx="5" ry="10" fill="#fbcfe8"/>
            <ellipse cx="38" cy="10" rx="5" ry="10" fill="#fbcfe8"/>
            <ellipse cx="22" cy="10" rx="2.5" ry="7" fill="#f9a8d4"/>
            <ellipse cx="38" cy="10" rx="2.5" ry="7" fill="#f9a8d4"/>
            <ellipse cx="30" cy="34" rx="14" ry="12" fill="#fbcfe8"/>
            <circle cx="30" cy="22" r="13" fill="#fce7f3"/>
            <ellipse cx="23" cy="22" rx="4" ry="5" fill="#1e1b4b"/>
            <ellipse cx="37" cy="22" rx="4" ry="5" fill="#1e1b4b"/>
            <circle cx="24" cy="21" r="1.5" fill="white"/>
            <circle cx="38" cy="21" r="1.5" fill="white"/>
            <ellipse cx="30" cy="30" rx="3" ry="2" fill="#f9a8d4"/>
            """
        }
        return wrapSvg(inner, width: 60, height: 60)
    }

    private static func wrapSvg(_ content: String, width: Int = 160, height: Int = 160) -> String {
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) \(height)" width="\(width)" height="\(height)">
        \(content)
        </svg>
        """
    }

    // MARK: - Cat
    private static func catSvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle:
            let tailWiggle = sin(t * 3.0) * 5.0
            return wrapSvg("""
            <defs><radialGradient id="bg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#2d1b69"/><stop offset="100%" stop-color="#0f0a1e"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bg)" opacity="0.45"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#c4b5fd"/>
            <circle cx="80" cy="68" r="32" fill="#ddd6fe"/>
            <polygon points="52,42 44,18 68,38" fill="#c4b5fd"/>
            <polygon points="108,42 116,18 92,38" fill="#c4b5fd"/>
            <polygon points="54,40 49,24 66,38" fill="#f9a8d4"/>
            <polygon points="106,40 111,24 94,38" fill="#f9a8d4"/>
            <ellipse cx="66" cy="66" rx="7" ry="8" fill="#1e1b4b"/>
            <ellipse cx="94" cy="66" rx="7" ry="8" fill="#1e1b4b"/>
            <circle cx="68" cy="64" r="2.5" fill="white"/>
            <circle cx="96" cy="64" r="2.5" fill="white"/>
            <ellipse cx="80" cy="77" rx="4" ry="3" fill="#f9a8d4"/>
            <path d="M76,80 Q80,85 84,80" stroke="#9333ea" stroke-width="1.5" fill="none" stroke-linecap="round"/>
            <line x1="50" y1="75" x2="72" y2="77" stroke="#7c3aed" stroke-width="1" opacity="0.5"/>
            <line x1="50" y1="80" x2="72" y2="79" stroke="#7c3aed" stroke-width="1" opacity="0.5"/>
            <line x1="88" y1="77" x2="110" y2="75" stroke="#7c3aed" stroke-width="1" opacity="0.5"/>
            <line x1="88" y1="79" x2="110" y2="80" stroke="#7c3aed" stroke-width="1" opacity="0.5"/>
            <path d="M44,128 Q\(22.0 + tailWiggle),110 \(30.0 + tailWiggle * 0.5),92 Q38,78 48,96" stroke="#c4b5fd" stroke-width="7" fill="none" stroke-linecap="round"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <ellipse cx="58" cy="73" rx="7" ry="4" fill="#f9a8d4" opacity="0.45"/>
            <ellipse cx="102" cy="73" rx="7" ry="4" fill="#f9a8d4" opacity="0.45"/>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="bg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#2d1b69"/><stop offset="100%" stop-color="#0f0a1e"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bg)" opacity="0.45"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#c4b5fd"/>
            <circle cx="80" cy="68" r="32" fill="#ddd6fe"/>
            <polygon points="52,42 44,18 68,38" fill="#c4b5fd"/>
            <polygon points="108,42 116,18 92,38" fill="#c4b5fd"/>
            <path d="M58,66 Q66,59 74,66" stroke="#1e1b4b" stroke-width="3" fill="none"/>
            <path d="M86,66 Q94,59 102,66" stroke="#1e1b4b" stroke-width="3" fill="none"/>
            <ellipse cx="80" cy="77" rx="4" ry="3" fill="#f9a8d4"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <circle cx="100" cy="42" r="3" fill="#a78bfa"/>
            <circle cx="110" cy="33" r="4" fill="#a78bfa"/>
            <circle cx="122" cy="22" r="5" fill="#a78bfa"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="bg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#1a0f3d"/><stop offset="100%" stop-color="#050310"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bg)" opacity="0.6"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#9d7de8"/>
            <circle cx="80" cy="68" r="32" fill="#c4b5fd"/>
            <polygon points="52,42 44,18 68,38" fill="#9d7de8"/>
            <polygon points="108,42 116,18 92,38" fill="#9d7de8"/>
            <path d="M58,68 Q66,68 74,68" stroke="#1e1b4b" stroke-width="3" fill="none"/>
            <path d="M86,68 Q94,68 102,68" stroke="#1e1b4b" stroke-width="3" fill="none"/>
            <ellipse cx="80" cy="77" rx="4" ry="3" fill="#f9a8d4"/>
            <path d="M76,82 Q80,85 84,82" stroke="#9333ea" stroke-width="1.5" fill="none"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#9d7de8"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#9d7de8"/>
            <text x="105" y="45" fill="#c4b5fd" font-size="14">z</text>
            <text x="115" y="32" fill="#c4b5fd" font-size="18">z</text>
            <text x="128" y="18" fill="#c4b5fd" font-size="22">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="bg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#2d1b69"/><stop offset="100%" stop-color="#0f0a1e"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bg)" opacity="0.45"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#c4b5fd"/>
            <circle cx="80" cy="68" r="32" fill="#ddd6fe"/>
            <polygon points="52,42 44,18 68,38" fill="#c4b5fd"/>
            <polygon points="108,42 116,18 92,38" fill="#c4b5fd"/>
            <ellipse cx="66" cy="64" rx="11" ry="12" fill="#1e1b4b"/>
            <ellipse cx="94" cy="64" rx="11" ry="12" fill="#1e1b4b"/>
            <circle cx="68" cy="62" r="4" fill="white"/>
            <circle cx="96" cy="62" r="4" fill="white"/>
            <ellipse cx="80" cy="84" rx="6" ry="5" fill="#1e1b4b"/>
            <text x="42" y="50" fill="#f59e0b" font-size="20" font-weight="bold">!</text>
            <text x="110" y="50" fill="#f59e0b" font-size="20" font-weight="bold">!</text>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            """)
        case .dance:
            let bounce = sin(t * 6.0) * 6.0
            return wrapSvg("""
            <defs><radialGradient id="bg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#2d1b69"/><stop offset="100%" stop-color="#0f0a1e"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bg)" opacity="0.45"/>
            <g transform="translate(0, \(bounce))">
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#c4b5fd"/>
            <circle cx="80" cy="68" r="32" fill="#ddd6fe"/>
            <polygon points="52,42 44,18 68,38" fill="#c4b5fd"/>
            <polygon points="108,42 116,18 92,38" fill="#c4b5fd"/>
            <ellipse cx="66" cy="66" rx="7" ry="9" fill="#1e1b4b"/>
            <ellipse cx="94" cy="66" rx="7" ry="9" fill="#1e1b4b"/>
            <circle cx="68" cy="63" r="2.5" fill="white"/>
            <circle cx="96" cy="63" r="2.5" fill="white"/>
            <ellipse cx="80" cy="77" rx="4" ry="3" fill="#f9a8d4"/>
            <path d="M74,80 Q80,87 86,80" stroke="#9333ea" stroke-width="2" fill="none"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#c4b5fd"/>
            <ellipse cx="58" cy="73" rx="7" ry="4" fill="#f9a8d4" opacity="0.6"/>
            <ellipse cx="102" cy="73" rx="7" ry="4" fill="#f9a8d4" opacity="0.6"/>
            </g>
            <text x="28" y="30" font-size="18">♪</text>
            <text x="110" y="40" font-size="14">♫</text>
            """)
        }
    }

    // MARK: - Dragon
    private static func dragonSvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle:
            return wrapSvg("""
            <defs><radialGradient id="dg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431407"/><stop offset="100%" stop-color="#0c0a09"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#dg)" opacity="0.5"/>
            <path d="M48,80 Q10,50 18,100 Q28,90 48,95" fill="#b45309" opacity="0.8"/>
            <path d="M112,80 Q150,50 142,100 Q132,90 112,95" fill="#b45309" opacity="0.8"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#f97316"/>
            <ellipse cx="80" cy="113" rx="22" ry="18" fill="#fed7aa"/>
            <circle cx="80" cy="66" r="30" fill="#f97316"/>
            <ellipse cx="80" cy="80" rx="14" ry="9" fill="#ea580c"/>
            <ellipse cx="73" cy="78" rx="3.5" ry="2.5" fill="#7c2d12"/>
            <ellipse cx="87" cy="78" rx="3.5" ry="2.5" fill="#7c2d12"/>
            <ellipse cx="64" cy="59" rx="8" ry="9" fill="#1c1917"/>
            <ellipse cx="96" cy="59" rx="8" ry="9" fill="#1c1917"/>
            <ellipse cx="64" cy="59" rx="4" ry="6" fill="#fbbf24"/>
            <ellipse cx="96" cy="59" rx="4" ry="6" fill="#fbbf24"/>
            <path d="M62,38 Q56,18 60,10" stroke="#b45309" stroke-width="4" fill="none" stroke-linecap="round"/>
            <path d="M98,38 Q104,18 100,10" stroke="#b45309" stroke-width="4" fill="none" stroke-linecap="round"/>
            <ellipse cx="80" cy="92" rx="5" ry="3.5" fill="#fbbf24" opacity="0.7"/>
            <path d="M44,130 Q22,118 28,100" stroke="#f97316" stroke-width="7" fill="none" stroke-linecap="round"/>
            <polygon points="22,97 32,106 26,112" fill="#b45309"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#f97316"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#f97316"/>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="dg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431407"/><stop offset="100%" stop-color="#0c0a09"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#dg)" opacity="0.5"/>
            <path d="M48,80 Q10,50 18,100 Q28,90 48,95" fill="#b45309" opacity="0.8"/>
            <path d="M112,80 Q150,50 142,100 Q132,90 112,95" fill="#b45309" opacity="0.8"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#f97316"/>
            <circle cx="80" cy="66" r="30" fill="#f97316"/>
            <path d="M56,59 Q64,52 72,59" stroke="#fbbf24" stroke-width="3" fill="none"/>
            <path d="M88,59 Q96,52 104,59" stroke="#fbbf24" stroke-width="3" fill="none"/>
            <ellipse cx="80" cy="80" rx="14" ry="9" fill="#ea580c"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#f97316"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#f97316"/>
            <circle cx="108" cy="44" r="3" fill="#fbbf24"/>
            <circle cx="118" cy="34" r="4" fill="#fbbf24"/>
            <circle cx="130" cy="22" r="5" fill="#fbbf24"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="dg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431407"/><stop offset="100%" stop-color="#0c0a09"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#dg)" opacity="0.65"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#c2671a"/>
            <circle cx="80" cy="66" r="30" fill="#dc8a3f"/>
            <path d="M56,62 Q64,62 72,62" stroke="#1c1917" stroke-width="3" fill="none"/>
            <path d="M88,62 Q96,62 104,62" stroke="#1c1917" stroke-width="3" fill="none"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#c2671a"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#c2671a"/>
            <text x="105" y="45" fill="#fbbf24" font-size="14">z</text>
            <text x="116" y="31" fill="#fbbf24" font-size="18">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="dg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431407"/><stop offset="100%" stop-color="#0c0a09"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#dg)" opacity="0.5"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#f97316"/>
            <circle cx="80" cy="66" r="30" fill="#f97316"/>
            <ellipse cx="64" cy="59" rx="11" ry="12" fill="#1c1917"/>
            <ellipse cx="96" cy="59" rx="11" ry="12" fill="#1c1917"/>
            <ellipse cx="64" cy="59" rx="7" ry="9" fill="#fbbf24"/>
            <ellipse cx="96" cy="59" rx="7" ry="9" fill="#fbbf24"/>
            <ellipse cx="80" cy="80" rx="14" ry="9" fill="#ea580c"/>
            <ellipse cx="80" cy="84" rx="7" ry="6" fill="#1c1917"/>
            <text x="38" y="48" fill="#ef4444" font-size="22" font-weight="bold">!</text>
            <text x="108" y="48" fill="#ef4444" font-size="22" font-weight="bold">!</text>
            """)
        case .dance:
            let bounce = sin(t * 6.0) * 8.0
            return wrapSvg("""
            <defs><radialGradient id="dg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431407"/><stop offset="100%" stop-color="#0c0a09"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#dg)" opacity="0.5"/>
            <g transform="translate(0, \(bounce))">
            <path d="M48,80 Q10,50 18,100 Q28,90 48,95" fill="#b45309" opacity="0.8"/>
            <path d="M112,80 Q150,50 142,100 Q132,90 112,95" fill="#b45309" opacity="0.8"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#f97316"/>
            <ellipse cx="80" cy="113" rx="22" ry="18" fill="#fed7aa"/>
            <circle cx="80" cy="66" r="30" fill="#f97316"/>
            <ellipse cx="64" cy="59" rx="8" ry="9" fill="#1c1917"/>
            <ellipse cx="96" cy="59" rx="8" ry="9" fill="#1c1917"/>
            <ellipse cx="64" cy="59" rx="4" ry="6" fill="#fbbf24"/>
            <ellipse cx="96" cy="59" rx="4" ry="6" fill="#fbbf24"/>
            <ellipse cx="80" cy="92" rx="6" ry="4" fill="#fbbf24" opacity="0.9"/>
            <ellipse cx="58" cy="132" rx="13" ry="9" fill="#f97316"/>
            <ellipse cx="102" cy="132" rx="13" ry="9" fill="#f97316"/>
            </g>
            <text x="22" y="30" font-size="20">🔥</text>
            <text x="110" y="42" font-size="16">✨</text>
            """)
        }
    }

    // MARK: - Robot
    private static func robotSvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle:
            return wrapSvg("""
            <defs><radialGradient id="rg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0c1a2e"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#rg)" opacity="0.5"/>
            <line x1="80" y1="26" x2="80" y2="40" stroke="#94a3b8" stroke-width="3"/>
            <circle cx="80" cy="22" r="6" fill="#06b6d4"/>
            <rect x="46" y="38" width="68" height="58" rx="12" fill="#1e293b"/>
            <rect x="50" y="42" width="60" height="50" rx="10" fill="#0f172a"/>
            <rect x="58" y="54" width="16" height="12" rx="3" fill="#06b6d4"/>
            <rect x="86" y="54" width="16" height="12" rx="3" fill="#06b6d4"/>
            <rect x="64" y="58" width="4" height="4" rx="2" fill="white"/>
            <rect x="92" y="58" width="4" height="4" rx="2" fill="white"/>
            <rect x="60" y="76" width="40" height="8" rx="4" fill="#0f172a"/>
            <rect x="62" y="78" width="8" height="4" rx="2" fill="#06b6d4"/>
            <rect x="74" y="78" width="6" height="4" rx="2" fill="#06b6d4"/>
            <rect x="84" y="78" width="10" height="4" rx="2" fill="#06b6d4"/>
            <rect x="36" y="52" width="10" height="20" rx="4" fill="#1e293b"/>
            <rect x="114" y="52" width="10" height="20" rx="4" fill="#1e293b"/>
            <rect x="52" y="98" width="56" height="44" rx="10" fill="#1e293b"/>
            <rect x="58" y="104" width="44" height="32" rx="6" fill="#0f172a"/>
            <line x1="66" y1="114" x2="94" y2="114" stroke="#06b6d4" stroke-width="1.5" opacity="0.5"/>
            <line x1="66" y1="120" x2="88" y2="120" stroke="#06b6d4" stroke-width="1.5" opacity="0.3"/>
            <rect x="32" y="100" width="18" height="36" rx="8" fill="#1e293b"/>
            <rect x="110" y="100" width="18" height="36" rx="8" fill="#1e293b"/>
            <circle cx="41" cy="138" r="8" fill="#0f172a"/>
            <circle cx="119" cy="138" r="8" fill="#0f172a"/>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="rg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0c1a2e"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#rg)" opacity="0.5"/>
            <line x1="80" y1="26" x2="80" y2="40" stroke="#94a3b8" stroke-width="3"/>
            <circle cx="80" cy="22" r="8" fill="#f59e0b"/>
            <rect x="46" y="38" width="68" height="58" rx="12" fill="#1e293b"/>
            <rect x="50" y="42" width="60" height="50" rx="10" fill="#0f172a"/>
            <rect x="58" y="54" width="16" height="12" rx="3" fill="#f59e0b"/>
            <rect x="86" y="54" width="16" height="12" rx="3" fill="#f59e0b"/>
            <rect x="60" y="76" width="40" height="8" rx="4" fill="#0f172a"/>
            <rect x="62" y="78" width="14" height="4" rx="2" fill="#f59e0b"/>
            <rect x="36" y="52" width="10" height="20" rx="4" fill="#1e293b"/>
            <rect x="114" y="52" width="10" height="20" rx="4" fill="#1e293b"/>
            <rect x="52" y="98" width="56" height="44" rx="10" fill="#1e293b"/>
            <circle cx="108" cy="42" r="3" fill="#f59e0b"/>
            <circle cx="118" cy="32" r="4" fill="#f59e0b"/>
            <circle cx="130" cy="20" r="5" fill="#f59e0b"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="rg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0c1a2e"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#rg)" opacity="0.65"/>
            <rect x="46" y="38" width="68" height="58" rx="12" fill="#111e2e"/>
            <rect x="50" y="42" width="60" height="50" rx="10" fill="#07111c"/>
            <rect x="58" y="54" width="16" height="12" rx="3" fill="#0c2030" opacity="0.5"/>
            <rect x="86" y="54" width="16" height="12" rx="3" fill="#0c2030" opacity="0.5"/>
            <rect x="60" y="76" width="40" height="8" rx="4" fill="#07111c"/>
            <rect x="52" y="98" width="56" height="44" rx="10" fill="#111e2e"/>
            <text x="105" y="45" fill="#06b6d4" font-size="14">z</text>
            <text x="116" y="31" fill="#06b6d4" font-size="18">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="rg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0c1a2e"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#rg)" opacity="0.5"/>
            <rect x="46" y="38" width="68" height="58" rx="12" fill="#1e293b"/>
            <rect x="50" y="42" width="60" height="50" rx="10" fill="#0f172a"/>
            <rect x="58" y="52" width="18" height="16" rx="3" fill="#ef4444"/>
            <rect x="84" y="52" width="18" height="16" rx="3" fill="#ef4444"/>
            <rect x="63" y="56" width="8" height="8" rx="4" fill="white"/>
            <rect x="89" y="56" width="8" height="8" rx="4" fill="white"/>
            <rect x="60" y="76" width="40" height="8" rx="4" fill="#0f172a"/>
            <rect x="62" y="78" width="36" height="4" rx="2" fill="#ef4444"/>
            <text x="36" y="44" fill="#f59e0b" font-size="22" font-weight="bold">!</text>
            <text x="108" y="44" fill="#f59e0b" font-size="22" font-weight="bold">!</text>
            """)
        case .dance:
            let bounce = sin(t * 6.0) * 6.0
            return wrapSvg("""
            <defs><radialGradient id="rg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0c1a2e"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#rg)" opacity="0.5"/>
            <g transform="translate(0, \(bounce))">
            <line x1="80" y1="26" x2="80" y2="40" stroke="#94a3b8" stroke-width="3"/>
            <circle cx="80" cy="22" r="6" fill="#06b6d4"/>
            <rect x="46" y="38" width="68" height="58" rx="12" fill="#1e293b"/>
            <rect x="50" y="42" width="60" height="50" rx="10" fill="#0f172a"/>
            <rect x="58" y="54" width="16" height="12" rx="3" fill="#06b6d4"/>
            <rect x="86" y="54" width="16" height="12" rx="3" fill="#06b6d4"/>
            <rect x="60" y="76" width="40" height="8" rx="4" fill="#0f172a"/>
            <rect x="62" y="78" width="36" height="4" rx="2" fill="#06b6d4"/>
            <rect x="52" y="98" width="56" height="44" rx="10" fill="#1e293b"/>
            <rect x="32" y="100" width="18" height="36" rx="8" fill="#1e293b"/>
            <rect x="110" y="100" width="18" height="36" rx="8" fill="#1e293b"/>
            </g>
            <text x="22" y="32" font-size="18">⚡</text>
            <text x="112" y="40" font-size="16">💫</text>
            """)
        }
    }

    // MARK: - RobotCat (NEO)
    private static func robotcatSvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle, .dance:
            let bounce = state == .dance ? sin(t * 6.0) * 6.0 : 0.0
            return wrapSvg("""
            <defs><radialGradient id="ng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#064e3b"/><stop offset="100%" stop-color="#020c07"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#ng)" opacity="0.5"/>
            <g transform="translate(0, \(bounce))">
            <line x1="80" y1="16" x2="80" y2="34" stroke="#6ee7b7" stroke-width="2.5"/>
            <circle cx="80" cy="12" r="5" fill="#10b981"/>
            <polygon points="52,44 44,20 68,40" fill="#1e293b"/>
            <polygon points="108,44 116,20 92,40" fill="#1e293b"/>
            <polygon points="54,42 50,26 66,40" fill="#10b981" opacity="0.35"/>
            <polygon points="106,42 110,26 94,40" fill="#10b981" opacity="0.35"/>
            <rect x="46" y="38" width="68" height="52" rx="16" fill="#1e293b"/>
            <rect x="50" y="42" width="60" height="44" rx="12" fill="#0f172a"/>
            <ellipse cx="66" cy="62" rx="7" ry="8" fill="#10b981"/>
            <ellipse cx="94" cy="62" rx="7" ry="8" fill="#10b981"/>
            <ellipse cx="66" cy="62" rx="2.5" ry="5" fill="#022c22"/>
            <ellipse cx="94" cy="62" rx="2.5" ry="5" fill="#022c22"/>
            <circle cx="69" cy="58" r="2" fill="white"/>
            <circle cx="97" cy="58" r="2" fill="white"/>
            <rect x="77" y="75" width="6" height="4" rx="2" fill="#10b981"/>
            <path d="M74,82 Q80,88 86,82" stroke="#10b981" stroke-width="1.5" fill="none" stroke-linecap="round"/>
            <rect x="52" y="92" width="56" height="46" rx="12" fill="#1e293b"/>
            <rect x="58" y="98" width="44" height="34" rx="8" fill="#0f172a"/>
            </g>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="ng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#064e3b"/><stop offset="100%" stop-color="#020c07"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#ng)" opacity="0.5"/>
            <rect x="46" y="38" width="68" height="52" rx="16" fill="#1e293b"/>
            <rect x="50" y="42" width="60" height="44" rx="12" fill="#0f172a"/>
            <path d="M58,62 Q66,54 74,62" stroke="#10b981" stroke-width="3" fill="none"/>
            <path d="M86,62 Q94,54 102,62" stroke="#10b981" stroke-width="3" fill="none"/>
            <circle cx="108" cy="42" r="3" fill="#10b981"/>
            <circle cx="118" cy="32" r="4" fill="#10b981"/>
            <circle cx="130" cy="20" r="5" fill="#10b981"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="ng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#064e3b"/><stop offset="100%" stop-color="#020c07"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#ng)" opacity="0.65"/>
            <rect x="46" y="38" width="68" height="52" rx="16" fill="#1e293b"/>
            <path d="M58,64 Q66,64 74,64" stroke="#10b981" stroke-width="3" fill="none"/>
            <path d="M86,64 Q94,64 102,64" stroke="#10b981" stroke-width="3" fill="none"/>
            <text x="105" y="45" fill="#10b981" font-size="14">z</text>
            <text x="116" y="31" fill="#10b981" font-size="18">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="ng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#064e3b"/><stop offset="100%" stop-color="#020c07"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#ng)" opacity="0.5"/>
            <rect x="46" y="38" width="68" height="52" rx="16" fill="#1e293b"/>
            <ellipse cx="66" cy="62" rx="11" ry="12" fill="#ef4444"/>
            <ellipse cx="94" cy="62" rx="11" ry="12" fill="#ef4444"/>
            <circle cx="68" cy="60" r="4" fill="white"/>
            <circle cx="96" cy="60" r="4" fill="white"/>
            <text x="38" y="48" fill="#f59e0b" font-size="20" font-weight="bold">!</text>
            <text x="108" y="48" fill="#f59e0b" font-size="20" font-weight="bold">!</text>
            """)
        }
    }

    // MARK: - Ghost
    private static func ghostSvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle:
            let floatY = sin(t * 1.5) * 6.0
            return wrapSvg("""
            <defs><radialGradient id="gg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0f172a"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#gg)" opacity="0.6"/>
            <ellipse cx="80" cy="\(72.0 + floatY)" rx="42" ry="46" fill="rgba(226,232,240,0.88)"/>
            <path d="M38,\(92.0 + floatY) Q38,\(120.0 + floatY) 46,\(122.0 + floatY) Q54,\(124.0 + floatY) 54,\(118.0 + floatY) Q54,\(124.0 + floatY) 62,\(122.0 + floatY) Q70,\(124.0 + floatY) 70,\(118.0 + floatY) Q70,\(124.0 + floatY) 80,\(122.0 + floatY) Q90,\(124.0 + floatY) 90,\(118.0 + floatY) Q90,\(124.0 + floatY) 98,\(122.0 + floatY) Q106,\(124.0 + floatY) 106,\(118.0 + floatY) Q106,\(124.0 + floatY) 114,\(122.0 + floatY) Q122,\(120.0 + floatY) 122,\(92.0 + floatY)" fill="rgba(226,232,240,0.88)"/>
            <ellipse cx="66" cy="\(64.0 + floatY)" rx="10" ry="12" fill="#1e293b"/>
            <ellipse cx="94" cy="\(64.0 + floatY)" rx="10" ry="12" fill="#1e293b"/>
            <circle cx="68" cy="\(61.0 + floatY)" r="4" fill="white"/>
            <circle cx="96" cy="\(61.0 + floatY)" r="4" fill="white"/>
            <ellipse cx="80" cy="\(78.0 + floatY)" rx="7" ry="5" fill="#475569" opacity="0.55"/>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="gg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0f172a"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#gg)" opacity="0.6"/>
            <ellipse cx="80" cy="72" rx="42" ry="46" fill="rgba(226,232,240,0.88)"/>
            <path d="M38,92 Q38,120 46,122 Q54,124 54,118 Q54,124 62,122 Q70,124 70,118 Q70,124 80,122 Q90,124 90,118 Q90,124 98,122 Q106,124 106,118 Q106,124 114,122 Q122,120 122,92" fill="rgba(226,232,240,0.88)"/>
            <path d="M56,64 Q66,56 76,64" stroke="#1e293b" stroke-width="3" fill="none"/>
            <path d="M84,64 Q94,56 104,64" stroke="#1e293b" stroke-width="3" fill="none"/>
            <ellipse cx="80" cy="78" rx="7" ry="5" fill="#475569" opacity="0.55"/>
            <circle cx="108" cy="42" r="3" fill="#bae6fd"/>
            <circle cx="118" cy="32" r="4" fill="#bae6fd"/>
            <circle cx="130" cy="20" r="5" fill="#bae6fd"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="gg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0f172a"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#gg)" opacity="0.7"/>
            <ellipse cx="80" cy="72" rx="42" ry="46" fill="rgba(200,210,230,0.7)"/>
            <path d="M38,92 Q38,120 46,122 Q54,124 54,118 Q54,124 62,122 Q70,124 70,118 Q70,124 80,122 Q90,124 90,118 Q90,124 98,122 Q106,124 106,118 Q106,124 114,122 Q122,120 122,92" fill="rgba(200,210,230,0.7)"/>
            <path d="M56,66 Q66,66 76,66" stroke="#475569" stroke-width="3" fill="none"/>
            <path d="M84,66 Q94,66 104,66" stroke="#475569" stroke-width="3" fill="none"/>
            <text x="105" y="45" fill="#bae6fd" font-size="14">z</text>
            <text x="116" y="31" fill="#bae6fd" font-size="18">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="gg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0f172a"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#gg)" opacity="0.6"/>
            <ellipse cx="80" cy="72" rx="42" ry="46" fill="rgba(226,232,240,0.88)"/>
            <ellipse cx="66" cy="62" rx="13" ry="14" fill="#1e293b"/>
            <ellipse cx="94" cy="62" rx="13" ry="14" fill="#1e293b"/>
            <circle cx="68" cy="60" r="5" fill="white"/>
            <circle cx="96" cy="60" r="5" fill="white"/>
            <ellipse cx="80" cy="80" rx="9" ry="8" fill="#1e293b"/>
            """)
        case .dance:
            let bounce = sin(t * 6.0) * 8.0
            return wrapSvg("""
            <defs><radialGradient id="gg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#0f172a"/><stop offset="100%" stop-color="#020617"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#gg)" opacity="0.6"/>
            <g transform="translate(0, \(bounce))">
            <ellipse cx="80" cy="72" rx="42" ry="46" fill="rgba(226,232,240,0.88)"/>
            <ellipse cx="66" cy="64" rx="10" ry="12" fill="#1e293b"/>
            <ellipse cx="94" cy="64" rx="10" ry="12" fill="#1e293b"/>
            <circle cx="68" cy="61" r="4" fill="white"/>
            <circle cx="96" cy="61" r="4" fill="white"/>
            <path d="M72,80 Q80,88 88,80" stroke="#475569" stroke-width="2" fill="none"/>
            </g>
            <text x="22" y="30" font-size="18">⭐</text>
            <text x="112" y="40" font-size="16">💫</text>
            """)
        }
    }

    // MARK: - Fox
    private static func foxSvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle:
            return wrapSvg("""
            <defs><radialGradient id="fg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431a07"/><stop offset="100%" stop-color="#0c0805"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#fg)" opacity="0.5"/>
            <path d="M48,96 Q16,80 28,56" stroke="#fb923c" stroke-width="10" fill="none" stroke-linecap="round"/>
            <path d="M48,96 Q16,80 28,56" stroke="#fde8d0" stroke-width="4" fill="none" stroke-linecap="round"/>
            <ellipse cx="80" cy="108" rx="32" ry="26" fill="#fb923c"/>
            <ellipse cx="80" cy="112" rx="19" ry="16" fill="#fde8d0"/>
            <polygon points="54,52 44,14 70,46" fill="#fb923c"/>
            <polygon points="106,52 116,14 90,46" fill="#fb923c"/>
            <circle cx="80" cy="66" r="28" fill="#fb923c"/>
            <ellipse cx="80" cy="76" rx="14" ry="11" fill="#fde8d0"/>
            <ellipse cx="66" cy="60" rx="7" ry="8" fill="#1c1917"/>
            <ellipse cx="94" cy="60" rx="7" ry="8" fill="#1c1917"/>
            <ellipse cx="66" cy="60" rx="3.5" ry="5.5" fill="#fbbf24"/>
            <ellipse cx="94" cy="60" rx="3.5" ry="5.5" fill="#fbbf24"/>
            <ellipse cx="67" cy="58" rx="1.5" ry="2" fill="white"/>
            <ellipse cx="95" cy="58" rx="1.5" ry="2" fill="white"/>
            <ellipse cx="80" cy="75" rx="3.5" ry="2.5" fill="#1c1917"/>
            <path d="M76,78 Q80,83 84,78" stroke="#c2500e" stroke-width="1.5" fill="none"/>
            <ellipse cx="60" cy="132" rx="12" ry="8" fill="#fb923c"/>
            <ellipse cx="100" cy="132" rx="12" ry="8" fill="#fb923c"/>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="fg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431a07"/><stop offset="100%" stop-color="#0c0805"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#fg)" opacity="0.5"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#fb923c"/>
            <circle cx="80" cy="66" r="30" fill="#fb923c"/>
            <path d="M57,58 Q65,51 73,58" stroke="#fbbf24" stroke-width="2.5" fill="none"/>
            <path d="M87,58 Q95,51 103,58" stroke="#fbbf24" stroke-width="2.5" fill="none"/>
            <ellipse cx="60" cy="132" rx="13" ry="9" fill="#fb923c"/>
            <ellipse cx="100" cy="132" rx="13" ry="9" fill="#fb923c"/>
            <circle cx="108" cy="44" r="3" fill="#fbbf24"/>
            <circle cx="118" cy="34" r="4" fill="#fbbf24"/>
            <circle cx="130" cy="22" r="5" fill="#fbbf24"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="fg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431a07"/><stop offset="100%" stop-color="#0c0805"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#fg)" opacity="0.65"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#c2500e"/>
            <circle cx="80" cy="66" r="30" fill="#de7a3a"/>
            <path d="M57,62 Q65,62 73,62" stroke="#1c1917" stroke-width="3" fill="none"/>
            <path d="M87,62 Q95,62 103,62" stroke="#1c1917" stroke-width="3" fill="none"/>
            <text x="105" y="45" fill="#fbbf24" font-size="14">z</text>
            <text x="116" y="31" fill="#fbbf24" font-size="18">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="fg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431a07"/><stop offset="100%" stop-color="#0c0805"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#fg)" opacity="0.5"/>
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#fb923c"/>
            <circle cx="80" cy="66" r="30" fill="#fb923c"/>
            <ellipse cx="66" cy="58" rx="11" ry="12" fill="#1c1917"/>
            <ellipse cx="94" cy="58" rx="11" ry="12" fill="#1c1917"/>
            <ellipse cx="66" cy="58" rx="6" ry="8" fill="#fbbf24"/>
            <ellipse cx="94" cy="58" rx="6" ry="8" fill="#fbbf24"/>
            <ellipse cx="80" cy="82" rx="7" ry="7" fill="#1c1917"/>
            <text x="40" y="46" fill="#ef4444" font-size="22" font-weight="bold">!</text>
            <text x="108" y="46" fill="#ef4444" font-size="22" font-weight="bold">!</text>
            """)
        case .dance:
            let bounce = sin(t * 6.0) * 8.0
            return wrapSvg("""
            <defs><radialGradient id="fg" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#431a07"/><stop offset="100%" stop-color="#0c0805"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#fg)" opacity="0.5"/>
            <g transform="translate(0, \(bounce))">
            <ellipse cx="80" cy="108" rx="34" ry="28" fill="#fb923c"/>
            <circle cx="80" cy="66" r="30" fill="#fb923c"/>
            <ellipse cx="66" cy="58" rx="8" ry="9" fill="#1c1917"/>
            <ellipse cx="94" cy="58" rx="8" ry="9" fill="#1c1917"/>
            <ellipse cx="66" cy="58" rx="4" ry="6" fill="#fbbf24"/>
            <ellipse cx="94" cy="58" rx="4" ry="6" fill="#fbbf24"/>
            <path d="M76,83 Q80,89 84,83" stroke="#c2500e" stroke-width="2" fill="none"/>
            <ellipse cx="60" cy="132" rx="13" ry="9" fill="#fb923c"/>
            <ellipse cx="100" cy="132" rx="13" ry="9" fill="#fb923c"/>
            </g>
            <text x="22" y="30" font-size="18">🔥</text>
            <text x="112" y="40" font-size="16">🍊</text>
            """)
        }
    }

    // MARK: - Bunny
    private static func bunnySvg(state: PetAnimState, t: Double) -> String {
        switch state {
        case .idle:
            return wrapSvg("""
            <defs><radialGradient id="bng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#500724"/><stop offset="100%" stop-color="#0f051a"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bng)" opacity="0.45"/>
            <ellipse cx="62" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="98" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="62" cy="20" rx="5" ry="16" fill="#f9a8d4"/>
            <ellipse cx="98" cy="20" rx="5" ry="16" fill="#f9a8d4"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#fbcfe8"/>
            <circle cx="80" cy="68" r="32" fill="#fce7f3"/>
            <ellipse cx="66" cy="66" rx="7" ry="8" fill="#1e1b4b"/>
            <ellipse cx="94" cy="66" rx="7" ry="8" fill="#1e1b4b"/>
            <circle cx="68" cy="64" r="2.5" fill="white"/>
            <circle cx="96" cy="64" r="2.5" fill="white"/>
            <ellipse cx="80" cy="77" rx="4" ry="3" fill="#f9a8d4"/>
            <path d="M76,80 Q80,85 84,80" stroke="#ec4899" stroke-width="1.5" fill="none"/>
            <ellipse cx="60" cy="132" rx="13" ry="9" fill="#fbcfe8"/>
            <ellipse cx="100" cy="132" rx="13" ry="9" fill="#fbcfe8"/>
            """)
        case .thinking:
            return wrapSvg("""
            <defs><radialGradient id="bng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#500724"/><stop offset="100%" stop-color="#0f051a"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bng)" opacity="0.45"/>
            <ellipse cx="62" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="98" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#fbcfe8"/>
            <circle cx="80" cy="68" r="32" fill="#fce7f3"/>
            <path d="M57,65 Q65,58 73,65" stroke="#1e1b4b" stroke-width="3" fill="none"/>
            <path d="M87,65 Q95,58 103,65" stroke="#1e1b4b" stroke-width="3" fill="none"/>
            <circle cx="108" cy="44" r="3" fill="#f9a8d4"/>
            <circle cx="118" cy="34" r="4" fill="#f9a8d4"/>
            <circle cx="130" cy="22" r="5" fill="#f9a8d4"/>
            """)
        case .sleep:
            return wrapSvg("""
            <defs><radialGradient id="bng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#500724"/><stop offset="100%" stop-color="#0f051a"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bng)" opacity="0.6"/>
            <ellipse cx="62" cy="20" rx="10" ry="22" fill="#f3a8cc"/>
            <ellipse cx="98" cy="20" rx="10" ry="22" fill="#f3a8cc"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#f3a8cc"/>
            <circle cx="80" cy="68" r="32" fill="#fad6ec"/>
            <path d="M57,68 Q65,68 73,68" stroke="#9d174d" stroke-width="3" fill="none"/>
            <path d="M87,68 Q95,68 103,68" stroke="#9d174d" stroke-width="3" fill="none"/>
            <text x="105" y="45" fill="#f9a8d4" font-size="14">z</text>
            <text x="116" y="31" fill="#f9a8d4" font-size="18">z</text>
            """)
        case .shock:
            return wrapSvg("""
            <defs><radialGradient id="bng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#500724"/><stop offset="100%" stop-color="#0f051a"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bng)" opacity="0.45"/>
            <ellipse cx="62" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="98" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#fbcfe8"/>
            <circle cx="80" cy="68" r="32" fill="#fce7f3"/>
            <ellipse cx="66" cy="64" rx="11" ry="12" fill="#1e1b4b"/>
            <ellipse cx="94" cy="64" rx="11" ry="12" fill="#1e1b4b"/>
            <circle cx="68" cy="62" r="4" fill="white"/>
            <circle cx="96" cy="62" r="4" fill="white"/>
            <ellipse cx="80" cy="82" rx="7" ry="6" fill="#1e1b4b"/>
            <text x="40" y="50" fill="#f59e0b" font-size="20" font-weight="bold">!</text>
            <text x="108" y="50" fill="#f59e0b" font-size="20" font-weight="bold">!</text>
            """)
        case .dance:
            let bounce = sin(t * 6.0) * 8.0
            return wrapSvg("""
            <defs><radialGradient id="bng" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#500724"/><stop offset="100%" stop-color="#0f051a"/></radialGradient></defs>
            <circle cx="80" cy="80" r="78" fill="url(#bng)" opacity="0.45"/>
            <g transform="translate(0, \(bounce))">
            <ellipse cx="62" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="98" cy="20" rx="10" ry="22" fill="#fbcfe8"/>
            <ellipse cx="80" cy="108" rx="36" ry="30" fill="#fbcfe8"/>
            <circle cx="80" cy="68" r="32" fill="#fce7f3"/>
            <ellipse cx="66" cy="66" rx="7" ry="9" fill="#1e1b4b"/>
            <ellipse cx="94" cy="66" rx="7" ry="9" fill="#1e1b4b"/>
            <circle cx="68" cy="63" r="2.5" fill="white"/>
            <circle cx="96" cy="63" r="2.5" fill="white"/>
            <ellipse cx="80" cy="77" rx="4" ry="3" fill="#f9a8d4"/>
            <path d="M74,80 Q80,87 86,80" stroke="#ec4899" stroke-width="2" fill="none"/>
            <ellipse cx="60" cy="132" rx="13" ry="9" fill="#fbcfe8"/>
            <ellipse cx="100" cy="132" rx="13" ry="9" fill="#fbcfe8"/>
            </g>
            <text x="28" y="30" font-size="18">🎀</text>
            <text x="110" y="40" font-size="14">💗</text>
            """)
        }
    }
}

public struct PetSVGView: View {
    public let species: PetSpecies
    public let state: PetAnimState
    public let animTime: Double

    public init(species: PetSpecies, state: PetAnimState, animTime: Double = 0.0) {
        self.species = species
        self.state = state
        self.animTime = animTime
    }

    public var body: some View {
        let svgStr = PetSVGProvider.svgString(for: species, state: state, t: animTime)
        if let data = svgStr.data(using: .utf8), let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Text(species.icon)
                .font(.system(size: 80))
        }
    }
}
