# Kanevas iOS — screens

| Id | Screen | Who | What they do |
|---|---|---|---|
| E-1 | Kanevas web view (full screen) | child | everything: sign in (Authelia page), map, sheets. All content is Kanevas'; the app draws nothing around it. |
| E-2 | Connection error | child | reads "Kanevas is unreachable", taps **Retry** |

Matrix: child × E-1 (view, navigate, sign in) ; child × E-2 (retry). The parent has no screen.

## States

- **E-1**: loading (native progress bar at top, system colours), loaded, navigation failure → E-2.
  Orientation: landscape and portrait. Light and dark follow the system and Kanevas' own theme; the
  app imposes none.
- **E-2**: one message, one **Retry** button, on the system background. No mockup: it is a plain native
  view with system components; the visual direction is Kanevas' own charter (the app adds no chrome, hence no
  separate charter or design-system component).

## E-2 detail (kanevas-ios-hors-reseau)

- Shown over E-1 on a navigation failure or an HTTP ≥ 500 on the main frame (AD-4, AD-reseau-1); never a blank page.
- Content: message "Kanevas is unreachable" (system `.title2`), button "Retry" (system `.borderedProminent`), centred vertically and horizontally, on `Color(.systemBackground)`; identical in
  landscape and portrait, light and dark. Accessibility identifiers: `unreachableMessage`, `retryButton`.
- Retry hides E-2 and reloads the failing address (the last URL, AD-reseau-3); if it fails again E-2 returns. No loading indicator of its own: E-1's progress bar shows the reload.
- Design system: none to judge (native system components, no token, no component added; cadrage decision).
