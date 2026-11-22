# kanevas-ios

The children's iPad app for Kanevas: a SwiftUI shell around one full-screen `WKWebView` that loads Kanevas
(persistent data store, native progress bar). When the network is cut or Kanevas answers HTTP 5xx, a native screen says "Kanevas is unreachable" with a Retry button. See `ARCHITECTURE.md` for the decisions, `docs/` for needs, screens and tests.

## Layout

- `project.yml`: XcodeGen definition (the `.xcodeproj` is generated, never committed).
- `Sources/KanevasCore`, `Package.swift`: pure logic (base URL resolution, navigation policy, failure mapping to the unreachable state).
- `App/`: the shell (`Views/`, `Navigation/`, `Support/` for the system URL opening, `SessionReset.swift` for the Debug-only session clearing).
- `Tests/UnitTests`, `Tests/UITests` (with the Kanevas stub harness).

## Base URL

`KanevasBaseURL` in Info.plist (generated from `project.yml`, where it is set; there is no Info.plist file to edit) (default `https://kanevas.berard.me`); the launch argument `-KANEVAS_URL <url>` overrides it.

## Links

Links to hosts other than Kanevas and its Authelia open in the system browser, never in the app. Allowed hosts: Info.plist (generated from `project.yml`)
`KanevasAllowedHosts` (default `kanevas.berard.me,auth.berard.me`; the base URL host is always allowed); the launch argument
`-KANEVAS_ALLOWED_HOSTS a,b` overrides it. See `ARCHITECTURE.md` (AD-liens-1 to 4).

## Build and test

Build and tests run on the bench only (Xcode on a Mac, through the `xcodebuild` shim of the build pod):

```
xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'
```

Unit tests alone: add `-only-testing:KanevasUnitTests`; one UI class: `-only-testing:KanevasUITests/<Class>`. The UI tests start Kanevas in stub mode themselves (except `LinksTests`, `UnreachableStatesTests` and `UnreachableBoundariesTests`, which serve their own pages from loopback servers;
the others, `SessionTests` (sign-in, persistence, expiry) among them, need `node`, `git`, network; see `docs/tests.md`). Bench unreachable: exit code 3, not a red test (that code comes from the bench shim). If git, node, npm or network is missing, `Scripts/fetch-kanevas.sh` exits 3 inside the UI test, which then fails: that is the bench's fault, not the app's.

Run the app by hand against the stub: in a clone of `AntorFr/kanevas` with its dependencies installed (`npm ci`),
`KANEVAS_STUB=1 PORT=3055 SESSION_SECRET=0123456789abcdef0123 DB_PATH=/tmp/k.db node --import tsx src/server.ts`, (the stub then serves the account choice page; pages that need Kanevas' built `dist/public` are not available from sources: the harness gets it from `Scripts/build-kanevas-web.sh`, see `docs/tests.md`), then, on a Mac with XcodeGen,
`xcodegen generate` (not available in the build pod; the bench shim generates the project itself), open `Kanevas.xcodeproj`, and add `-KANEVAS_URL http://127.0.0.1:3055` to the `Kanevas` scheme
(Run > Arguments) before running on an iPad simulator.

Distribution is by sideload (free Apple ID); nothing is deployed to the cluster.
