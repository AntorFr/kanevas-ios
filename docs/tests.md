# Tests

## Levels

- **Unit** (`KanevasUnitTests`): pure logic of `KanevasCore`. Local level: `-only-testing:KanevasUnitTests`.
- **UI** (`KanevasUITests`, iPad simulator): the app launched with `-KANEVAS_URL` against the Kanevas stub; screenshots are
  attached to the report (`XCTAttachment`, `keepAlways`) and land in `.banc/captures/`.

Both play on the bench with `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'`.
Bench unreachable: code 3 (not a red test). Clone, `git`, network or `node` missing: `Scripts/fetch-kanevas.sh` exits 3; the harness then throws and the UI test fails (it is the bench, not the app, that is at fault).

## Harness (`Tests/UITests/Harness/`)

- `StubServer` starts and stops the stub at any moment of a test, also after the app has launched. Host `127.0.0.1`, port
  `3055` by default (`KANEVAS_STUB_PORT` overrides). It runs `node --import tsx src/server.ts` in the Kanevas clone with
  `KANEVAS_STUB=1`, `PORT`, a `DB_PATH` and a `SESSION_SECRET` in a temporary folder: the harness never writes in the clone.
  The test process is a simulator process, so children are spawned with `posix_spawn` (`Process` does not exist on iOS).
- Kanevas clone: `KANEVAS_SRC` (path of a clone with `node_modules` installed and the web build `dist/public`; the harness does not build it and fails with a message if the build is missing), else `Scripts/fetch-kanevas.sh` clones
  `https://github.com/AntorFr/kanevas` (runs `npm ci`, then `npm run build` when `dist/public/index.html` is missing, exit 3 if either fails) outside this repository, in `$TMPDIR/kanevas-ios-stub-src`,
  and prints its path. Nothing of Kanevas is committed here.
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
- **Pages served** (single-page app, needs Kanevas' `dist/public` build, which the harness provides):
  map `/univers/:id/cartes/:cid` (list `/univers/:id/cartes`), sheet `/univers/:id/fiche/:fid`,
  sheet list by type `/univers/:id/fiches/:type`. The lore of a sheet is read through `GET /api/univers/:id/fiches/...`.
- **Session expiry**: the session is a signed cookie; the tests expire it by clearing the cookies of the WKWebView data store.
