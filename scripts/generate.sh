#!/bin/bash
# Flutter Native Bridge - Single Command Code Generation
# This script handles both Android KSP processing and Dart code generation

set -e

echo "🚀 Flutter Native Bridge - Code Generation"
echo "==========================================="

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Must be run from Flutter project root"
    exit 1
fi

# Step 1: Build Android to trigger KSP processor
echo ""
echo "📱 Step 1: Running KSP processor (Android)..."
cd android
./gradlew assembleDebug -q
cd ..

# Check if metadata was generated
METADATA_FILE="android/app/build/generated/ksp/debug/resources/native_bridge_metadata.json"
if [ ! -f "$METADATA_FILE" ]; then
    echo "⚠️  Warning: No metadata file generated. No native bridges found."
    exit 0
fi

echo "✅ Metadata generated successfully"

# Step 2: Run Dart code generator
echo ""
echo "🎯 Step 2: Generating Dart code..."
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "✅ Code generation complete!"
echo ""
echo "📝 Generated files:"
echo "   - lib/generated/native_bridge.g.dart"
echo ""
echo "You can now use your native bridges in Dart! 🎉"
