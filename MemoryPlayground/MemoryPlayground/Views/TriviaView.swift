import SwiftUI

struct TriviaView: View {
    let questions: [TriviaQuestion]
    @State private var selectedQuestion: TriviaQuestion?
    @State private var revealAnswer = false

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
            TriviaDetail(question: question, revealAnswer: $revealAnswer)
        }
    }

    private func triviaCard(_ question: TriviaQuestion) -> some View {
        Button {
            selectedQuestion = question
            revealAnswer = false
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

private struct TriviaDetail: View {
    let question: TriviaQuestion
    @Binding var revealAnswer: Bool

    var body: some View {
        VStack(spacing: 22) {
            Text(question.prompt)
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    HStack {
                        Text(String(UnicodeScalar(65 + index)!))
                            .font(.system(size: 16, weight: .semibold))
                        Text(option)
                            .font(.system(size: 16))
                        Spacer()
                        if revealAnswer && index == question.answerIndex {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            if revealAnswer {
                Text(question.funFact)
                    .font(.system(size: 15, weight: .medium))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            Button(revealAnswer ? "Nice!" : "Reveal Answer") {
                revealAnswer.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding(36)
        .frame(minWidth: 520)
    }
}
