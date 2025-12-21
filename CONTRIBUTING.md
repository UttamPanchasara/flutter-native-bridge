# Contributing to Flutter Native Bridge

Thanks for your interest in contributing!

## How to Contribute

### Reporting Bugs

- Open an issue on [GitHub Issues](https://github.com/UttamPanchasara/flutter-native-bridge/issues)
- Include steps to reproduce, expected vs actual behavior
- Mention your Flutter version and platform (Android/iOS)

### Suggesting Features

- Open an issue with the "feature request" label
- Describe the use case and proposed solution

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`flutter test`)
5. Commit with clear messages
6. Push and open a Pull Request

### Development Setup

```bash
# Clone the repo
git clone https://github.com/UttamPanchasara/flutter-native-bridge.git
cd flutter-native-bridge

# Get dependencies
flutter pub get

# Run tests
flutter test

# Test code generator
cd example
dart run flutter_native_bridge:generate
```

### Code Style

- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` before submitting

## Questions?

Open an issue or reach out via GitHub.
