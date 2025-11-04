#!/usr/bin/env python3
"""
Bluesky Firehose Listener
Demonstrates unauthenticated connection to the ATProto firehose
"""

import asyncio
import websockets
import cbor2
from datetime import datetime
from collections import defaultdict
import sys


class FirehoseListener:
    def __init__(self, url="wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos"):
        self.url = url
        self.stats = {
            'total_events': 0,
            'commits': 0,
            'identity': 0,
            'account': 0,
            'posts': 0,
            'likes': 0,
            'follows': 0,
            'reposts': 0,
            'profiles': 0,
        }
        self.start_time = datetime.now()

    def decode_message(self, data):
        """Decode a firehose message from DAG-CBOR format"""
        try:
            # The firehose sends two CBOR objects concatenated:
            # 1. Header with 'op' and 't' (type) fields
            # 2. Payload with the actual message data

            from io import BytesIO

            # Decode the header first
            stream = BytesIO(data)
            header = cbor2.load(stream)

            # Get message type
            message_type = header.get('t', 'unknown')
            op = header.get('op', 1)

            if op == -1:
                # Error message
                error = header.get('error', 'Unknown error')
                return {'type': 'error', 'error': error}

            # Try to decode the payload
            try:
                payload = cbor2.load(stream)
            except:
                payload = {}

            return {
                'type': message_type,
                'payload': payload,
                'op': op
            }
        except Exception as e:
            return {'type': 'decode_error', 'error': str(e)}

    def process_commit(self, payload):
        """Process a commit message and extract operations"""
        operations = []

        # Get repo operations if present
        ops = payload.get('ops', [])

        for op in ops:
            action = op.get('action', 'unknown')
            path = op.get('path', '')

            operations.append({
                'action': action,
                'path': path
            })

            # Update statistics
            if 'app.bsky.feed.post' in path:
                self.stats['posts'] += 1
                rkey = path.split('/')[-1] if '/' in path else 'unknown'
                if self.stats['posts'] % 5 == 0 or self.stats['total_events'] < 100:
                    print(f"📝 {action.upper()} post ({rkey}) | Total: {self.stats['posts']}")

            elif 'app.bsky.feed.like' in path:
                self.stats['likes'] += 1
                if self.stats['likes'] % 10 == 0:
                    print(f"❤️  {action.upper()} like | Total: {self.stats['likes']}")

            elif 'app.bsky.graph.follow' in path:
                self.stats['follows'] += 1
                if self.stats['follows'] % 5 == 0:
                    print(f"👥 {action.upper()} follow | Total: {self.stats['follows']}")

            elif 'app.bsky.feed.repost' in path:
                self.stats['reposts'] += 1
                if self.stats['reposts'] % 10 == 0:
                    print(f"🔄 {action.upper()} repost | Total: {self.stats['reposts']}")

            elif 'app.bsky.actor.profile' in path:
                self.stats['profiles'] += 1
                if self.stats['profiles'] % 20 == 0:
                    print(f"👤 {action.upper()} profile | Total: {self.stats['profiles']}")

        return operations

    def show_statistics(self):
        """Display current statistics"""
        elapsed = (datetime.now() - self.start_time).total_seconds()
        rate = self.stats['total_events'] / max(elapsed, 1.0)

        print("\n" + "=" * 60)
        print(f"📊 STATISTICS after {self.stats['total_events']} events")
        print("=" * 60)
        print(f"⏱️  Rate: {rate:.1f} events/sec")
        print(f"📦 Events: Commits: {self.stats['commits']} | Identity: {self.stats['identity']} | Account: {self.stats['account']}")
        print(f"📝 Posts: {self.stats['posts']}")
        print(f"❤️  Likes: {self.stats['likes']}")
        print(f"👥 Follows: {self.stats['follows']}")
        print(f"🔄 Reposts: {self.stats['reposts']}")
        print(f"👤 Profiles: {self.stats['profiles']}")
        print("=" * 60 + "\n")

    async def listen(self):
        """Connect to the firehose and listen for events"""
        print("🔥 Petrel Firehose Listener (Python)")
        print("=" * 60)
        print(f"Connecting to {self.url}")
        print("Press Ctrl+C to stop\n")

        while True:
            try:
                async with websockets.connect(self.url, ping_interval=30) as websocket:
                    print("✅ Connected to firehose!\n")

                    async for message in websocket:
                        self.stats['total_events'] += 1

                        # Decode the message
                        decoded = self.decode_message(message)

                        message_type = decoded.get('type', 'unknown')

                        if message_type == '#commit':
                            self.stats['commits'] += 1
                            payload = decoded.get('payload', {})
                            self.process_commit(payload)

                        elif message_type == '#identity':
                            self.stats['identity'] += 1
                            if self.stats['identity'] % 10 == 0 or self.stats['total_events'] < 50:
                                print("🆔 Identity update event")

                        elif message_type == '#account':
                            self.stats['account'] += 1
                            if self.stats['account'] % 10 == 0 or self.stats['total_events'] < 50:
                                print("👤 Account update event")

                        elif message_type == 'error':
                            print(f"❌ Error from server: {decoded.get('error')}")

                        elif message_type == 'decode_error':
                            if self.stats['total_events'] < 10:
                                print(f"⚠️  Decode error: {decoded.get('error')}")

                        # Show periodic statistics
                        if self.stats['total_events'] % 100 == 0:
                            self.show_statistics()

            except websockets.exceptions.ConnectionClosed:
                print("\n⚠️  Connection closed. Reconnecting in 5 seconds...")
                await asyncio.sleep(5)

            except KeyboardInterrupt:
                print("\n\n👋 Shutting down firehose listener...")
                break

            except Exception as e:
                print(f"\n❌ Error: {e}")
                print("🔄 Reconnecting in 5 seconds...")
                await asyncio.sleep(5)


async def main():
    listener = FirehoseListener()
    await listener.listen()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
        sys.exit(0)
