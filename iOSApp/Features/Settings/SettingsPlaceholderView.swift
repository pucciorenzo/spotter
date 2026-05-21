import SwiftUI
import SwiftData
import UIKit

struct ProfileView: View {
    let dataProvider: any SpotterDataProviding
    @ObservedObject var healthKitManager: HealthKitWorkoutManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("activeWorkoutFocusModeDefault") private var focusModeDefault = false
    @State private var promptForSetResults = true
    @State private var exportURLs: [URL] = []
    @State private var showingExporter = false
    @State private var exportErrorMessage: String?

    private var profile: SpotterProfileSnapshot {
        dataProvider.profile
    }

    var body: some View {
        ZStack {
            SpotterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(
                        eyebrow: "Account-free",
                        title: "Profile",
                        subtitle: profile.privacyMessage
                    )

                    ProfileSection(title: "Units") {
                        ProfileRow(title: "Weight", value: profile.weightUnit, systemImage: "scalemass")
                        ProfileRow(title: "Distance", value: profile.distanceUnit, systemImage: "ruler")
                    }

                    ProfileSection(title: "Workout Defaults") {
                        Toggle(isOn: $focusModeDefault) {
                            Label("Start Workouts in Focus Mode", systemImage: "scope")
                        }
                        .tint(SpotterPalette.accentSoft)

                        Toggle(isOn: $promptForSetResults) {
                            Label("Prompt for Set Results", systemImage: "keyboard")
                        }
                        .tint(SpotterPalette.accentSoft)

                        ProfileRow(title: "Default Rest", value: "120s", systemImage: "timer")
                    }

                    ProfileSection(title: "Health") {
                        ProfileRow(
                            title: "Status",
                            value: healthKitManager.authorizationStatusText,
                            systemImage: "heart"
                        )

                        HStack(spacing: 12) {
                            ProfileRow(
                                title: "Apple Workout",
                                value: healthKitManager.isParallelWorkoutActive ? "Running" : "Optional",
                                systemImage: "figure.strengthtraining.traditional"
                            )
                        }

                        Button {
                            healthKitManager.requestAuthorization()
                        } label: {
                            Label("Connect Apple Health", systemImage: "heart.text.square")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Text("Optional. Spotter stays local-first and can save workout duration, active energy and heart rate with permission.")
                            .font(.caption)
                            .foregroundStyle(SpotterPalette.textSecondary)

                        if let error = healthKitManager.lastErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    ProfileSection(title: "Data") {
                        ProfileActionRow(title: "Export CSV", systemImage: "tablecells") {
                            exportCSV()
                        }
                        ProfileActionRow(title: "Export JSON", systemImage: "curlybraces.square") {
                            exportJSON()
                        }
                        ProfileActionRow(title: "Import Data", systemImage: "square.and.arrow.down")
                        ProfileActionRow(title: "Privacy Information", systemImage: "lock.shield")
                    }

                    ProfileSection(title: "About") {
                        ProfileRow(title: "Version", value: profile.appVersion, systemImage: "info.circle")
                        ProfileActionRow(title: "Open Source Project", systemImage: "curlybraces")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .spotterScreenChrome()
        .sheet(isPresented: $showingExporter) {
            ActivityView(activityItems: exportURLs)
        }
        .alert("Export Failed", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private func exportCSV() {
        do {
            exportURLs = try SpotterExportService.makeCSVExport(context: modelContext)
            showingExporter = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func exportJSON() {
        do {
            exportURLs = try SpotterExportService.makeJSONExport(context: modelContext)
            showingExporter = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }
}

private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            GlassCard(cornerRadius: 24, padding: 16) {
                VStack(spacing: 14) {
                    content
                }
            }
        }
    }
}

private struct ProfileRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(SpotterPalette.accentSoft)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SpotterPalette.textSecondary)
        }
    }
}

private struct ProfileActionRow: View {
    let title: String
    let systemImage: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SpotterPalette.accentSoft)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SpotterPalette.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = controller.view
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            dataProvider: MockSpotterRepository.preview,
            healthKitManager: HealthKitWorkoutManager()
        )
            .preferredColorScheme(.dark)
    }
}
