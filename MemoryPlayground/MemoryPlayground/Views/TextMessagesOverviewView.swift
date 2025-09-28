import SwiftUI
import Foundation

struct TextMessagesOverviewView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onSelectContact: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Text Messages")
                .font(.system(size: 36, weight: .bold))
            if viewModel.textContactSummaries.isEmpty {
                Text("No message history yet. Grant Full Disk Access and refresh to load your chats.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 18, pinnedViews: []) {
                        ForEach(viewModel.textContactSummaries) { summary in
                            Button {
                                onSelectContact(summary.id)
                            } label: {
                                HStack(alignment: .top, spacing: 16) {
                                    avatar(for: summary.displayName)
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(summary.displayName)
                                                .font(.headline)
                                            Spacer()
                                            Text(summary.formattedLastMessage)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("\(summary.messageCount) messages")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(summary.preview)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.03))
    }

    private func avatar(for name: String) -> some View {
        let initials = name.split(separator: " ").prefix(2).map { String($0.first ?? "?") }.joined()
        return ZStack {
            Circle()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 44, height: 44)
            Text(initials)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.blue)
        }
    }
}
