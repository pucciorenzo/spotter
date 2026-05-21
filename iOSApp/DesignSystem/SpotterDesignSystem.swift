import SwiftUI
import UIKit

enum SpotterPalette {
    static let backgroundTop = Color(red: 0.04, green: 0.07, blue: 0.11)
    static let backgroundBottom = Color(red: 0.01, green: 0.02, blue: 0.03)
    static let accent = Color(red: 0.37, green: 0.63, blue: 1.0)
    static let accentSoft = Color(red: 0.33, green: 0.49, blue: 0.73)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.45)
    static let iconMuted = Color.white.opacity(0.56)
    static let glassStroke = Color.white.opacity(0.16)
    static let navGlass = Color(red: 0.04, green: 0.06, blue: 0.09)
}

enum SpotterAppearance {
    static func configure() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.96)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.96)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navAppearance
        navigationBar.compactAppearance = navAppearance
        navigationBar.scrollEdgeAppearance = navAppearance
        navigationBar.tintColor = UIColor(red: 0.33, green: 0.49, blue: 0.73, alpha: 1.0)
        navigationBar.overrideUserInterfaceStyle = .dark

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 1.0)
        tabAppearance.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
        tabBar.tintColor = UIColor(red: 0.33, green: 0.49, blue: 0.73, alpha: 1.0)
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.46)
        tabBar.overrideUserInterfaceStyle = .dark
    }
}

enum SpotterHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

struct SpotterBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SpotterPalette.backgroundTop,
                    Color(red: 0.03, green: 0.05, blue: 0.08),
                    SpotterPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !reduceMotion {
                RadialGradient(
                    colors: [
                        SpotterPalette.accent.opacity(0.20),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 360
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 28, padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 28, y: 18)
    }
}

struct GlassButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    var style: Style = .primary
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            GlassButtonLabel(title: title, systemImage: systemImage, style: style)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

struct GlassButtonLabel: View {
    let title: String
    let systemImage: String
    var style: GlassButton.Style = .primary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .frame(minHeight: 52)
        .foregroundStyle(SpotterPalette.textPrimary)
        .background(buttonBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(style == .primary ? 0.18 : 0.12), lineWidth: 1)
        }
    }

    private var buttonBackground: some ShapeStyle {
        style == .primary
            ? AnyShapeStyle(LinearGradient(
                colors: [SpotterPalette.accent.opacity(0.94), SpotterPalette.accentSoft.opacity(0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            : AnyShapeStyle(.thinMaterial)
    }
}

struct GlassIconButtonLabel: View {
    let systemImage: String
    var diameter: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .frame(width: diameter, height: diameter)
            .foregroundStyle(SpotterPalette.textPrimary)
            .background(.thinMaterial, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .contentShape(Circle())
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)

                Text(value)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SpotterPalette.textPrimary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(SpotterPalette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        }
    }
}

struct ExerciseRow: View {
    let name: String
    let detail: String
    let metric: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(SpotterPalette.accentSoft)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(SpotterPalette.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
            }

            Spacer()

            Text(metric)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(SpotterPalette.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

struct WorkoutProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [
                            SpotterPalette.accentSoft,
                            SpotterPalette.accent.opacity(0.82),
                            SpotterPalette.accentSoft
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("done")
                    .font(.caption)
                    .foregroundStyle(SpotterPalette.textSecondary)
            }
        }
        .frame(width: 118, height: 118)
    }
}

struct SpotterStateView: View {
    enum Mode {
        case empty
        case loading
        case error
    }

    let mode: Mode
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        GlassCard(cornerRadius: 26, padding: 20) {
            VStack(spacing: 14) {
                Image(systemName: mode == .loading ? "progress.indicator" : systemImage)
                    .font(.system(.title2, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(mode == .error ? .orange : SpotterPalette.accentSoft)
                    .frame(width: 54, height: 54)
                    .background(.thinMaterial, in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(SpotterPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(actionTitle)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(SpotterPalette.accentSoft)
            Text(title)
                .font(.largeTitle.weight(.semibold))
                .tracking(0)
                .foregroundStyle(SpotterPalette.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(SpotterPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.34),
                    Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
        }
    }
}

struct SpotterScreenChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(SpotterPalette.textPrimary)
            .tint(SpotterPalette.accentSoft)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .toolbarBackground(SpotterPalette.navGlass, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

extension View {
    func spotterScreenChrome() -> some View {
        modifier(SpotterScreenChrome())
    }

    @ViewBuilder
    func spotterZoomSource<ID: Hashable>(
        _ id: ID,
        in namespace: Namespace.ID,
        reduceMotion: Bool
    ) -> some View {
        if reduceMotion {
            self
        } else {
            matchedTransitionSource(id: id, in: namespace)
        }
    }

    @ViewBuilder
    func spotterZoomDestination<ID: Hashable>(
        _ id: ID,
        in namespace: Namespace.ID,
        reduceMotion: Bool
    ) -> some View {
        if reduceMotion {
            self
        } else {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        }
    }

    func spotterNavigationChrome() -> some View {
        background(SpotterPalette.backgroundBottom.ignoresSafeArea())
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct SpotterInlineNavigationTitle: View {
    let title: String
    let isVisible: Bool

    var body: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(SpotterPalette.textPrimary.opacity(isVisible ? 1 : 0))
            .animation(.easeInOut(duration: 0.18), value: isVisible)
    }
}
