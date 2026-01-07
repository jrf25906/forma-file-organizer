#!/bin/bash
# Script to check saved security-scoped bookmarks for Forma

echo "🔍 Checking Forma's saved bookmarks..."
echo ""

BUNDLE_ID="com.jamesfarmer.Forma-File-Organizing"

# Check if any bookmarks exist
BOOKMARK_COUNT=$(defaults read $BUNDLE_ID 2>/dev/null | grep -c "DestinationFolderBookmark_")

if [ $? -ne 0 ] || [ $BOOKMARK_COUNT -eq 0 ]; then
    echo "❌ No destination folder bookmarks found."
    echo ""
    echo "This means you haven't granted permission to any destination folders yet."
    echo "The first time you try to organize a file, you'll be prompted to select the destination folder."
    exit 0
fi

echo "✅ Found destination folder bookmarks:"
echo ""

# List all bookmark keys
defaults read $BUNDLE_ID 2>/dev/null | grep "DestinationFolderBookmark_" | while read -r line; do
    KEY=$(echo "$line" | cut -d'"' -f2)
    FOLDER_NAME=$(echo "$KEY" | sed 's/DestinationFolderBookmark_//')
    echo "  📁 $FOLDER_NAME"
done

echo ""
echo "💡 To reset bookmarks (if they're pointing to wrong folders):"
echo ""
echo "   defaults delete $BUNDLE_ID DestinationFolderBookmark_Pictures"
echo "   defaults delete $BUNDLE_ID DestinationFolderBookmark_Documents"
echo "   # ... etc for each folder"
echo ""
echo "Or reset all at once:"
echo "   defaults delete $BUNDLE_ID"
echo ""
echo "After resetting, restart the app and you'll be prompted to select folders again."
