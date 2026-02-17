# NnArgumentParser

![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blueviolet.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## Overview

A Swift package that extends ArgumentParser with dependency injection support for testable CLI commands. Provides thread-local factory storage for injecting dependencies during testing without global mutable state.

## Features

- **Dependency Injection Protocol** — `NnRootCommand` protocol for commands with injectable factories
- **Thread-Safe Testing** — Thread-local storage enables parallel test execution
- **stdout Capture** — `testRun` method captures printed output for test assertions
- **ArgumentParser Re-export** — Import `NnArgumentParser` to get full ArgumentParser access

## Requirements

- macOS 15+
- Swift 6.0+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/nikolainobadi/NnArgumentParser.git", branch: "main")
]
```

Then include it in your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "NnArgumentParser", package: "NnArgumentParser")
    ]
)
```

For testing support, also add:

```swift
.testTarget(
    name: "YourTests",
    dependencies: [
        .product(name: "ArgumentParserTesting", package: "NnArgumentParser")
    ]
)
```

## Usage

### Define a Root Command with Dependency Injection

```swift
import NnArgumentParser

struct MyCommand: NnRootCommand {
    typealias Factory = MyFactory
    static var defaultFactory: Factory { MyFactory() }

    @Argument var name: String

    mutating func run() throws {
        let greeter = Self.contextFactory.makeGreeter()
        print(greeter.greet(name))
    }
}
```

### Test Commands with Injected Dependencies

```swift
import Testing
import ArgumentParserTesting

@Test func greeting() throws {
    let output = try MyCommand.testRun(
        contextFactory: MockFactory(),
        args: ["World"]
    )
    #expect(output == "Hello, World!")
}
```

## Dependencies

- [swift-argument-parser](https://github.com/apple/swift-argument-parser) (1.7.0+)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
