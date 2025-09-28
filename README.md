# Memory Playground 🎭✨

**Transform Your Digital Memories Into Playful Remixes**
A native macOS app that turns your iMessages and voice conversations into creative, entertaining content powered by GPT-5.

---

## ✨ Features

Memory Playground transforms your everyday conversations into five unique remix formats:

### 📰 **The Daily Newspaper**
Your messages become breaking news! Complete with:
- Dramatic headlines from your actual conversations
- Multiple story sections with proper newspaper layout
- Quote of the Day pulled from your messages
- Gossip column featuring your social highlights
- Beautiful serif typography and classic newspaper styling

### 🎯 **Roast My Week**
Get lovingly roasted by AI that knows your habits:
- Three perfectly-timed roast bubbles
- Personalized burns based on your actual conversations
- Interactive "Hit me again" for fresh roasts
- Visual layout with your profile at the center

### 🎲 **Context Trivia**
Jeopardy-style questions from your inside jokes:
- Five trivia cards per generation
- Questions only your friends would understand
- Click-to-reveal answers
- Perfect for game night with friends

### 🎨 **Comic Generator**
Your week becomes a graphic novel:
- Multi-panel comic strips
- Scene descriptions and dialogue bubbles
- Swipeable panels with page navigation
- Characters and situations from your messages

### 🔮 **Future You**
Receive wisdom from your 70-year-old self:
- Personalized advice based on current patterns
- Three key insights per message
- Optional aged portrait generation
- Surprisingly insightful and touching

---

## 🎯 Additional Features

### 💬 **Text Messages Browser**
- Browse all your iMessage conversations
- View full conversation threads
- See message counts and previews
- Smart contact grouping

### 🎙️ **Voice Conversations** (with Omi device)
- Integration with Omi wearable transcripts
- Browse voice conversation summaries
- View detailed segments and plugin data
- Seamless mixing with text messages

### 🔄 **Real-time Refresh**
- Individual refresh buttons for each remix
- Global refresh from dashboard
- Instant regeneration of content
- New perspectives with every refresh

---

## 🛠️ Tech Stack

### Core Technologies
- **SwiftUI** - Native macOS app with beautiful, responsive UI
- **SQLite** - Direct iMessage database access
- **OpenAI GPT-5 API** - Advanced content generation and remixing
- **NSKeyedUnarchiver** - Parsing NSAttributedString message data

### Architecture Highlights
- **MVVM Pattern** - Clean separation of concerns
- **Async/Await** - Modern Swift concurrency
- **Structured Data Models** - Type-safe remix content
- **Local Processing** - Privacy-first design

### Optional Integrations
- **Omi Wearable** - Voice conversation capture
- **Supabase** - Voice transcript storage
- **DALL-E** - Future portrait generation

---

## 🚀 Getting Started

### Prerequisites
- macOS 13.0 or later
- Xcode 15.0 or later
- OpenAI API key with GPT-5 access

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/luscious-lew/memory_playground.git
cd memory_playground/MemoryPlayground
```

2. **Open in Xcode**
```bash
open MemoryPlayground.xcodeproj
```

3. **Configure API Keys**
Create environment variables in Xcode scheme or use a `.env` file:
```
OPENAI_API_KEY=your-api-key-here
OPENAI_ORG_ID=your-org-id (optional)
SUPABASE_ANON_KEY=your-key (optional, for voice features)
```

4. **Grant Permissions**
- Build and run the app
- Grant Full Disk Access when prompted (System Settings → Privacy & Security)
- This allows the app to read your iMessage database

5. **Start Remixing!**
- Click Refresh to load your messages
- Explore each remix format
- Regenerate content anytime

---

## 🔐 Privacy & Security

- **Local First**: All message processing happens on your device
- **No Data Storage**: We don't store or transmit your messages
- **API Calls Only**: Only generated prompts are sent to OpenAI
- **Full Disk Access**: Required only for iMessage database reading
- **Open Source**: Full transparency in how your data is handled

---

## 📸 Screenshots

### Dashboard
Beautiful gradient UI with remix tiles and real-time status updates

### Newspaper View
Professional newspaper layout with your conversations as news stories

### Roast View
Three-bubble roast layout with your profile photo at the center

### Future You
Wisdom from your future self with optional aged portrait

---

## 🎮 Demo Tips

### Best Practices
- Have at least 100+ messages for best results
- Include variety in conversation partners
- More history = better remixes
- Each refresh creates unique content

### Quick Demo Script
1. Launch app → Show beautiful dashboard
2. Click Daily Newspaper → "Your life as breaking news"
3. Navigate to Roast → "AI that knows your habits"
4. Show Context Trivia → "Inside jokes as game questions"
5. End with Future You → "Advice from tomorrow"

---

## 🤝 Contributing

We welcome contributions! Areas of interest:
- Additional remix formats
- WhatsApp/Telegram integration
- Windows/Linux ports
- UI/UX improvements
- Performance optimizations

---

## 📝 License

Open source

---

## 🙏 Acknowledgments

- Built for the GPT-5 Startup Hackathon NYC
- Powered by OpenAI's GPT-5 API
- Voice features via Omi wearable

---

## 🔗 Links

- [GitHub Repository](https://github.com/luscious-lew/memory_playground)
- [Demo Video](https://youtu.be/cw82zSpXozk)
- [OpenAI GPT-5](https://openai.com)
- [Omi Wearable](https://omi.me)
