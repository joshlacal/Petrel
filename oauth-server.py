#!/usr/bin/env python3

import http.server
import socketserver
import json
import os
from urllib.parse import urlparse

PORT = 8080

class OAuthMetadataHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Parse the URL
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/' or parsed_path.path == '/client-metadata.json':
            # Serve the client metadata
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            # Read and serve the client metadata
            with open('oauth-client-metadata.json', 'r') as f:
                metadata = json.load(f)
            
            self.wfile.write(json.dumps(metadata, indent=2).encode())
            
        elif parsed_path.path == '/callback':
            # Handle OAuth callback - show the URL that needs to be copied
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            callback_url = f"http://127.0.0.1:8080{self.path}"
            
            html = f"""
            <!DOCTYPE html>
            <html>
            <head>
                <title>OAuth Callback - Petrel Load Test</title>
                <style>
                    body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; }}
                    .callback-url {{ background: #f5f5f5; padding: 20px; border-radius: 8px; word-break: break-all; font-family: monospace; }}
                    .copy-button {{ background: #007AFF; color: white; border: none; padding: 10px 20px; border-radius: 6px; cursor: pointer; margin-top: 10px; }}
                </style>
            </head>
            <body>
                <h1>OAuth Callback Received</h1>
                <p>Copy the URL below and use it with the <code>--oauth-complete</code> command:</p>
                <div class="callback-url" id="callbackUrl">{callback_url}</div>
                <button class="copy-button" onclick="copyToClipboard()">Copy URL</button>
                
                <h2>Next Step:</h2>
                <p>Run this command in your terminal:</p>
                <pre>swift run PetrelLoad --namespace josh.uno.oauth --endpoint app.bsky.actor.getProfile --oauth-complete "{callback_url}"</pre>
                
                <script>
                function copyToClipboard() {{
                    const url = document.getElementById('callbackUrl').textContent;
                    navigator.clipboard.writeText(url).then(function() {{
                        alert('URL copied to clipboard!');
                    }});
                }}
                </script>
            </body>
            </html>
            """
            
            self.wfile.write(html.encode())
            
        else:
            # Default behavior for other requests
            super().do_GET()

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    with socketserver.TCPServer(("", PORT), OAuthMetadataHandler) as httpd:
        print(f"OAuth server running at http://localhost:{PORT}")
        print(f"Client metadata available at http://localhost:{PORT}/client-metadata.json")
        print("Starting ngrok in the background...")
        
        # Start ngrok to expose the server
        import subprocess
        ngrok_process = subprocess.Popen([
            'ngrok', 'http', str(PORT), '--log=stdout'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        print("Server ready. Press Ctrl+C to stop.")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")
            ngrok_process.terminate()
            httpd.shutdown()