# kanevas-ios

The children's iPad app for Kanevas: a SwiftUI shell around one full-screen `WKWebView` that loads Kanevas
(persistent data store, native progress bar). When the network is cut or Kanevas answers HTTP 5xx, a native screen says "Kanevas is unreachable" with a Retry button. See `ARCHITECTURE.md` for the decisions, `docs/` for needs, screens and tests.

## Layout

- `project.yml`: XcodeGen definition (the `.xcodeproj` is generated, never committed).
- `Sources/KanevasCore`, `Package.swift`: pure logic (base URL resolution, failure mapping to the unreachable state).
- `App/`: the shell (`Views/`, `Navigation/`).
- `Tests/UnitTests`, `Tests/UITests` (with the Kanevas stub harness).

## Base URL

`KanevasBaseURL` in Info.plist (default `https://kanevas.berard.me`); the launch argument `-KANEVAS_URL <url>` overrides it.

## Build and test

Build and tests run on the bench only (Xcode on a Mac, through the `xcodebuild` shim of the build pod):

```
xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'
```

Unit tests alone: add `-only-testing:KanevasUnitTests`. The UI tests start Kanevas in stub mode themselves
(needs `node`, `git`, network; see `docs/tests.md`). Bench unreachable: exit code 3, not a red test (that code comes from the bench shim, and from `Scripts/fetch-kanevas.sh` when git, node or network is missing).

Run the app by hand against the stub: in a clone of `AntorFr/kanevas` with its dependencies installed (`npm ci`),
`KANEVAS_STUB=1 PORT=3055 SESSION_SECRET=0123456789abcdef0123 DB_PATH=/tmp/k.db node --import tsx src/server.ts`, then, on a Mac with XcodeGen,
`xcodegen generate` (not available in the build pod; the bench shim generates the project itself), open `Kanevas.xcodeproj`, and add `-KANEVAS_URL http://127.0.0.1:3055` to the `Kanevas` scheme
(Run > Arguments) before running on an iPad simulator.

Distribution is by sideload (free Apple ID); nothing is deployed to the cluster.
