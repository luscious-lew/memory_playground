import SwiftUI

struct TriviaView: View {
    let questions: [TriviaQuestion]
    @State private var selectedQuestion: TriviaQuestion?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 2)

    var body: some View {
        VStack(spacing: 24) {
            Text("Context Trivia")
                .font(.system(size: 42, weight: .bold, design: .default))
                .foregroundStyle(.primary)
            Text("Tap a card to reveal the inside joke.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(questions) { question in
                        triviaCard(question)
                    }
                }
                .padding(32)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.04))
        .navigationTitle("Context Trivia")
        .sheet(item: $selectedQuestion) { question in
            TriviaRound(question: question)
        }
    }

    private func triviaCard(_ question: TriviaQuestion) -> some View {
        Button {
            selectedQuestion = question
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                Text(question.prompt)
                    .font(.system(size: 18, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Spacer()
                Text("Tap to play")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(26)
            .frame(maxWidth: .infinity, minHeight: 170)
            .background(LinearGradient(colors: [.blue.opacity(0.85), .purple.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 12)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct TriviaRound: View {
    let question: TriviaQuestion
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int? = nil
    @State private var attempts: Set<Int> = []
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 22) {
            Text(question.prompt)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        handleSelection(index)
                    } label: {
                        HStack {
                            Text(String(UnicodeScalar(65 + index)!))
                                .font(.system(size: 16, weight: .semibold))
                            Text(option)
                                .font(.system(size: 16))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            feedbackIcon(for: index)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(backgroundColor(for: index), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    }
            }
            if let selectedIndex, selectedIndex == question.answerIndex {
                Text(question.funFact)
                    .font(.system(size: 15, weight: .medium))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            if isComplete {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            } else {
                Button("Pass for now") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(36)
        .frame(minWidth: 520)
    }

    private func handleSelection(_ index: Int) {
        if isComplete { return }
        selectedIndex = index
        if index == question.answerIndex {
            isComplete = true
        } else {
            attempts.insert(index)
        }
    }

    @ViewBuilder
    private func feedbackIcon(for index: Int) -> some View {
        if index == question.answerIndex, selectedIndex == index {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if attempts.contains(index) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func backgroundColor(for index: Int) -> Color {
        if index == question.answerIndex, selectedIndex == index {
            return Color.green.opacity(0.18)
        }
        if attempts.contains(index) {
            return Color.red.opacity(0.12)
        }
        return Color.black.opacity(0.05)
    }
}
