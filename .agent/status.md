# Status — kanevas-ios

> MàJ : 2026-11-21

## État

Socle livré (feature `kanevas-ios-socle`) : projet XcodeGen, paquet `KanevasCore` (URL de base, `-KANEVAS_URL` prioritaire),
coque SwiftUI avec WKWebView plein écran et barre de progression (E-1 chargé), `NavigationCoordinator` unique composant
`NavigationPolicyHandler` et `FailureHandler` (vides), harnais des tests UI (`Tests/UITests/Harness/`) qui lance le bouchon
Kanevas sous node, test UI de la page de choix de compte avec capture jointe, `docs/tests.md` (faits du bouchon).

## Reste

- Session : connexion, persistance, expiration (`kanevas-ios-session`) ; remplit `Harness.signIn`.
- Liens externes : `NavigationPolicyHandler` (`kanevas-ios-liens`).
- E-2 et échecs réseau : `FailureHandler` (`kanevas-ios-hors-reseau`).
- Preuve du socle sur le banc : voir la discussion de la feature ; au passage integrate le banc était injoignable.

## Pièges

- Pas de `xcodegen generate` dans les commandes de test : le shim `xcodebuild` du banc génère le projet, xcodegen est absent du pod.
- Les tests UI tournent dans le simulateur : pas de `Process`, `posix_spawn` à la place.
- ATS : `NSAllowsLocalNetworking` seulement en Debug (post-build de la cible app) ; Release reste par défaut.
- Le clone de Kanevas (`KANEVAS_SRC` ou `Scripts/fetch-kanevas.sh`) reste hors du dépôt, en lecture seule.
- Recette du socle : `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'` sur le banc.
