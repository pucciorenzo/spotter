import SwiftUI

struct PlanListView: View {
    let dataProvider: any SpotterDataProviding
    @State private var searchText = ""
    @State private var showingCreatePlanSheet = false

    private var plans: [SpotterPlanSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return dataProvider.plans
        }

        return dataProvider.plans.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.suggestedDay.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            if plans.isEmpty && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                PlansEmptyState {
                    showingCreatePlanSheet = true
                }
                .padding(.horizontal, 28)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(plans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                PlanCard(plan: plan)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                } label: {
                                    Label("Make Active", systemImage: "checkmark.circle")
                                }

                                Button {
                                } label: {
                                    Label("Edit Plan", systemImage: "pencil")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                }
            }
        }
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Plans")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreatePlanSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                }
                .accessibilityLabel("Create Plan")
            }
        }
        .sheet(isPresented: $showingCreatePlanSheet) {
            CreatePlanSheet()
                .presentationDetents([.height(330), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .spotterScreenChrome()
    }
}

private struct PlanCard: View {
    let plan: SpotterPlanSummary

    var body: some View {
        GlassCard(cornerRadius: 26, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(plan.name)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)

                            if plan.isActive {
                                Text("Active")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                                    }
                            }
                        }

                        Text("\(plan.days.count) days")
                            .font(.subheadline)
                            .foregroundStyle(SpotterPalette.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SpotterPalette.textTertiary)
                }

                HStack(spacing: 10) {
                    PlanInfoPill(title: plan.lastUsed, systemImage: "clock")
                    PlanInfoPill(title: plan.suggestedDay, systemImage: "arrow.forward.circle")
                }
            }
        }
    }
}

private struct PlanDetailView: View {
    let plan: SpotterPlanSummary

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(
                        eyebrow: "\(plan.days.count) days",
                        title: plan.name,
                        subtitle: "Plan edits will apply going forward. Completed workout logs keep their original snapshot."
                    )

                    ForEach(plan.days) { day in
                        NavigationLink {
                            PlanDayDetailView(day: day)
                        } label: {
                            GlassCard {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(day.name)
                                            .font(.title3.weight(.semibold))
                                        Text(day.focus)
                                            .font(.subheadline)
                                            .foregroundStyle(SpotterPalette.textSecondary)
                                        Text("\(day.exerciseCount) exercises - \(day.estimatedDuration)")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(SpotterPalette.accentSoft)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(SpotterPalette.accentSoft)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }

            GlassButton(title: "Start Workout", systemImage: "play.fill")
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit Plan")
            }
        }
        .spotterScreenChrome()
    }
}

private struct PlanDayDetailView: View {
    let day: SpotterPlanDaySummary

    var body: some View {
        ZStack(alignment: .bottom) {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        eyebrow: "Workout Day",
                        title: day.name,
                        subtitle: "\(day.focus) - \(day.estimatedDuration)"
                    )

                    GlassCard {
                        VStack(spacing: 4) {
                            ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, exercise in
                                ExerciseRow(
                                    name: exercise.name,
                                    detail: exercise.target,
                                    metric: exercise.load
                                )
                                if index < day.exercises.count - 1 {
                                    Divider().overlay(.white.opacity(0.10))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }

            GlassButton(title: "Start Workout", systemImage: "play.fill")
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
    }
}

private struct PlansEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 84)

            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 42, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(SpotterPalette.accentSoft)
                .frame(width: 92, height: 92)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                }

            VStack(spacing: 8) {
                Text("No Plans")
                    .font(.title2.weight(.semibold))
                Text("Create a plan for your training week, then build days around how you lift.")
                    .font(.subheadline)
                    .foregroundStyle(SpotterPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GlassButton(title: "Create Plan", systemImage: "plus", action: onCreate)
                .frame(maxWidth: 260)

            Spacer(minLength: 84)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CreatePlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                SpotterBackground()

                VStack(alignment: .leading, spacing: 18) {
                    Text("Name your workout plan.")
                        .font(.headline)

                    TextField("Plan Name", text: $planName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .foregroundStyle(SpotterPalette.textPrimary)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(SpotterPalette.glassStroke, lineWidth: 1)
                        }

                    GlassButton(title: "Create Plan", systemImage: "plus") {
                        dismiss()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                isNameFocused = true
            }
        }
    }
}

private struct PlanInfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(SpotterPalette.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.07), in: Capsule())
    }
}

#Preview {
    NavigationStack {
        PlanListView(dataProvider: MockSpotterRepository.preview)
            .preferredColorScheme(.dark)
    }
}
