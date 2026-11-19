# Kanevas iOS — screens

| Id | Screen | Who | What they do |
|---|---|---|---|
| E-1 | Kanevas web view (full screen) | child | everything: sign in (Authelia page), map, sheets. All content is Kanevas'; the app draws nothing around it. |
| E-2 | Connection error | child | reads "Kanevas is unreachable", taps **Retry** |

| Actor | E-1 | E-2 |
|---|---|---|
| child | view, navigate, sign in (what Kanevas permits the account is Kanevas' own; the app hides nothing) | retry |
| parent | no access (no screen; sideload is a manual gesture, AD-7) | no access |
| the chain (P-6) | no screen of its own; plays the journeys and captures E-1 and E-2 | same |

## States

- **E-1**: loading (native progress bar at top, system colours), loaded, navigation failure or HTTP ≥ 500 on the main frame → E-2.
  Orientation: landscape and portrait. Light and dark follow the system and Kanevas' own theme; the
  app imposes none.
- **E-2**: one message, one **Retry** button, on the system background. No mockup: it is a plain native
  view with system components; the visual direction is Kanevas' own charter (the app adds no chrome, hence no
  separate charter or design-system component).

- **E-1, other states**: empty, denied (Kanevas' own 4xx pages) and extreme content are rendered by Kanevas inside E-1; the app draws nothing for them, an HTTP 4xx is not a failure and never shows E-2.

## E-2 detail (kanevas-ios-hors-reseau)

- Shown over E-1 on a navigation failure or an HTTP ≥ 500 on the main frame (AD-4, AD-reseau-1); never a blank page.
- Content: message "Kanevas is unreachable" (system `.title2`), button "Retry" (system `.borderedProminent`), centred vertically and horizontally, on `Color(.systemBackground)`; identical in
  landscape and portrait, light and dark. Accessibility identifiers: `unreachableMessage`, `retryButton`.
- Retry hides E-2 and reloads the failing address (the last URL, AD-reseau-3); if it fails again E-2 returns. No loading indicator of its own: E-1's progress bar shows the reload.
- Under E-2: the web view stays in place beneath, fully covered by the opaque background; a page already read is not shown while E-2 is up.
- Retry in flight: E-2 disappears at the tap and E-1 shows its progress bar; E-2 returning is the only sign that the retry failed.
- States: loading (E-1's bar, above), error (E-2 itself), empty and denied (no object: E-2 holds no data and no permission), extreme content (one short fixed message in system text styles: it wraps and follows the system text size, no truncation, any size and orientation).
- Criteria: given nothing listens at Kanevas' address, when the app launches, then E-2 shows the message and Retry; given E-2 and Kanevas now answering, when the child taps Retry, then E-1 loads the page; given Kanevas answers HTTP 503, then E-2 shows; given a 404, then E-1 shows Kanevas' own page.
- Design system: none to judge (native system components, no token, no component added; cadrage decision).
