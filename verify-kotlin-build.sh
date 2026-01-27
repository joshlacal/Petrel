#!/bin/bash

# Petrel Kotlin Build Verification Script
# Verifies that Petrel Kotlin builds successfully, checks for JAR output, and runs tests.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOTLIN_DIR="$SCRIPT_DIR/petrel-kotlin"

echo "================================================"
echo "Petrel Kotlin Build Verification"
echo "================================================"
echo ""

# Check if petrel-kotlin directory exists
if [ ! -d "$KOTLIN_DIR" ]; then
    echo "ERROR: Petrel Kotlin directory not found at $KOTLIN_DIR"
    exit 1
fi

cd "$KOTLIN_DIR"

# Determine gradle command (prefer gradlew if available)
if [ -f "./gradlew" ]; then
    GRADLE_CMD="./gradlew"
else
    GRADLE_CMD="gradle"
fi

echo "Using gradle command: $GRADLE_CMD"
echo ""

echo "Step 1: Cleaning previous build artifacts..."
$GRADLE_CMD clean
echo "✓ Clean completed"
echo ""

echo "Step 2: Building Petrel Kotlin..."
$GRADLE_CMD build --info
echo "✓ Build completed"
echo ""

echo "Step 3: Running tests..."
$GRADLE_CMD test
echo "✓ Tests completed"
echo ""

echo "Step 4: Checking for JAR output..."
JAR_PATH="build/libs/petrel-kotlin-0.1.0.jar"
if [ -f "$JAR_PATH" ]; then
    echo "✓ JAR found at: $JAR_PATH"
    ls -lh "$JAR_PATH"
else
    echo "WARNING: JAR not found at expected path: $JAR_PATH"
    echo "Searching for JAR files in build directory..."
    find build -name "*.jar" -type f
fi
echo ""

echo "Step 5: Verifying publishable artifacts..."
$GRADLE_CMD publishToMavenLocal
echo "✓ Published to Maven Local"
echo ""

echo "================================================"
echo "Build Verification Summary"
echo "================================================"
echo "✓ All checks passed successfully!"
echo ""
echo "Build outputs:"
find build/libs -name "*.jar" -type f 2>/dev/null || echo "No JAR files found"
echo ""
echo "Test results:"
find build/test-results -name "*.xml" -type f 2>/dev/null || echo "No test results found"
echo ""
