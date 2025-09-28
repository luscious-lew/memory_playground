import SwiftUI

struct FullDiskAccessView: View {
    @State private var isCheckingAccess = false
    @State private var hasAccess = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Full Disk Access Required")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Memory Playground needs Full Disk Access to read your iMessage history.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                Text("To grant access:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Open System Settings", systemImage: "1.circle.fill")
                    Label("Go to Privacy & Security → Full Disk Access", systemImage: "2.circle.fill")
                    Label("Toggle ON for Memory Playground", systemImage: "3.circle.fill")
                    Label("Restart the app", systemImage: "4.circle.fill")
                }
                .font(.body)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            HStack(spacing: 15) {
                Button("Open System Settings") {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Access") {
                    checkAccess()
                }
                .buttonStyle(.bordered)
            }

            if isCheckingAccess {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }

            if hasAccess {
                Label("Access Granted!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .frame(maxWidth: 500)
        .onAppear {
            checkAccess()
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkAccess() {
        isCheckingAccess = true
        let chatDbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
        hasAccess = FileManager.default.isReadableFile(atPath: chatDbPath)
        isCheckingAccess = false
    }
}