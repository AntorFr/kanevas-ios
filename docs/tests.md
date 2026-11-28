# Tests

## Levels

- **Unit** (`KanevasUnitTests`): pure logic of `KanevasCore`. Local level: `-only-testing:KanevasUnitTests`.
- **UI** (`KanevasUITests`, iPad simulator): the app launched with `-KANEVAS_URL` against the Kanevas stub; screenshots are
  attached to the report (`XCTAttachment`, `keepAlways`) and land in `.banc/captures/`.

`UnreachableStatesTests` (UI) starts a loopback `StatusServer` (`Tests/UITests/Harness/StatusServer.swift`, no `node`, no Kanevas stub) that always answers a chosen HTTP status, and checks E-2, Retry (also while the server is still down) and that a 404 stays on its page.

`UnreachableBoundariesTests` (UI, written from need B-6) uses its own private `RouteServer` (loopback, per-path status, no `node`, no Kanevas stub), which can also accept a connection and close it unanswered. It checks the bounds of the 5xx range (500 and 599 show E-2; 401, 403, 499 do not), a connection cut with no answer, Retry reloading the address that failed rather than the base one, and that a 500 on a sub-resource does not show E-2.

`LinksTests` (UI) serves its own page with an external link from a loopback HTTP server started by the test (no Kanevas stub),
launches the app with `-KANEVAS_URL` on it and `-KANEVAS_FAKE_OPENER` (Debug double recording the opened URL, read through the
`externalOpenCount` / `lastExternalURL` accessibility elements), and checks the view stays on its page.

