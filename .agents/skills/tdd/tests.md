# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```swift
// GOOD: Tests observable behavior
func testExpiredFileNeverHidesALiveToken() throws {
    let dir = try makeProfileDir(credentials: expiredJSON)
    let creds = CredentialStore.read(for: profile(dir))
    XCTAssertTrue(creds.expired)
}
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```swift
// BAD: Tests implementation details
func testReadCallsKeychainAfterFile() {
    let spy = KeychainSpy()
    _ = CredentialStore.read(for: profile, keychain: spy)
    XCTAssertEqual(spy.calls, ["Claude Code-credentials"])
}
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```swift
// BAD: Bypasses interface to verify
func testWriteCreatesFile() throws {
    bundle.write(to: url)
    let raw = try String(contentsOf: url)
    XCTAssertTrue(raw.contains("\"sessionPct\""))
}

// GOOD: Verifies through interface
func testBundleRoundTrips() throws {
    bundle.write(to: url)
    XCTAssertEqual(SnapshotBundle.read(from: url), bundle)
}
```

**Tautological tests**: Expected value restates the implementation, so the test passes by construction.

```swift
// BAD: Expected value is recomputed the way the code computes it
func testBurnRate() {
    let readings = [(t0, 10.0), (t0 + 3600, 25.0)]
    let expected = (readings[1].1 - readings[0].1) / 1
    XCTAssertEqual(burnRate(readings), expected)
}

// GOOD: Expected value is an independent, known literal
func testBurnRate() {
    XCTAssertEqual(burnRate([(t0, 10), (t0 + 3600, 25)]), 15)
}
```
