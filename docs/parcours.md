# Kanevas iOS — audience, needs, journeys

> Product documentation, scoping target on `epic/kanevas-ios`. Identifiers: `B-n` needs, `P-n` journeys,
> `E-n` screens (`docs/ecrans.md`), `AD-n` decisions (`ARCHITECTURE.md`).

## For whom

**The children** of the household, on the family iPad, in the evening or during a tabletop session:
they look at the universe map and go back to read the lore of the characters they met. They are
readers, not editors. They sign in once; a prompt for a password on every launch would end the use.

The **parent** (Monsieur) installs the app by sideload (free Apple ID, 7-day signature) and re-signs it
when it expires. No one else operates the app. This gesture happens in Xcode, outside the product: it has no
journey or screen here and nothing in the app supports it (AD-7).

## Needs

- **B-1** — The app opens the Kanevas universe map on the iPad, full screen, without leaving the app.
- **B-2** — From the map, a child opens a character sheet and reads its lore (what Kanevas shows
  that account, permissions unchanged).
- **B-3** — A child signs in once through Authelia (OIDC → Kanevas session); a later launch
  lands on the map without signing in again while the Authelia/Kanevas session is valid.
- **B-4** — When the session has expired, the app shows the Authelia sign-in again, then returns where the child
  was going (the map by default).
- **B-5** — Navigation stays inside Kanevas: a link to another host opens outside the app
  (system browser), never inside the shell.
- **B-6** — With the network down or Kanevas unreachable, the app says so and offers a retry; it never shows a blank page.
- **B-7** — The app is built and its tests played by the chain (banc Xcode), with screenshots as evidence.

## Journeys

- **P-1 — First launch.** The child opens the app (E-1 loading) → Kanevas redirects to Authelia
  (E-1, web content) → signs in → lands on the map (E-1). Actor: the child; screen: E-1. B-1, B-3.
- **P-2 — Back to a character.** The child opens the app (session valid: map directly) → taps a
  character on the map → reads the sheet (E-1 web content). B-1, B-2, B-3.
- **P-3 — Session expired.** The app opens, Kanevas answers with sign-in → the child signs in again → map. B-4.
- **P-4 — Kanevas unreachable (no network, or Kanevas down).** Launch or navigation fails, or Kanevas answers HTTP 5xx on the page → E-2 ("Kanevas is unreachable", Retry) → Retry reloads the last address; if it fails again, E-2 returns. Actor: the child; screen: E-2. B-6.
- **P-5 — External link.** A child taps an external link in a sheet → the system browser opens. B-5.
- **P-6 — Chain build and test.** The chain builds the app and plays unit and UI tests on the bench against Kanevas in
  stub mode; the run attaches one screenshot per journey P-1 to P-5 (E-1, E-2). Actor: the chain; no screen of its own. B-7. (So far: the account choice page, P-1 to P-3 (`SessionTests`), P-4 (E-2) and P-5 (`LinksTests`).)

## Out of scope

Any native function beyond the shell (offline mode, notifications, editing content); App Store or
TestFlight distribution; any change to the Kanevas web product (a Kanevas change needed by the app is
a feature on `AntorFr/kanevas`); iPhone layout; native OIDC flow (see AD-2); any in-app support for installing or re-signing (sideload is a manual gesture of the parent, AD-7).
