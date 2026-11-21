# Kanevas iOS — screens

> Built so far: E-1 loading and loaded (slice `kanevas-ios-socle`). E-2 and the failure/navigation handlers are
> still empty pass-throughs (slices `kanevas-ios-hors-reseau`, `kanevas-ios-liens`).

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
