# Kanevas iOS — data

The app owns **no business data**: universes, sheets and permissions live in Kanevas.

| Item | Where | Notes |
|---|---|---|
| Kanevas session cookie | WKWebView persistent data store (`WKWebsiteDataStore.default()`) | survives launches; deleted by the system at uninstall |
| Authelia session cookie | same store | validity set by Authelia |
| Base URL | build setting `KANEVAS_URL` (Info.plist), default `https://kanevas.berard.me`; overridden by a launch argument in tests | not a secret |

No credential is stored by the app code (no Keychain, no password). Rights: those of the signed-in Kanevas account.
