#!/bin/bash

# Full Disk Access Setup Script for MemoryPlayground Development
# This script helps configure Full Disk Access for the development build

echo "═══════════════════════════════════════════════════════════════"
echo "    Memory Playground - Full Disk Access Setup for Development"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Get the path to the built app
APP_PATH="/Users/lewisclements/memory_playground/MemoryPlayground/BuildProducts/Debug/MemoryPlayground.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at: $APP_PATH"
    echo "Please build the app in Xcode first."
    exit 1
fi

echo "📱 App found at: $APP_PATH"
echo ""

# Check if we can read the chat.db file
CHAT_DB="$HOME/Library/Messages/chat.db"
if [ -r "$CHAT_DB" ]; then
    echo "✅ Full Disk Access appears to be working!"
    echo "   Can read: $CHAT_DB"
else
    echo "⚠️  Cannot read iMessage database at: $CHAT_DB"
    echo ""
    echo "To grant Full Disk Access to the development build:"
    echo ""
    echo "1. Open System Settings → Privacy & Security → Full Disk Access"
    echo ""
    echo "2. Click the + button to add an app"
    echo ""
    echo "3. Navigate to:"
    echo "   $APP_PATH"
    echo ""
    echo "4. Select MemoryPlayground.app and click Open"
    echo ""
    echo "5. Make sure the toggle is ON for MemoryPlayground"
    echo ""
    echo "6. You may need to quit and restart the app from Xcode"
    echo ""
    echo "Press Enter to open System Settings..."
    read

    # Open System Settings to the Full Disk Access pane
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Alternative Method: Run from a fixed location"
echo ""
echo "1. Build the app in Xcode (Cmd+B)"
echo "2. Right-click on MemoryPlayground.app in Products folder"
echo "3. Select 'Show in Finder'"
echo "4. Copy the app to /Applications"
echo "5. Grant Full Disk Access to /Applications/MemoryPlayground.app"
echo "6. Run the app from /Applications instead of Xcode"
echo ""
echo "This ensures the app always runs from the same location."
echo "═══════════════════════════════════════════════════════════════"