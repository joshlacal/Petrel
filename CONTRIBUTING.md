# Contributing to Petrel

Thank you for your interest in contributing to Petrel! This guide will help you get started with contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Generation](#code-generation)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Code Style](#code-style)
- [Documentation](#documentation)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Respect differing viewpoints and experiences

## Getting Started

1. **Fork the Repository**
   - Visit [https://github.com/joshlacal/Petrel](https://github.com/joshlacal/Petrel)
   - Click the "Fork" button in the top right
   - Clone your fork locally

2. **Set Up Your Development Environment**
   ```bash
   # Clone your fork
   git clone https://github.com/YOUR_USERNAME/Petrel.git
   cd Petrel
   
   # Add upstream remote
   git remote add upstream https://github.com/joshlacal/Petrel.git
   
   # Create a new branch for your feature
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- **Xcode 16.0+** with Swift 6.0+
- **Python 3.8+** (for code generation)
- **Git** for version control

### Building the Project

```bash
# Build the Swift package
swift build

# Run tests
swift test

# Generate documentation
swift package generate-documentation
```

### Setting Up Code Generation

The code generator requires Python with Jinja2:

```bash
# Install Python dependencies
cd Generator
pip install -r requirements.txt
```

## Code Generation

Petrel uses automated code generation from AT Protocol Lexicon files. Understanding this process is crucial for contributing.

### How Code Generation Works

1. **Lexicon Files**: JSON definitions from the AT Protocol spec are stored in `Generator/lexicons/`
2. **Templates**: Jinja2 templates in `Generator/templates/` define the Swift code structure
3. **Generator**: Python scripts process Lexicons and generate Swift files
4. **Output**: Generated files are placed in `Sources/Petrel/Generated/`

### Updating Generated Code

```bash
# Run the generator
cd Petrel
python Generator/main.py

# Or use the convenience script
python run.py Generator/lexicons Sources/Petrel/Generated
```

### Adding New Lexicons

1. Add new Lexicon JSON files to `Generator/lexicons/`
2. Run the generator
3. Commit both the Lexicon files and generated Swift code

### Modifying Templates

If you need to change how code is generated:

1. Edit templates in `Generator/templates/`
2. Test thoroughly with existing Lexicons
3. Regenerate all code and ensure tests pass

## Making Changes

### Types of Contributions

- **Bug Fixes**: Fix issues in existing functionality
- **New Features**: Add support for new AT Protocol features
- **Performance**: Optimize existing code
- **Documentation**: Improve guides, API docs, or code comments
- **Tests**: Add missing test coverage

### Development Workflow

1. **Update your fork**
   ```bash
   git checkout main
   git pull upstream main
   git push origin main
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature
   ```

3. **Make your changes**
   - Write clean, documented code
   - Follow the existing code style
   - Add tests for new functionality

4. **Test your changes**
   ```bash
   swift test
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter TestClassName

# Run with verbose output
swift test --verbose
```

### Writing Tests

- Place tests in `Tests/PetrelTests/`
- Follow the naming convention: `YourFeatureTests.swift`
- Use XCTest framework
- Mock network calls when testing API methods

Example test structure:

```swift
import XCTest
@testable import Petrel

final class YourFeatureTests: XCTestCase {
    func testFeatureBehavior() async throws {
        // Arrange
        let client = ATProtoClient()
        
        // Act
        let result = try await client.someMethod()
        
        // Assert
        XCTAssertEqual(result.expected, actualValue)
    }
}
```

### Test Coverage

- Aim for high test coverage for new features
- Test edge cases and error conditions
- Ensure async/await code is properly tested

## Submitting Pull Requests

### Before Submitting

1. **Ensure all tests pass**
2. **Update documentation** if needed
3. **Run SwiftLint** if available
4. **Rebase on latest main** to avoid conflicts

### Pull Request Process

1. **Create the PR**
   - Use a clear, descriptive title
   - Reference any related issues (#123)
   - Describe what changes you made and why

2. **PR Description Template**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   
   ## Testing
   - [ ] Tests pass locally
   - [ ] Added new tests
   - [ ] Updated documentation
   
   ## Related Issues
   Fixes #123
   ```

3. **Code Review**
   - Respond to feedback constructively
   - Make requested changes promptly
   - Ask for clarification if needed

## Code Style

### Swift Style Guide

- Use Swift 6.0 features appropriately
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Keep functions focused and small

### Specific Guidelines

1. **Async/Await**
   ```swift
   // Good
   func fetchProfile() async throws -> Profile
   
   // Avoid
   func fetchProfile(completion: @escaping (Result<Profile, Error>) -> Void)
   ```

2. **Error Handling**
   ```swift
   // Use specific error types
   throw NetworkError.unauthorized
   
   // Not generic errors
   throw NSError(domain: "error", code: 0)
   ```

3. **Naming Conventions**
   ```swift
   // Types: UpperCamelCase
   struct UserProfile { }
   
   // Functions/variables: lowerCamelCase
   func getUserProfile() { }
   let userName = "Alice"
   ```

4. **Documentation**
   ```swift
   /// Fetches a user profile from the AT Protocol network
   /// - Parameter handle: The user's handle (e.g., "alice.bsky.social")
   /// - Returns: The user's profile information
   /// - Throws: `NetworkError` if the request fails
   func getProfile(handle: String) async throws -> Profile
   ```

## Documentation

### Code Documentation

- Add doc comments to all public APIs
- Use Xcode's documentation format
- Include examples where helpful

### Updating Guides

When adding features, update:
- `README.md` for major features
- `GETTING_STARTED.md` for usage examples
- `API_REFERENCE.md` for new APIs
- DocC documentation in `Sources/Petrel/Petrel.docc/`

### Documentation Style

- Be clear and concise
- Include code examples
- Explain the "why" not just the "what"
- Keep examples up-to-date

## Reporting Issues

### Before Creating an Issue

- Search existing issues to avoid duplicates
- Try to reproduce with the latest version
- Gather relevant information

### Issue Template

```markdown
## Description
Clear description of the issue

## Steps to Reproduce
1. Step one
2. Step two
3. ...

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Petrel Version: 
- Swift Version:
- Xcode Version:
- Platform: iOS/macOS
- OS Version:

## Code Sample
```swift
// Minimal code to reproduce
```

## Additional Context
Any other relevant information
```

### Feature Requests

- Explain the use case
- Provide examples
- Consider implementation approach
- Be open to alternatives

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Create an Issue
- **Ideas**: Start a Discussion first
- **Security**: Email security concerns privately

## Recognition

Contributors will be recognized in:
- The project README
- Release notes for significant contributions
- Special thanks in documentation

## License

By contributing, you agree that your contributions will be licensed under the same MIT license as the project.

---

Thank you for contributing to Petrel! Your efforts help make AT Protocol accessible to the Swift community. 🐦