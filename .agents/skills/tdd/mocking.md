# When to Mock

Mock at **system boundaries** only:

- External APIs (the usage endpoint)
- The Keychain and other system services
- Time/randomness
- File system (sometimes: prefer a temporary directory)

Don't mock:

- Your own types/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```swift
// Easy to mock
func fetch(token: String, session: URLSession) async throws -> Usage {
    try await decode(session.data(for: request(token)))
}

// Hard to mock
func fetch() async throws -> Usage {
    let token = CredentialStore.readKeychain(service: "Claude Code-credentials")
    return try await decode(URLSession.shared.data(for: request(token)))
}
```

A `URLSession` whose configuration lists a `URLProtocol` subclass in
`protocolClasses` serves canned responses without touching the network.

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```swift
// GOOD: Each function is independently mockable
protocol UsageSource {
    func usage(token: String) async throws -> Usage
}

// BAD: Mocking requires conditional logic inside the mock
protocol HTTPClient {
    func send(_ request: URLRequest) async throws -> Data
}
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint
