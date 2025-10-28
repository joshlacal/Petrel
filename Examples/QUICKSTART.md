# Quick Start Guide for Petrel Examples

## Overview

This directory contains three working examples:

1. **FirehoseDemo.swift** - Simple firehose monitor (no auth required)
2. **SimplePostCLI.swift** - Standalone posting script (no Petrel dependency)
3. **PostCLIDemo** - Full-featured CLI using the Petrel library

## 1. Firehose Monitor (Easiest)

Watch the Bluesky firehose in real-time. No authentication needed!

```bash
cd Examples
swift FirehoseDemo.swift
```

**What you'll see:**
```
🔥 Bluesky Firehose Monitor
Connecting to wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos
Press Ctrl+C to stop

✅ Connected to firehose!

[1] 📦 Received 2048 bytes | Rate: 12.3 events/sec
[2] 📦 Received 1834 bytes | Rate: 11.8 events/sec
[3] 📦 Received 2156 bytes | Rate: 12.1 events/sec
...
```

Press `Ctrl+C` to stop.

---

## 2. Simple Post CLI (No Dependencies)

A standalone script that posts to Bluesky without requiring the Petrel library.

```bash
cd Examples
swift SimplePostCLI.swift
```

**Example session:**
```
📱 Simple Bluesky Poster
========================

Enter your Bluesky handle (e.g., alice.bsky.social):
alice.bsky.social

Enter your app password:
(Generate one at https://bsky.app/settings/app-passwords)
abcd-1234-efgh-5678

🔐 Authenticating...
✅ Logged in as: did:plc:abc123xyz...

📝 Enter your post:
Hello from the Petrel examples! 🎉

⏳ Posting...
✅ Posted successfully!
   URI: at://did:plc:abc123xyz.../app.bsky.feed.post/3k...
   View: https://bsky.app/profile/alice.bsky.social/post/3k...
```

**Note:** You need an app password. Generate one at:
https://bsky.app/settings/app-passwords

---

## 3. Full-Featured Post CLI (Using Petrel)

The complete demo using the Petrel library with multi-line posts and profile viewing.

### First time setup:

```bash
cd Examples/PostCLIDemo
swift build
```

### Run:

```bash
swift run PostCLIDemo
```

**Features:**
- ✅ Multi-line post composition
- ✅ View your profile
- ✅ Character count warnings
- ✅ Interactive menu
- ✅ Full Petrel library integration

**Example session:**
```
📱 Bluesky CLI Poster
=====================

Enter your Bluesky handle (e.g., alice.bsky.social):
alice.bsky.social

Enter your app password:
abcd-1234-efgh-5678

🔐 Authenticating...
✅ Logged in successfully!
   DID: did:plc:abc123xyz...

──────────────────────────────────────────────────
What would you like to do?
1. Post a message
2. View your profile  
3. Exit
──────────────────────────────────────────────────

Choice: 1

📝 Compose your post:
(Press Enter twice to finish, or type 'cancel' to abort)

This is a multi-line post!

It can have multiple paragraphs
and will preserve line breaks.


⏳ Posting...
✅ Post created successfully!
   URI: at://did:plc:abc123xyz.../app.bsky.feed.post/3k...
   View: https://bsky.app/profile/alice.bsky.social/post/3k...
```

---

## Generating an App Password

All the posting examples require an app password. Here's how to get one:

1. **Go to settings:**
   https://bsky.app/settings/app-passwords

2. **Click "Add App Password"**

3. **Give it a name:**
   - "Petrel Examples" or "CLI Tool"

4. **Copy the password:**
   - Format: `abcd-1234-efgh-5678`
   - Save it somewhere - you can't view it again!

5. **Use it in the demos**

**Security tip:** App passwords can be revoked individually without affecting your main password. This makes them perfect for testing and CLI tools!

---

## Troubleshooting

### "swift: command not found"

Install Swift from https://swift.org/download/

### "Invalid credentials" error

- Make sure you're using an **app password**, not your main password
- Verify your handle format: `alice.bsky.social` (not `@alice.bsky.social`)
- Check that the app password hasn't been revoked

### Firehose connection drops

This is normal - the demo will automatically reconnect after 5 seconds.

### Build errors in PostCLIDemo

```bash
cd Examples/PostCLIDemo
swift package clean
swift build
```

If still failing, make sure you're in the correct directory and Swift 5.9+ is installed.

---

## What's Next?

After trying these examples:

1. **Read the full documentation:**
   - `LEGACY_AUTH_EXAMPLE.md` - Detailed auth guide
   - `GETTING_STARTED.md` - Complete library usage
   - `Examples/README.md` - Extended examples documentation

2. **Build your own app:**
   - Use Petrel in your Swift project
   - Implement OAuth for production apps
   - Explore advanced features (feeds, follows, rich text, etc.)

3. **Explore the API:**
   - Browse `Sources/Petrel/Generated/` for all available endpoints
   - Check out the lexicon definitions
   - Build custom integrations

---

## Quick Command Reference

```bash
# Firehose monitor
swift Examples/FirehoseDemo.swift

# Simple post (standalone)
swift Examples/SimplePostCLI.swift

# Full CLI (first time)
cd Examples/PostCLIDemo && swift build && swift run PostCLIDemo

# Full CLI (subsequent runs)
cd Examples/PostCLIDemo && swift run PostCLIDemo
```

---

## Support

- **Issues:** https://github.com/[your-repo]/issues
- **Documentation:** See the `docs/` directory
- **Examples:** This directory

Happy coding! 🎉
