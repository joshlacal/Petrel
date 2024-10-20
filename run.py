import os
import sys
import asyncio

# Add the Generator directory to the Python path
generator_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), 'Generator'))
sys.path.insert(0, generator_dir)

from main import main

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python run.py <lexicons_path> <output_path>")
        sys.exit(1)
    
    asyncio.run(main(sys.argv[1], sys.argv[2]))