# kanevas-ios — agent instructions

- Code, comments, README, `docs/` and release notes in English; `.agent/*` stays French.
- Commit messages in French: subject, then the *why*. Explicit paths, no AI attribution trailers.
- The Xcode project is generated: `project.yml` (XcodeGen) is committed, `*.xcodeproj` never.
  Pure logic lives in the SwiftPM package `KanevasCore` (`Sources/KanevasCore`); the SwiftUI shell in `App/`.
- Build and test on the bench only, with `xcodebuild` (the pod side of the bench, codes 0–4; code 3 = bench unreachable,
  not a red test): `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'`.
  Local level (`tests.local`): unit tests only (`-only-testing:KanevasUnitTests`).
- Proof of test: `attester` plays the suite `.sdlc.yaml` declares; `attester --publier` posts `tests-complets` when green.
- One `WKNavigationDelegate` (`NavigationCoordinator`) composes the handlers; a slice fills its handler, never the coordinator.
- No deployment (`deploiement:` absent): the app is sideloaded (AD-7); nothing goes to the cluster.
- Update `.agent/status.md` in the same commit as the work it reflects — except in a task of a chain feature, which
  leaves it and the other common files alone unless its fiche names them.

## Socle checklist (skill socle-projet)

Not applicable, with reason: image/Dockerfile, chart, cluster conf (an app does not deploy to the cluster); auth,
data, secrets (no account or state of its own: the session lives in Kanevas' cookies); stub mode (the stub is Kanevas',
started by the UI-test harness, see `docs/tests.md`).
