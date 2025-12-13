# Castle – Firebase Setup Guide

## 1. Create Firebase Project

```bash
# Login to Firebase
firebase login

# Create a new project (or use existing)
firebase projects:create castle-app
# Or choose from existing: firebase projects:list
```

## 2. Initialize Firebase in Castle

```bash
cd /Users/hariprasanna/Workspace/castle
firebase init

# Select:
# - Firestore
# - Functions
# - Storage
# Use existing files when prompted
```

## 3. Register iOS App

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click "+ Add app" → iOS
4. Enter bundle ID: `com.mostlycached.castle`
5. Download `GoogleService-Info.plist`
6. Save to: `/Users/hariprasanna/Workspace/castle/castle/GoogleService-Info.plist`

## 4. Set Gemini API Key

```bash
cd /Users/hariprasanna/Workspace/castle
firebase functions:secrets:set GEMINI_API_KEY
# Paste your Gemini API key when prompted
```

## 5. Deploy Functions & Rules

```bash
cd /Users/hariprasanna/Workspace/castle/functions
npm install
cd ..
firebase deploy
```

## 6. Regenerate Xcode Project

```bash
cd /Users/hariprasanna/Workspace/castle
xcodegen generate
open castle.xcodeproj
```

## 7. Run the App
Press ⌘R in Xcode to build and run in Simulator.
