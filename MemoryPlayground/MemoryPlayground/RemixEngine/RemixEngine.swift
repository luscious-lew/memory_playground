import Foundation
import os

/// Central orchestrator that asks GPT-5 to remix conversation history into playful formats.
final class RemixEngine {
    private let gptClient: GPTClient
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "RemixEngine")

    init(gptClient: GPTClient) {
        self.gptClient = gptClient
    }

    func generateDailyNewspaper(conversations: [ConversationItem]) async -> String {
        await run(
            prompt: prompt(for: conversations, style: "daily newspaper front page"),
            system: "You are a witty newsroom editor who writes bold headlines and short blurbs.",
            reasoning: .low,
            verbosity: .high
        )
    }

    func generateRoast(conversations: [ConversationItem]) async -> String {
        await run(
            prompt: prompt(for: conversations, style: "playful roast of the week's events"),
            system: "You are a roast comic who keeps jokes affectionate yet spicy.",
            reasoning: .low,
            verbosity: .medium,
            maxTokens: 1000
        )
    }

    func generateTrivia(conversations: [ConversationItem]) async -> [TriviaQuestion] {
        let response = await run(
            prompt: prompt(for: conversations, style: "generate 5 trivia questions with 4 options and a fun fact"),
            system: "You are a trivia host. Reply in JSON array format with fields prompt, options, answerIndex, funFact.",
            reasoning: .minimal,
            verbosity: .low
        )

        guard let data = response.data(using: .utf8), let questions = try? JSONDecoder().decode([TriviaQuestion].self, from: data) else {
            return fallbackTrivia()
        }
        return questions
    }

    func generateComic(conversations: [ConversationItem]) async -> [ComicPanel] {
        let response = await run(
            prompt: prompt(for: conversations, style: "turn into a 4-panel comic. Each panel needs title, caption, illustration idea"),
            system: "You are a comic script writer. Reply in JSON array with title, caption, illustrationPrompt.",
            reasoning: .low,
            verbosity: .medium
        )

        guard let data = response.data(using: .utf8), let panels = try? JSONDecoder().decode([ComicPanel].self, from: data) else {
            return fallbackComic()
        }
        return panels
    }

    func generateFutureYou(conversations: [ConversationItem]) async -> String {
        await run(
            prompt: prompt(for: conversations, style: "send advice from future self"),
            system: "You are future \"me\" sending heartfelt advice with futurist flair.",
            reasoning: .medium,
            verbosity: .medium,
            maxTokens: 1000
        )
    }

    private func run(prompt: String, system: String, reasoning: GPTClient.ReasoningEffort = .medium, verbosity: GPTClient.TextVerbosity? = nil, maxTokens: Int? = nil) async -> String {
        do {
            let result = try await gptClient.complete(prompt: prompt, instructions: system, reasoningEffort: reasoning, textVerbosity: verbosity, maxTokens: maxTokens)
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logger.warning("Received empty response from GPT-5 for style: \(system, privacy: .public)")
            }
            return result
        } catch {
            logger.error("GPT-5 remix failed: \(error.localizedDescription, privacy: .public)")
            return fallbackText(for: prompt)
        }
    }

    private func prompt(for conversations: [ConversationItem], style: String) -> String {
        let transcript = conversations.suffix(40).map { item in
            "[\(item.timestamp) | \(item.speaker)]: \(item.text)"
        }.joined(separator: "\n")
        return "Use the following conversation transcript to create a \(style):\n\(transcript)"
    }

    private func fallbackText(for context: String) -> String {
        "Remix placeholder because GPT-5 is not reachable. Context hash: \(context.hashValue)"
    }

    private func fallbackTrivia() -> [TriviaQuestion] {
        [
            TriviaQuestion(
                prompt: "Who sent the most messages this week?",
                options: ["Alex", "Taylor", "Jordan", "Kai"],
                answerIndex: 1,
                funFact: "Taylor barely edged out Jordan by 3 texts."),
            TriviaQuestion(
                prompt: "What word keeps popping up?",
                options: ["Deadline", "Coffee", "Concert", "Omi"],
                answerIndex: 0,
                funFact: "Apparently the squad is fueled by caffeine and chaos.")
        ]
    }

    private func fallbackComic() -> [ComicPanel] {
        [
            ComicPanel(title: "Panel 1", caption: "Meet the crew gearing up for hackathon mayhem.", illustrationPrompt: "Four friends huddled over laptops with neon lighting."),
            ComicPanel(title: "Panel 2", caption: "Omi blurts out a wild idea mid-walk.", illustrationPrompt: "Wearable device emitting speech bubbles."),
            ComicPanel(title: "Panel 3", caption: "iMessage thread erupts in memes.", illustrationPrompt: "Phone screen overflowing with gifs and emojis."),
            ComicPanel(title: "Panel 4", caption: "Future self approves from a hoverboard.", illustrationPrompt: "Futuristic version of the main character giving thumbs up.")
        ]
    }
}
