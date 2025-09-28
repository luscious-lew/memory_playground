import SwiftUI

struct NewspaperView: View {
    let newspaper: DailyNewspaper?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mastheadSection
                if let content = structuredContent {
                    leadSection(content)
                    Divider()
                        .padding(.vertical, 8)
                    contentColumns(content)
                } else {
                    fallbackLayout
                }
            }
            .padding(48)
            .background(Color.white)
        }
        .background(Color(white: 0.9))
        .navigationTitle("Daily Newspaper")
    }

    private var mastheadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text((structuredContent?.masthead ?? "The Lewis Times").uppercased())
                .font(.system(size: 56, weight: .heavy, design: .serif))
                .foregroundStyle(.black)
                .tracking(3)
            if let lead = structuredContent?.leadStory ?? structuredContent?.featureStories.first {
                Text(lead.headline)
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(.black)
                if !lead.subheadline.isEmpty {
                    Text(lead.subheadline)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Breaking: Waiting for GPT-5 to file the story.")
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundStyle(.black)
            }
            Divider()
                .padding(.top, 0)
        }
    }

    private func leadSection(_ content: DailyNewspaper) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lead story is already shown in masthead, so show additional content or skip this section
            if let lead = content.leadStory ?? content.featureStories.first {
                VStack(alignment: .leading, spacing: 0) {
                    if !lead.subheadline.isEmpty {
                        Text(lead.subheadline)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(.secondary)
                    }

                    let paragraphs = paragraphs(from: lead.body)
                    if paragraphs.isEmpty {
                        Text(lead.body)
                            .font(.system(size: 17, design: .serif))
                            .foregroundStyle(.black)
                            .lineSpacing(5)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(paragraphs, id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(.system(size: 17, design: .serif))
                                    .foregroundStyle(.black)
                                    .lineSpacing(5)
                            }
                        }
                    }
                }
            }
        }
    }

    private func contentColumns(_ content: DailyNewspaper) -> some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(alignment: .leading, spacing: 16) {
                let secondaryStories = secondaryStories(from: content)
                if secondaryStories.isEmpty {
                    Text("Trending Threads")
                        .font(.title3.bold())
                        .foregroundStyle(.black)
                    Text("Waiting on the newsroom wire for more stories.")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                } else {
                    // Hidden: More Stories heading

                    ForEach(secondaryStories) { story in
                        storyCard(for: story, emphasis: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            sidebar(for: content)
        }
    }

    private func storyCard(for story: DailyNewspaper.Story, emphasis: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(story.headline)
                .font(emphasis ? .system(size: 28, weight: .bold, design: .serif)
                               : .system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(.black)
            if !story.subheadline.isEmpty {
                Text(story.subheadline)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(.secondary)
            }

            let paragraphs = paragraphs(from: story.body)
            if paragraphs.isEmpty {
                Text(story.body)
                    .font(.system(size: 17, design: .serif))
                    .foregroundStyle(.black)
                    .lineSpacing(5)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(size: 17, design: .serif))
                            .foregroundStyle(.black)
                            .lineSpacing(5)
                    }
                }
            }
        }
    }

    private func sidebar(for content: DailyNewspaper) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let quote = content.quoteOfDay {
                Text("Quote of the Day")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.black)
                Text("\"\(quote.text)\"")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(.black)
                    .italic()
                if let attribution = quote.attribution, !attribution.isEmpty {
                    Text("— \(attribution)")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.secondary)
                }
                Divider()
            }

            if let gossip = content.gossipColumn {
                Text(gossip.headline)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(.black)
                let gossipParagraphs = paragraphs(from: gossip.body)
                if gossipParagraphs.isEmpty {
                    Text(gossip.body)
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(.black)
                        .lineSpacing(4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(gossipParagraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.system(size: 17, design: .serif))
                                .foregroundStyle(.black)
                                .lineSpacing(4)
                        }
                    }
                }
            }

            if content.quoteOfDay == nil && content.gossipColumn == nil {
                Text("Newsroom desk is still gathering quotes and gossip.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 280, alignment: .leading)
    }

    private var fallbackLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No copy filed yet — showing raw response:")
                .font(.headline)
                .foregroundStyle(.black)
            Text(newspaper?.rawText ?? "Remix placeholder because GPT-5 is not reachable.")
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(.black)
                .lineSpacing(4)
        }
    }

    private var structuredContent: DailyNewspaper? {
        guard let paper = newspaper else { return nil }
        if paper.leadStory != nil || !paper.featureStories.isEmpty {
            return paper
        }
        return nil
    }

    private func paragraphs(from text: String) -> [String] {
        text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func secondaryStories(from content: DailyNewspaper) -> [DailyNewspaper.Story] {
        var stories: [DailyNewspaper.Story] = []

        if let lead = content.leadStory {
            stories.append(contentsOf: content.featureStories.filter { story in
                !(story.headline == lead.headline && story.subheadline == lead.subheadline)
            })
        } else {
            stories.append(contentsOf: content.featureStories.dropFirst())
        }

        return Array(stories.prefix(3))
    }
}
