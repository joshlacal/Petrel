# Petrel Examples

This directory contains example applications demonstrating how to use Petrel for various Bluesky/ATProto tasks.

## Examples

### 1. FirehoseDemo.swift

A simple standalone script that connects to the Bluesky firehose and displays real-time events.

**Features:**
- No authentication required
- WebSocket connection to the firehose
- Real-time event monitoring
- Automatic reconnection on errors

**Usage:**
```bash
cd Examples
swift FirehoseDemo.swift
```

**What you'll see:**
- Real-time stream of events from the Bluesky network
- Event rate statistics
- Binary data packets from the firehose

**Note:** This is a simplified demo. For production use, you'd want to properly decode the DAG-CBOR messages using the full Petrel library.

---

### 2. PostCLIDemo

A complete CLI application for posting to Bluesky using app password authentication.

**Features:**
- App password authentication (legacy auth)
- Post creation with multi-line support
- Profile viewing
- Interactive menu system
- Character count warnings

**Setup:**
```bash
cd Examples/PostCLIDemo
swift build
```

**Usage:**
```bash
swift run PostCLIDemo
```

**Interactive prompts:**
1. Enter your Bluesky handle (e.g., `alice.bsky.social`)
2. Enter your app password (generate one at https://bsky.app/settings/app-passwords)
3. Choose from menu:
   - Post a message
   - View your profile
   - Exit

**Creating a post:**
- Type your message (supports multiple lines)
- Press Enter twice to finish
- Type `cancel` to abort

**Example session:**
```
📱 Bluesky CLI Poster
=====================

Enter your Bluesky handle (e.g., alice.bsky.social):
alice.bsky.social

Enter your app password:
(Generate one at https://bsky.app/settings/app-passwords)
****-****-****-****

🔐 Authenticating...
✅ Logged in successfully!
   DID: did:plc:abc123...

──────────────────────────────────────────────────
What would you like to do?
1. Post a message
2. View your profile
3. Exit
──────────────────────────────────────────────────

Choice: 1

📝 Compose your post:
(Press Enter twice to finish, or type 'cancel' to abort)

Hello from the Petrel CLI! 🎉


⏳ Posting...
✅ Post created successfully!
   URI: at://did:plc:abc123.../app.bsky.feed.post/3k...
   View: https://bsky.app/profile/alice.bsky.social/post/3k...
```

---

## Requirements

- Swift 5.9 or later
- macOS 13.0+ (for PostCLIDemo)
- Linux (for FirehoseDemo standalone script)

## Security Notes

### App Passwords

⚠️ **Important:** Never use your main account password! Always use app-specific passwords.

**How to generate an app password:**
1. Go to https://bsky.app/settings/app-passwords
2. Click "Add App Password"
3. Give it a descriptive name (e.g., "Petrel CLI")
4. Copy the generated password
5. Use it in the CLI demo

**App password benefits:**
- Can be revoked individually without affecting your main password
- Limited scope (cannot change account settings)
- More secure for automation and scripts

### Credential Storage

These demos do NOT store credentials. You must enter them each time you run the app. For production apps, consider:

- Using OAuth instead of app passwords
- Storing tokens securely in Keychain (the Petrel library does this automatically)
- Implementing proper credential management

---

## Building for Production

These are simple demos for learning. For production apps:

1. **Use OAuth instead of app passwords:**
   ```swift
   let url = try await client.startOAuthFlow(identifier: "alice.bsky.social")
   // Present URL to user in browser
   // Handle callback
   try await client.handleOAuthCallback(url: callbackURL)
   ```

2. **Handle errors gracefully:**
   - Network failures
   - Rate limiting
   - Token expiration
   - Invalid credentials

3. **Add proper firehose parsing:**
   - Use DAG-CBOR decoder
   - Parse commit messages
   - Handle different event types
   - Filter for specific content

4. **Implement rate limiting:**
   - Respect API limits
   - Add backoff strategies
   - Handle 429 responses

---

## Common Issues

### "Invalid credentials" error
- Make sure you're using an app password, not your main password
- Verify your handle format (e.g., `alice.bsky.social` not `@alice.bsky.social`)
- Check that the app password hasn't been revoked

### Firehose connection drops
- This is normal - the demo will automatically reconnect
- Network issues may cause temporary disconnections
- The firehose may restart during server maintenance

### Build errors
- Ensure you're using Swift 5.9 or later: `swift --version`
- Clean build folder: `swift package clean`
- Update dependencies: `swift package update`

---

## Next Steps

After trying these demos, explore:

1. **Full Petrel Integration:**
   - Import Petrel in your own projects
   - Use the complete API (feeds, profiles, follows, etc.)
   - Implement OAuth for better security

2. **Advanced Features:**
   - Rich text with facets (mentions, links, hashtags)
   - Image uploads
   - Thread/reply handling
   - Custom feeds

3. **Documentation:**
   - See `LEGACY_AUTH_EXAMPLE.md` for detailed authentication docs
   - Check `GETTING_STARTED.md` for full library usage
   - Read the API reference for all available methods

---

## Contributing

Found a bug or want to improve these examples? Pull requests welcome!

## License

These examples are provided as-is for educational purposes. See the main Petrel library license for details.
