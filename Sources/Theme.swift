import SwiftUI
import AppKit


// MARK: - Theme Mode Definition

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .light: return t("theme.light")
        case .dark: return t("theme.dark")
        case .system: return t("theme.system")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Design System (Lab98 Studio Dynamic Theme System)

enum Theme {

    private static func dynamicColor(lightHex: String, darkHex: String, alphaLight: CGFloat = 1.0, alphaDark: CGFloat = 1.0) -> Color {
        let lightColor = NSColor(hex: lightHex).withAlphaComponent(alphaLight)
        let darkColor = NSColor(hex: darkHex).withAlphaComponent(alphaDark)
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? darkColor : lightColor
        }))
    }

    // MARK: Accent (Lab98 Emerald)
    static let accent = dynamicColor(lightHex: "059669", darkHex: "3ECF8E")
    static let accentDeep = dynamicColor(lightHex: "047857", darkHex: "00B96B")
    static let accentSoft = dynamicColor(lightHex: "10B981", darkHex: "6EE7B7")
    static let accentGlow = dynamicColor(lightHex: "059669", darkHex: "3ECF8E", alphaLight: 0.10, alphaDark: 0.14)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSoft, accent, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradientFlat: LinearGradient {
        LinearGradient(colors: [accent, accentDeep],
                       startPoint: .leading, endPoint: .trailing)
    }

    // MARK: Surfaces (Lab98 Studio Canvas & Cards)
    static let bgCanvas = dynamicColor(lightHex: "F8FAFC", darkHex: "121316")
    static let bgCanvasBottom = dynamicColor(lightHex: "F1F5F9", darkHex: "0C0D0F")
    static let bgSidebar = dynamicColor(lightHex: "F1F5F9", darkHex: "17181D")
    static let bgCard = dynamicColor(lightHex: "FFFFFF", darkHex: "1D1F24")
    static let bgCardHover = dynamicColor(lightHex: "F8FAFC", darkHex: "24262C")

    static var appBackground: LinearGradient {
        LinearGradient(colors: [bgCanvas, bgCanvasBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    static let glassTint = Color.primary.opacity(0.02)
    static let hairline = dynamicColor(lightHex: "E2E8F0", darkHex: "2E3038")
    static let hairlineSoft = dynamicColor(lightHex: "CBD5E1", darkHex: "3A3D47")

    // MARK: Text & Contrast (Solid, Razor-Sharp Typography - No Haze/Blur)
    static let textPrimary = dynamicColor(lightHex: "020617", darkHex: "EDEDED")
    static let textSecondary = dynamicColor(lightHex: "475569", darkHex: "A1A1AA")
    static let textOnAccent = dynamicColor(lightHex: "FFFFFF", darkHex: "0E0F12")

    // MARK: Card Shadow (Light: Soft 4% shadow for crisp edges / Dark: 35% shadow)
    static let cardShadow = dynamicColor(lightHex: "000000", darkHex: "000000", alphaLight: 0.04, alphaDark: 0.35)

    // MARK: Semantic
    static let danger = dynamicColor(lightHex: "EF4444", darkHex: "F87171")
    static let dangerBg = dynamicColor(lightHex: "FEE2E2", darkHex: "471C1C", alphaLight: 0.5, alphaDark: 0.3)
    static let warning = dynamicColor(lightHex: "F59E0B", darkHex: "FBBF24")

    // MARK: Metrics
    static let radiusCard: CGFloat = 12
    static let radiusControl: CGFloat = 8
    static let radiusChip: CGFloat = 6
    static let cardPadding: CGFloat = 18
    static let pagePadding: CGFloat = 28
}

// MARK: - NSColor Hex Extension
extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}


// MARK: - Studio Card Modifier (Sharp Edges, No Text Blur)

private struct GlassCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(highlighted ? Theme.bgCardHover : Theme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(highlighted ? Theme.accent.opacity(0.45) : Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
    }
}


extension View {
    /// Supabase Dark Studio Card.
    func glassCard(padding: CGFloat = Theme.cardPadding,
                   radius: CGFloat = Theme.radiusCard,
                   highlighted: Bool = false) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius, highlighted: highlighted))
    }

    /// Dark Studio Page Background.
    func appBackground() -> some View {
        background(Theme.appBackground.ignoresSafeArea())
    }
}

// MARK: - Supabase Button Styles

/// Supabase Emerald Primary Action Button (Bright Emerald with Crisp Dark Bold Text).
struct PrimaryActionButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(enabled ? Theme.textOnAccent : Theme.textSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(Theme.accent)
                                  : AnyShapeStyle(Theme.bgCardHover))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .stroke(enabled ? Theme.accentSoft.opacity(0.3) : Theme.hairline, lineWidth: 1)
            )
            .shadow(color: enabled ? Theme.accent.opacity(0.3) : .clear, radius: 10, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Danger Action Button.
struct DangerActionButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(enabled ? Color.white : Theme.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(Theme.bgCardHover))
            )
            .shadow(color: enabled ? Theme.danger.opacity(0.3) : .clear, radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Supabase Secondary (Translucent Dark Slate) Button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                    .fill(Theme.bgCardHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

// MARK: - Reusable Section Header

struct PageHeader: View {
    let title: String
    let subtitle: String
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accentGlow)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }
}

