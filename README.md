# swift-macros

A collection of Swift macros for URL creation, initializer generation, mocks, and stubs.

## Requirements
- Swift 6.2+ (SwiftPM)
- macOS 10.15+

## Installation (SwiftPM)
Add the package to `Package.swift`.

```swift
.package(url: "https://github.com/tdrk18/swift-macros.git", from: "0.1.0"),
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Macro", package: "swift-macros")
    ]
)
```

## Usage
### URL / FileURL
Create `URL` values from static string literals.

```swift
let api = #URL("https://example.com/api")
let file = #FileURL("/path/to/file.txt")
```

### Init
Generate initializers from stored properties.

```swift
@Init(.public)
struct User {
    let id: Int
    let name: String
}
```

### Mockable
Generate a mock class for a protocol.

```swift
@Mockable
protocol UserRepository {
    func fetch(id: Int) throws -> String
}

// Example output: MockUserRepository
```

### Stub
Generate `static func stub(...) -> Self` for a struct.

```swift
@Stub
struct User {
    let id: Int
    let name: String
}
```

## Development
- `swift build`: Build the package
- `swift test`: Run tests

## Project Structure
- `Sources/Macro`: Public API (macro declarations)
- `Sources/MacroImplements`: Macro implementations
- `Tests/MacroTests`: Macro expansion tests
