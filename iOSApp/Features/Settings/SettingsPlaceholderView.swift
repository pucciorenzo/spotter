import SwiftUI

struct ProfileView: View {
    let dataProvider: any SpotterDataProviding
    @State private var promptForSetResults = true

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
                        Toggle(isOn: $promptForSetResults) {
                            Label("Prompt for Set Results", systemImage: "keyboard")
                        }
                        .tint(SpotterPalette.accentSoft)

                        ProfileRow(title: "Default Rest", value: "120s", systemImage: "timer")
                    }

                    ProfileSection(title: "Health") {
                        ProfileRow(title: "Status", value: profile.healthStatus, systemImage: "heart")
                        Text("Health integration is planned as an optional local permission.")
                            .font(.caption)
                            .foregroundStyle(SpotterPalette.textSecondary)
                    }

                    ProfileSection(title: "Data") {
                        ProfileActionRow(title: "Export Data", systemImage: "square.and.arrow.up")
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

    var body: some View {
        Button {
        } label: {
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

#Preview {
    NavigationStack {
        ProfileView(dataProvider: MockSpotterRepository.preview)
            .preferredColorScheme(.dark)
    }
}
