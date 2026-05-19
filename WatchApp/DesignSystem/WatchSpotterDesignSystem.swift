import SwiftUI

enum WatchSpotterPalette {
    static let accent = Color(red: 0.37, green: 0.63, blue: 1.0)
}

struct WatchGlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
    }
}

struct WatchGlassButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(WatchSpotterPalette.accent.opacity(0.82), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
