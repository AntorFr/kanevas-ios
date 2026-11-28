# Kanevas iOS — data

The app owns **no business data**: universes, sheets and permissions live in Kanevas.

| Item | Where | Notes |
|---|---|---|
| Kanevas session cookie | WKWebView persistent data store (`WKWebsiteDataStore.default()`) | survives launches; deleted by the system at uninstall |
| Authelia session cookie | same store | validity set by Authelia |
| Base URL | `KanevasBaseURL` in Info.plist (`project.yml`), default `https://kanevas.berard.me`; the launch argument `-KANEVAS_URL <url>` wins (tests, AD-5) | not a secret |
| Allowed hosts | Info.plist `KanevasAllowedHosts`, default `kanevas.berard.me,auth.berard.me` (Kanevas and its Authelia issuer); overridden by launch argument `-KANEVAS_ALLOWED_HOSTS` in tests | not a secret; the base URL host is always allowed |

No credential is stored by the app code (no Keychain, no password). Rights: those of the signed-in Kanevas account.
