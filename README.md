# kanevas-ios

The children's iPad app for Kanevas: a SwiftUI shell around one full-screen `WKWebView` that loads Kanevas
(persistent data store, native progress bar). See `ARCHITECTURE.md` for the decisions, `docs/` for needs, screens and tests.

## Layout

- `project.yml`: XcodeGen definition (the `.xcodeproj` is generated, never committed).
- `Sources/KanevasCore`, `Package.swift`: pure logic (base URL resolution).
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
(needs `node`, `git`, network; see `docs/tests.md`). Bench unreachable: exit code 3, not a red test.

Run the app by hand against the stub: in a clone of `AntorFr/kanevas` with its dependencies installed,
`KANEVAS_STUB=1 PORT=3055 SESSION_SECRET=x DB_PATH=/tmp/k.db node --import tsx src/server.ts`, then launch the app
in Xcode with the argument `-KANEVAS_URL http://127.0.0.1:3055`.

Distribution is by sideload (free Apple ID); nothing is deployed to the cluster.