`SessionTests` (UI, P-1 to P-3) starts the Kanevas stub and plays: first launch (account choice, sign-in, the stub's default landing page, then the map and a character sheet through the page's own links), relaunch after the process is terminated (no sign-in again: the stub's session cookie survives a kill, so nothing to work around in the app), and an expired session (relaunch with the Debug argument `-KANEVAS_CLEAR_SESSION`: sign-in shows again, then the landing page). One screenshot per journey.

All UI tests play on the bench with `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'`.
One UI class alone: add `-only-testing:KanevasUITests/<Class>` (e.g. `UnreachableBoundariesTests`). Other UI classes: `StubHarnessUITests` (the harness starts the stub), `StubSignInPageUITests` (account choice page), `OfflineTests` (P-4: nothing listens, then the stub starts and Retry loads its page).
Kanevas page: the UI tests serve a pinned, prebuilt release of Kanevas (nothing of it is built here). The pin is the one line of `KANEVAS_WEB_VERSION` at the repository root (a Release tag of `AntorFr/kanevas` that carries `kanevas-web-<version>.tar.gz`, e.g. `v0.50.0`); changing that line, and nothing else, changes the page the tests run against. The suite the chain plays is `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'`; the report lands in `.banc/rapport-tests/junit.xml`.
The bench needs `node` (>= 20), `curl`, `tar`, a SHA-256 tool and network (the first stub of a run also runs `npm ci --omit=dev` in the archive). Bench unreachable, or network/`node` missing: code 3 (not a red test); the harness then throws and the UI test fails (it is the bench, not the app, that is at fault).

## Harness (`Tests/UITests/Harness/`)

- `StatusServer` (`Harness/StatusServer.swift`): loopback server answering one status, changeable during the test. `RouteServer` is a private copy inside `UnreachableBoundariesTests.swift` that adds a status per path and closing a connection unanswered; extend `StatusServer` rather than copy it if a third test needs that.

- `StubServer` starts and stops the stub at any moment of a test, also after the app has launched. Host `127.0.0.1`. `startStub()` picks a
  free port per test (`StubServer.freePort()`); `KANEVAS_STUB_PORT` forces one (a bare `StubServer()` defaults to `3055`). A port
  already answering fails the start with a clear message, instead of testing a stub left by a cut run. The test process is a simulator process, so children are spawned with `posix_spawn` (`Process` does not exist on iOS).
- Pinned archive: `Scripts/fetch-kanevas-web.sh [version]` reads `KANEVAS_WEB_VERSION`, downloads `kanevas-web-<version>.tar.gz` and its `.sha256` from the Release of that tag, checks the sum, unpacks it outside the repository into `${KANEVAS_WEB_CACHE:-$TMPDIR/kanevas-ios-web}/<version>` (reused without network once checked) and prints that folder. Exit 1: `checksum mismatch`, or `no archive for <version>` (Release or asset absent); exit 3: network, `node`, `curl`, `tar` or the cache. `KANEVAS_WEB_BASE_URL` overrides the download base (tests of the script). The harness (`KanevasWeb`) runs it once per run, repeats its failure verbatim, reads the archive's `VERSION`, requires it to equal the pin (without the leading `v`) and logs it at the head of the suite.
- `StubServer` runs `node lancer-bouchon.mjs --port <free port> --data <temp folder>` of the archive, plus a `SESSION_SECRET` in the environment (fresh per stub), and waits for `/connexion-bouchon`.

- `expectInWebView(_:of:stub:expecting:)` waits for an element of the web view; on failure it attaches `stub.log`, the answer of
  `GET /connexion-bouchon`, the accessibility hierarchy and a screenshot, and names the cause (stub silent, page served
  differently, page served but element not found).
- `XCUIApplication.launch(pointingAt:)` passes `-KANEVAS_URL`; `XCUIApplication.signIn(account:)` taps
  « Se connecter en tant que <Name> » in the web view (the button posts `compte=<id>` to `/connexion-bouchon`);
  `attachScreenshot(_:of:)` joins a capture.
- ATS: the Debug configuration (the bench's) adds `NSAllowsLocalNetworking` only, through a post-build step of the app
  target, so the stub is served over HTTP; Release keeps the default; `NSAllowsArbitraryLoads` is never set.

## Stub facts (read in the code of `AntorFr/kanevas`: `src/routes/bouchon.ts`, `src/bouchon/depart.ts`, its AD-15 and AD-55)

- **Origin**: a plain `http://<host>:<PORT>`, `PORT` default 3001; the server listens on `0.0.0.0`. No Authelia.
  Stub mode refuses to start if any `OIDC_*` variable is set.
- **Sign-in**: without a session, a request is redirected to `GET /connexion-bouchon`, the test-account choice page
  (title « Choisir un compte de test », one button « Se connecter en tant que <Name> » per account).
  `POST /connexion-bouchon` (form body `compte=<identifier>`) sets the session cookie and redirects to `/`; an unknown
  identifier redirects back to the choice page. Without `KANEVAS_STUB`, both answer 404.
- **Test accounts** (identifier → name): `antor` → Antor, `lea` → Léa, `teo` → Teo, `mira` → Mira, `admin` → Admin
  (Authelia group `parents`).
- **Starting world** (seeded on an empty database): universe « Lame d'Ébène » (owner `antor`, member `lea`), with
  character sheets such as « Maître Aldric » and « Bran Corvalis » (sections « Apparence », a GM-only « Vérité — MJ seul »)
  and a graph map « Carte de la côte » holding the places « Port-Sel » and the sheet of « Maître Aldric ».
  Other universes: « Les Landes grises » (`mira`), « Les Cendres de Vaëlis » (`admin`, `antor` member), « Essai Kanka ».
- **Pages served** (single-page app, the page of the pinned archive; the harness builds nothing):
  map `/univers/:id/cartes/:cid` (list `/univers/:id/cartes`), sheet `/univers/:id/fiche/:fid`,
  sheet list by type `/univers/:id/fiches/:type`. The lore of a sheet is read through `GET /api/univers/:id/fiches/...`.
- **Session expiry**: the session is a signed cookie; the tests expire it by clearing the cookies of the WKWebView data store.
