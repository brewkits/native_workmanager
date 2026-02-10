#!/bin/bash
# Script to quickly start iOS Simulator for Android Studio

echo "🚀 Starting iOS Simulator..."

# Boot iPhone 16 Pro
xcrun simctl boot "iPhone 16 Pro" 2>/dev/null

# Open Simulator app
open -a Simulator

# Wait a bit
sleep 2

# Show available devices
echo ""
echo "✅ Available devices:"
flutter devices

echo ""
echo "💡 Now you can select 'iPhone 16 Pro' in Android Studio!"
echo "   Device Selector → iPhone 16 Pro → Run ▶️"
