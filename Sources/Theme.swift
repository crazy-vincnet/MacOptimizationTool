import SwiftUI

// MARK: - Design System
// 미니멀 · 라이트 · 글래스모피즘 · 그린 액센트.
// 모든 뷰는 하드코딩 색상/카드 대신 이 토큰과 모디파이어를 사용한다.

enum Theme {

    // MARK: Accent (Emerald)
    /// 주 액센트 그린 (#22C55E)
    static let accent = Color(red: 0.13, green: 0.77, blue: 0.37)
    /// 진한 그린 (그라디언트 끝, #16A34A)
    static let accentDeep = Color(red: 0.09, green: 0.64, blue: 0.29)
    /// 밝은 민트 (그라디언트 하이라이트, #6EE7B7)
    static let accentSoft = Color(red: 0.43, green: 0.91, blue: 0.72)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSoft, accent, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradientFlat: LinearGradient {
        LinearGradient(colors: [accent, accentDeep],
                       startPoint: .leading, endPoint: .trailing)
    }

    // MARK: Surfaces (Light minimal)
    /// 창 배경 상단 (거의 흰색, 미세한 그린 틴트)
    static let bgTop = Color(red: 0.98, green: 0.99, blue: 0.98)
    /// 창 배경 하단 (연한 그린-그레이)
    static let bgBottom = Color(red: 0.93, green: 0.96, blue: 0.94)

    static var appBackground: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom],
                       startPoint: .top, endPoint: .bottom)
    }

    /// 카드 유리면 위에 얹는 미세한 흰색 오버레이
    static let glassTint = Color.white.opacity(0.55)
    /// 카드 테두리 (얇은 밝은 라인)
    static let hairline = Color.white.opacity(0.7)
    static let hairlineSoft = Color.black.opacity(0.05)

    // MARK: Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textOnAccent = Color.white

    // MARK: Semantic
    static let danger = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let warning = Color(red: 0.98, green: 0.71, blue: 0.19)

    // MARK: Metrics
    static let radiusCard: CGFloat = 18
    static let radiusControl: CGFloat = 12
    static let radiusChip: CGFloat = 8
    static let cardPadding: CGFloat = 20
    static let pagePadding: CGFloat = 30
}

// MARK: - Glass Card

private struct GlassCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var highlighted: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.glassTint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(highlighted ? Theme.accent.opacity(0.5) : Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}

extension View {
    /// 표준 글래스 카드. 배경·테두리·그림자·패딩을 일관되게 적용.
    func glassCard(padding: CGFloat = Theme.cardPadding,
                   radius: CGFloat = Theme.radiusCard,
                   highlighted: Bool = false) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius, highlighted: highlighted))
    }

    /// 페이지 전체 라이트 그라디언트 배경.
    func appBackground() -> some View {
        background(Theme.appBackground.ignoresSafeArea())
    }
}

// MARK: - Button Styles

/// 그린 그라디언트 주 액션 버튼.
struct PrimaryActionButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(Theme.textOnAccent)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(Theme.accentGradientFlat)
                                  : AnyShapeStyle(Color.gray.opacity(0.3)))
            )
            .shadow(color: enabled ? Theme.accent.opacity(0.28) : .clear, radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 파괴적(삭제) 액션 버튼.
struct DangerActionButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(Theme.textOnAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(Color.gray.opacity(0.3)))
            )
            .shadow(color: enabled ? Theme.danger.opacity(0.25) : .clear, radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 보조(투명/외곽선) 버튼.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                    .stroke(Theme.hairlineSoft, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
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
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.accentGradient)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.accent.opacity(0.12))
                    )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }
}
