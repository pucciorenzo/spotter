import SwiftUI

struct ProgressScreenView: View {
    let dataProvider: any SpotterDataProviding
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsNavigationTitle = false

    private var snapshot: SpotterProgressSnapshot {
        dataProvider.progress
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LazyVGrid(columns: metricColumns, spacing: 14) {
                        ForEach(snapshot.headlineMetrics) { metric in
                            MetricCard(
                                title: metric.title,
                                value: metric.value,
                                caption: metric.caption,
                                systemImage: metric.systemImage
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercise Progress")
                            .font(.headline)

                        if snapshot.exerciseTrends.isEmpty {
                            SpotterStateView(
                                mode: .empty,
                                title: "No exercise history",
                                message: "Exercise trends appear after completed workouts.",
                                systemImage: "chart.line.uptrend.xyaxis"
                            )
                        } else {
                            GlassCard {
                                VStack(spacing: 4) {
                                    ForEach(Array(snapshot.exerciseTrends.enumerated()), id: \.element.id) { index, trend in
                                        ExerciseTrendRow(trend: trend)
                                        if index < snapshot.exerciseTrends.count - 1 {
                                            Divider().overlay(.white.opacity(0.10))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plan Progress")
                            .font(.headline)

                        PlanTrendCard(trend: snapshot.planTrend)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 34)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 24
            } action: { _, isScrolled in
                showsNavigationTitle = isScrolled
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SpotterInlineNavigationTitle(title: "Progress", isVisible: showsNavigationTitle)
            }
        }
        .spotterScreenChrome()
    }

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }
}

private struct ExerciseTrendRow: View {
    let trend: SpotterExerciseTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(trend.exerciseName)
                    .font(.headline)
                Spacer()
                Text(trend.bestSet)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(SpotterPalette.accentSoft)
            }

            HStack(spacing: 12) {
                Label(trend.totalVolume, systemImage: "chart.bar")
                Label(trend.frequency, systemImage: "calendar")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(SpotterPalette.textSecondary)

            Text(trend.trend)
                .font(.caption)
                .foregroundStyle(SpotterPalette.textTertiary)
        }
        .padding(.vertical, 10)
    }
}

private struct PlanTrendCard: View {
    let trend: SpotterPlanTrend

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(trend.planName)
                        .font(.title2.weight(.semibold))
                    Text("\(trend.completedSessions) - \(trend.averageDuration) avg - \(trend.consistency)")
                        .font(.subheadline)
                        .foregroundStyle(SpotterPalette.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(trend.distribution) { metric in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: metric.systemImage)
                                .font(.headline)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(SpotterPalette.accentSoft)
                            Text(metric.value)
                                .font(.title3.weight(.semibold))
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(SpotterPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProgressScreenView(dataProvider: MockSpotterRepository.preview)
            .preferredColorScheme(.dark)
    }
}
