import SwiftUI

struct NewspaperView: View {
    let newspaper: String

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headlineSection
                articleColumns
            }
            .padding(48)
            .background(Color.white)
        }
        .background(Color(white: 0.9))
        .navigationTitle("Daily Newspaper")
    }

    private var lines: [String] {
        newspaper.split(separator: "\n").map(String.init)
    }

    private var headlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playground Press")
                .font(.system(size: 52, weight: .heavy, design: .serif))
                .tracking(2)
            Text(lines.first ?? "Breaking: Waiting for GPT-5 to file the story.")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundStyle(.black)
                .padding(.bottom, 4)
            Divider()
        }
    }

    private var articleColumns: some View {
        let paragraphs = Array(lines.dropFirst())
        return VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trending Threads")
                        .font(.title3.bold())
                    ForEach(paragraphs.prefix(3), id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(4)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quote of the Day")
                        .font(.title3.bold())
                    Text(paragraphs.dropFirst(3).first ?? "\"More coffee, less chaos.\"")
                        .font(.system(.headline, design: .serif))
                        .italic()
                    Divider()
                    Text("Gossip Column")
                        .font(.title3.bold())
                    Text(paragraphs.dropFirst(4).first ?? "Rumor has it the Omi wearable is starting a stand-up career.")
                        .font(.system(.body, design: .serif))
                        .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
