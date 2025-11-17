import os
import sys
import asyncio
import argparse

# Add the Generator directory to the Python path
generator_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'Generator'))
sys.path.insert(0, generator_dir)

from main import main

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate code from AT Protocol Lexicons')
    parser.add_argument('lexicons_path', help='Path to lexicons directory')
    parser.add_argument('output_path', help='Path to output directory')
    parser.add_argument('--language', choices=['swift', 'kotlin', 'both'], default='swift',
                       help='Target language for code generation (default: swift)')

    args = parser.parse_args()

    asyncio.run(main(args.lexicons_path, args.output_path, args.language))