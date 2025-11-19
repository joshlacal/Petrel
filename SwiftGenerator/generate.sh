#!/bin/bash

# Wrapper script to build and run the Swift generator

set -e

echo "Building Swift generator..."
swift build -c release

echo "Running generator..."
.build/release/swift-generator ../Generator/lexicons ../Sources/Petrel/Generated

echo "Done!"
