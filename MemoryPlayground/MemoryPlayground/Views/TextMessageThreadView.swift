import SwiftUI

struct TextMessageThreadView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let contactID: String

    @State private var messages: [ConversationItem] = []
    @State private var title: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.isEmpty ? "Conversation" : title)
                        .font(.system(size: 32, weight: .bold))
                    if let summary = viewModel.contactSummary(for: contactID) {
                        Text("Last message \(summary.formattedLastMessage)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            messageBubble(message)
                                .id(index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: proxy)
                }
            }
        }
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.03))
        .task {
            loadThread()
        }
    }

    private func loadThread() {
        messages = viewModel.messages(for: contactID)
        title = viewModel.contactSummary(for: contactID)?.displayName ?? "Conversation"
    }

    @ViewBuilder
    private func messageBubble(_ item: ConversationItem) -> some View {
        let isMe = item.isFromMe
        HStack(alignment: .bottom) {
            if isMe {
                Spacer()
                bubble(for: item, isMe: true)
            } else {
                bubble(for: item, isMe: false)
                Spacer()
            }
        }
        .transition(.opacity)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastIndex = messages.indices.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastIndex, anchor: .bottom)
            }
        }
    }

    private func bubble(for item: ConversationItem, isMe: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !isMe {
                Text(item.speaker)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.text)
                .font(.system(size: 16))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isMe ? Color.blue.opacity(0.85) : Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(isMe ? Color.white : Color.primary)
        .frame(maxWidth: 360, alignment: .leading)
    }
}
