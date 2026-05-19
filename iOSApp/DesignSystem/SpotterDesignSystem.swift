import SwiftUI

enum SpotterPalette {
    static let backgroundTop = Color(red: 0.04, green: 0.07, blue: 0.11)
    static let backgroundBottom = Color(red: 0.01, green: 0.02, blue: 0.03)
    static let accent = Color(red: 0.37, green: 0.63, blue: 1.0)
    static let accentSoft = Color(red: 0.57, green: 0.74, blue: 1.0)
}

struct SpotterBackground: View {
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
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
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
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(style == .primary ? .white : .primary)
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(style == .primary ? 0.18 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(SpotterPalette.accentSoft)

                Text(value)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(SpotterPalette.accentSoft)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(metric)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
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
                        colors: [SpotterPalette.accentSoft, .white.opacity(0.9), SpotterPalette.accent],
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
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 118, height: 118)
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
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
