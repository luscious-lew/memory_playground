import SwiftUI
import Foundation

struct VoiceConversationDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let conversationID: UUID

    @State private var detail: VoiceConversationDetail?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let detail {
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.conversation.structuredTitle ?? "Conversation")
                        .font(.system(size: 32, weight: .bold))
                    HStack(spacing: 12) {
                        Text(detail.conversation.createdAt.formatted(date: .abbreviated, time: .shortened))
                        if let category = detail.conversation.structuredCategory {
                            Text(category)
                        }
                        if let status = detail.conversation.status {
                            Text(status.capitalized)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let overview = detail.conversation.structuredOverview, !overview.isEmpty {
                        markdownText(overview)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.top, 6)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !detail.pluginContent.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(detail.pluginContent, id: \.self) { content in
                                markdownText(content)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                    .lineSpacing(4)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 14)
                                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(detail.segments, id: \.self) { segment in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(segment.speaker ?? (segment.isUser == true ? "You" : "Speaker"))
                                        .font(.headline)
                                    Spacer()
                                    if let start = segment.startSec, let end = segment.endSec {
                                        Text("\(start, specifier: "%.0f")s – \(end, specifier: "%.0f")s")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                markdownText(segment.text)
                                    .font(.system(size: 16))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.bottom, 32)
                }
            } else if isLoading {
                ProgressView("Loading conversation…")
            } else {
                Text("Unable to load conversation.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.03))
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        detail = await viewModel.voiceConversationDetail(for: conversationID)
        isLoading = false
    }

    private func markdownText(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }
}
