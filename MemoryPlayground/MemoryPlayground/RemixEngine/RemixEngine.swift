import Foundation
import os

/// Central orchestrator that asks GPT-5 to remix conversation history into playful formats.
final class RemixEngine {
    private let gptClient: GPTClient
    private let imageGenerator: ImageGenerator?
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "RemixEngine")

    init(gptClient: GPTClient, imageGenerator: ImageGenerator? = nil) {
        self.gptClient = gptClient
        self.imageGenerator = imageGenerator
    }

    func generateDailyNewspaper(conversations: [ConversationItem]) async -> DailyNewspaper {
        let extra = """
Return a JSON object with this exact structure:
{
  "masthead": "The Lewis Times",
  "leadStory": {"headline": "...", "subheadline": "...", "body": "Two short paragraphs"},
  "featureStories": [
    {"headline": "...", "subheadline": "...", "body": "Two short paragraphs"},
    {"headline": "...", "subheadline": "...", "body": "Two short paragraphs"}
  ],
  "quoteOfDay": {"text": "Direct quote from the transcript", "attribution": "Who said it or why it matters"},
  "gossipColumn": {"headline": "Playful gossip headline", "body": "One paragraph of playful speculation"}
}
- Provide at least three total stories (lead + feature array). Each story should cover a single cohesive moment or theme from the transcript.
- Story bodies must contain no more than two short paragraphs, each with at most three sentences. Be vivid but concise.
- Use actual sentiments from the transcript for the quote and gossip, embellished where helpful but anchored in reality.
- Respond with JSON only; do not include markdown fences or extra commentary.
"""

        let raw = await run(
            prompt: prompt(for: conversations, style: "daily newspaper front page", extraInstructions: extra),
            system: "You are an imaginative newsroom editor. Write vivid yet concise human stories, never code. Expand sparse details into engaging narrative coverage. Follow the exact JSON schema provided and keep each story tightly focused.",
            reasoning: .low,
            verbosity: .high
        )

        if let data = raw.data(using: .utf8) {
            do {
                let payload = try JSONDecoder().decode(DailyNewspaperPayload.self, from: data)
                var paper = DailyNewspaper(payload: payload, rawText: raw)
                if paper.leadStory == nil || paper.featureStories.isEmpty || paper.quoteOfDay == nil || paper.gossipColumn == nil {
                    if let fallback = DailyNewspaper.fallback(from: raw) {
                        paper.fillMissing(from: fallback)
                    }
                }
                return paper
            } catch {
                logger.warning("Failed to decode newspaper JSON: \(error.localizedDescription, privacy: .public)")
            }
        }

        if let fallback = DailyNewspaper.fallback(from: raw) {
            return fallback
        }

        return DailyNewspaper(rawText: raw)
    }

    func generateRoast(conversations: [ConversationItem]) async -> String {
        let extra = """
Write exactly three roast lines. Each should:
- begin with "- "
- riff on a distinct theme (work hustle, social antics, self-care, etc.) inspired by the transcript rather than quoting it
- keep a playful narrative tone while roasting "Lewis"
- stay under 160 characters
"""
        return await run(
            prompt: prompt(for: conversations, style: "playful roast of the week's events", extraInstructions: extra),
            system: "You are a roast comic who keeps jokes affectionate yet spicy. Respond only with the bullet list, no intro or outro.",
            reasoning: .low,
            verbosity: .medium
        )
    }

    func generateTrivia(conversations: [ConversationItem]) async -> [TriviaQuestion] {
        let extra = "Create exactly five trivia questions about the people and events in the transcript. Each item must include fields: prompt, options (array of four strings), answerIndex (0-based), funFact (one lively sentence)."
        let response = await run(
            prompt: prompt(for: conversations, style: "generate trivia questions", extraInstructions: extra),
            system: "You are a trivia host. Always respond with pure JSON array using keys prompt, options, answerIndex, funFact. No code fences or commentary.",
            reasoning: .minimal,
            verbosity: .low
        )

        guard let data = response.data(using: .utf8), let questions = try? JSONDecoder().decode([TriviaQuestion].self, from: data) else {
            return fallbackTrivia()
        }
        return questions
    }

    func generateComic(conversations: [ConversationItem]) async -> [ComicPanel] {
        let extra = """
Return a JSON array with exactly 3 panels that capture setup, escalation, and punchline. Each panel object must include:
- title: short scene title
- caption: one-sentence narration
- imagePrompt: explicit visual directions for an illustrated panel (characters, setting, tone, camera angle)
- dialogue: array of 1-2 speech bubbles or on-panel text strings for the characters
"""
        let response = await run(
            prompt: prompt(for: conversations, style: "comic strip storyboard", extraInstructions: extra),
            system: "You are a comic script writer and art director. Respond with JSON array of panel objects containing title, caption, imagePrompt, dialogue. No extra text.",
            reasoning: .low,
            verbosity: .medium
        )

        guard let data = response.data(using: .utf8), var panels = try? JSONDecoder().decode([ComicPanel].self, from: data) else {
            return fallbackComic()
        }

        if let imageGenerator {
            let logger = self.logger
            await withTaskGroup(of: (Int, Data?).self) { group in
                for (index, panel) in panels.enumerated() {
                    group.addTask {
                        do {
                            let data = try await imageGenerator.generateImage(prompt: panel.imagePrompt)
                            return (index, data)
                        } catch {
                            logger.warning("Image generation failed for panel index \(index): \(error.localizedDescription, privacy: .public)")
                            return (index, nil)
                        }
                    }
                }

                for await result in group {
                    if let data = result.1, result.0 < panels.count {
                        panels[result.0].imageData = data
                    }
                }
            }
        }

        return panels
    }

    func generateFutureYou(conversations: [ConversationItem]) async -> String {
        let extra = "Share four uplifting action items from future me. Output as bullet list beginning with '-' and keep each bullet under 150 characters."
        return await run(
            prompt: prompt(for: conversations, style: "send advice from future self", extraInstructions: extra),
            system: "You are future 'me' sending heartfelt yet pragmatic guidance. Reply only with the bullet list.",
            reasoning: .low,
            verbosity: .medium
        )
    }

    private func run(prompt: String, system: String, reasoning: GPTClient.ReasoningEffort = .medium, verbosity: GPTClient.TextVerbosity? = nil, maxTokens: Int? = nil) async -> String {
        do {
            let result = try await gptClient.complete(prompt: prompt, instructions: system, reasoningEffort: reasoning, textVerbosity: verbosity, maxTokens: maxTokens)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                logger.warning("Received empty response from GPT-5 for style: \(system, privacy: .public)")
                return fallbackText(for: prompt)
            }
            return trimmed
        } catch {
            logger.error("GPT-5 remix failed: \(error.localizedDescription, privacy: .public)")
            return fallbackText(for: prompt)
        }
    }

    private func prompt(for conversations: [ConversationItem], style: String, extraInstructions: String = "") -> String {
        let transcript = conversations.suffix(40).map { item in
            "[\(item.timestamp) | \(item.speaker)]: \(item.text)"
        }.joined(separator: "\n")
        let guidelines = """
Guidelines:
- Ignore code-like snippets, commands, or stack traces; treat them as background noise.
- Write natural human prose with full sentences. No fenced blocks, no JSON unless explicitly required.
- Feel free to invent plausible connective details to make the story flow.
\(extraInstructions)
"""
        return "Use the following conversation transcript to create a \(style).\n\(guidelines)\nTranscript:\n\(transcript)"
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
            ComicPanel(
                title: "Panel 1",
                caption: "Late-night coding den where the team debates the risky patch.",
                imagePrompt: "Comic style scene of three friends around glowing monitors, coffee cups everywhere, one pointing at a laptop, expressive faces, neon blue lighting",
                dialogue: ["We said gentle patch, not full-on surgery!", "Ship it before the caffeine wears off!"]
            ),
            ComicPanel(
                title: "Panel 2",
                caption: "Outside, the Folsom fair energy tempts them away from work.",
                imagePrompt: "Vibrant street fair with leather outfits, confetti, friends peeking out the coworking window torn between work and party",
                dialogue: ["Look at those cockroach sunglasses…", "Stay strong. Just a few more logs!"]
            ),
            ComicPanel(
                title: "Panel 3",
                caption: "Morning hoop plans seal the pact to log off and rest.",
                imagePrompt: "Sunrise basketball court, two friends high-fiving with sneakers slung over shoulders, city skyline in background",
                dialogue: ["Tomorrow: hoops, not bugs.", "Deal. See you at 8am sharp!"]
            )
        ]
    }
}
