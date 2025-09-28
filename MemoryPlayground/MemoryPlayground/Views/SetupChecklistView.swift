import SwiftUI

struct SetupChecklistView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Memory Playground Setup")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Finish these quick steps so the app can remix your real conversations.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Memory Playground ingests your entire recent iMessage history (limit configurable via IMESSAGE_MESSAGE_LIMIT) along with Omi transcripts to power the remixes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            checklistItem(
                title: "Grant Full Disk Access",
                description: "System Settings → Privacy & Security → Full Disk Access → add Xcode (or the built app).",
                status: viewModel.onboardingState.contains(.fullDiskAccess)
            ) {
                openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }

            checklistItem(
                title: "Allow Contacts Access",
                description: "Optional but recommended: approve Contacts so we can label iMessage participants.",
                status: viewModel.onboardingState.contains(.contactsAccess)
            ) {
                viewModel.requestContactsAccess()
            }

            checklistItem(
                title: "Add API Keys",
                description: "Set OPENAI_API_KEY + OMI_API_KEY in the scheme environment or shell before launch.",
                status: viewModel.onboardingState.contains(.apiKeysConfigured)
            ) {
                openURL(URL(string: "https://platform.openai.com/account/api-keys")!)
            }

            Button {
                viewModel.refreshOnboarding()
            } label: {
                Label("Re-check setup", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: 640)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(radius: 24)
    }

    @ViewBuilder
    private func checklistItem(title: String, description: String, status: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: status ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(status ? .green : .orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !status {
                    Button("Show me how", action: action)
                        .buttonStyle(.link)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
