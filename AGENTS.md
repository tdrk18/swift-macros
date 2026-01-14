# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` defines a SwiftPM package with two targets and tests.
- `Sources/MacroImplements` contains macro implementations and compiler plugin wiring.
- `Sources/MacroImplements/Support` holds shared helpers (syntax parsing, diagnostics, utilities).
- `Sources/Macro` exposes the public macro API surface.
- `Tests/MacroTests` includes XCTest-based macro expansion tests.

## Build, Test, and Development Commands
- `swift build` builds all targets in the package.
- `swift test` runs the XCTest suite in `Tests/MacroTests`.
- `swift test -v` provides verbose output when debugging failures.

## Coding Style & Naming Conventions
- Use standard Swift formatting (4-space indentation, no tabs).
- Types and macros use PascalCase (for example, `FileURL`, `Mockable`).
- Macro implementation files end in `Macro.swift` (for example, `FileURLMacro.swift`).
- Keep helper types in `Sources/MacroImplements/Support` and name them descriptively.
- No formatter or linter is configured; keep changes consistent with existing code.

## Testing Guidelines
- Tests use XCTest via SwiftPM.
- Name test files `*Tests.swift` and test types `*Tests`.
- Add new tests when changing macro expansion behavior; validate both success and failure cases.
- Run `swift test` locally before opening a PR.

## Commit & Pull Request Guidelines
- Commit messages currently use short, imperative summaries (for example, "Add macros").
- PRs should include a brief description, test results (`swift test`), and any new macro examples.
- Link related issues if applicable.

## Configuration Notes
- The package depends on `apple/swift-syntax` (see `Package.swift`).
- Minimum platform is macOS 10.15.
