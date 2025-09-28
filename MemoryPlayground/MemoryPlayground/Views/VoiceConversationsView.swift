import SwiftUI
import Foundation

struct VoiceConversationsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onSelectConversation: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Voice Conversations")
                .font(.system(size: 36, weight: .bold))
            if viewModel.isLoadingVoiceConversations {
                ProgressView("Loading conversations…")
                    .progressViewStyle(.circular)
            } else if let error = viewModel.voiceConversationsError {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unable to load conversations.")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.voiceConversations.isEmpty {
                Text("No voice conversations yet. Add your Supabase key to fetch them.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.voiceConversations) { convo in
                            Button {
                                onSelectConversation(convo.id)
                            } label: {
                                HStack(alignment: .top, spacing: 16) {
                                    Text(convo.structuredEmoji ?? "🎙️")
                                        .font(.system(size: 30))
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(convo.structuredTitle ?? "Conversation")
                                            .font(.headline)
                                        HStack(spacing: 12) {
                                            Text(convo.structuredCategory ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(convo.createdAt.formatted(.relative(presentation: .named)))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let status = convo.status {
                                            Text(status.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
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
        .task {
            if viewModel.voiceConversations.isEmpty {
                await viewModel.loadVoiceConversations()
            }
        }
    }
}
