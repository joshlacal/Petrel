import os
import sys
import asyncio
import argparse

# Add the Generator directory to the Python path
generator_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'generator'))
sys.path.insert(0, generator_dir)

from main import main, run_manifest

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate code from AT Protocol Lexicons')
    parser.add_argument('lexicons_path', nargs='?', help='Path to lexicons directory (legacy CLI)')
    parser.add_argument('output_path', nargs='?', help='Path to output directory (legacy CLI)')
    parser.add_argument('--manifest', help='Path to a generation manifest JSON (replaces positional args)')
    parser.add_argument('--language', choices=['swift', 'kotlin', 'both'], default=None,
                       help='Target language for code generation (default: swift for legacy CLI, both for --manifest)')

    args = parser.parse_args()

    if args.manifest:
        default_graph = os.path.join(generator_dir, 'package-graph.json')
        graph_path = default_graph if os.path.exists(default_graph) else None
        asyncio.run(run_manifest(args.manifest, args.language or 'both', graph_path=graph_path))
    elif args.lexicons_path and args.output_path:
        asyncio.run(main(args.lexicons_path, args.output_path, args.language or 'swift'))
    else:
        parser.error('provide either --manifest <file> or <lexicons_path> <output_path>')
