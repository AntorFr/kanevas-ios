# Status — kanevas-ios

> MàJ : 2026-11-21

## État

Socle livré (feature `kanevas-ios-socle`) : projet XcodeGen, paquet `KanevasCore` (URL de base, `-KANEVAS_URL` prioritaire),
coque SwiftUI avec WKWebView plein écran et barre de progression (E-1 chargé), `NavigationCoordinator` unique composant
`NavigationPolicyHandler` et `FailureHandler` (vides à l'origine, remplis par les features suivantes), harnais des tests UI (`Tests/UITests/Harness/`) qui lance le bouchon
Kanevas sous node, test UI de la page de choix de compte avec capture jointe, `docs/tests.md` (faits du bouchon).

Liens externes livrés (feature `kanevas-ios-liens`) : `NavigationPolicy.decide` (fonction pure, hôtes exacts), `NavigationPolicyHandler`
(décision de navigation + `createWebViewWith`), hôtes autorisés en configuration (`KanevasAllowedHosts`, `-KANEVAS_ALLOWED_HOSTS`),
ouverture système injectable (`URLOpening`, double Debug `-KANEVAS_FAKE_OPENER`), tests unitaires et `LinksTests` (page locale servie par le test).

Harnais durci (feature `rouge-kanevas-ios-1`) : port libre par test, refus d'un port déjà servi, secret de session neuf par
bouchon, diagnostic joint à l'échec (`expectInWebView`).

Hors réseau livré (feature `kanevas-ios-hors-reseau`, P-4, B-6) : `FailureMapping` (KanevasCore) range les erreurs `NSURLErrorDomain`
(hors annulation) et les HTTP 500–599 en `.unreachable` ; `FailureHandler` le dit à `ConnectionModel` ; `RootView` affiche E-2
(`UnreachableView`, « Kanevas is unreachable », « Retry ») ; Retry recharge l'adresse en échec par `load(URLRequest)`.
Tests : `FailureMappingTests` (unitaire), `OfflineTests` (UI, port qui s'éveille, capture P-4), `UnreachableStatesTests` (UI, `StatusServer` local : 5xx, 404, Retry en échec, coupure après lecture, grand texte), `UnreachableBoundariesTests` (UI, `RouteServer` privé : bornes 500/599 et 4xx, coupure sans réponse, Retry sur l'adresse en échec, sous-ressource 500). Piège : `RouteServer` duplique `StatusServer`, à fusionner si un troisième test en a besoin.

## Reste

- Session : connexion, persistance, expiration (`kanevas-ios-session`) ; s'appuie sur `XCUIApplication.signIn(account:)` (déjà écrit dans le harnais, aucun test ne l'appelle encore).
- Preuve de la suite entière : jouée par `attester` avant la recette ; `testAppShowsAccountChoicePage` (StubSignInPageUITests) rejoué 3 fois de suite, vert, sur le banc (feature `rouge-kanevas-ios-1`).

## Pièges

- Le double d'ouverture (`FakeOpenerOverlay`) n'existe qu'en Debug ; Release ouvre via `UIApplication.shared.open`.
- L'hôte est comparé exactement (pas de suffixe) et sans port ; un schéma sans hôte (`mailto:`, `tel:`) part au système.
- Un cookie de session reste dans la web view du simulateur d'un test à l'autre (les cookies ignorent le port) : d'où le secret neuf par bouchon.
- Pas de `xcodegen generate` dans les commandes de test : le shim `xcodebuild` du banc génère le projet, xcodegen est absent du pod.
- Les tests UI tournent dans le simulateur : pas de `Process`, `posix_spawn` à la place.
- ATS : `NSAllowsLocalNetworking` seulement en Debug (post-build de la cible app) ; Release reste par défaut.
- Le clone de Kanevas (`KANEVAS_SRC` ou `Scripts/fetch-kanevas.sh`) reste hors du dépôt, en lecture seule.
- `WKWebView.reload()` ne fait rien après un échec provisoire : Retry passe par `load(URLRequest)`. Annulation et `WebKitErrorDomain` 102 (lien externe, téléchargement) ne sont pas des échecs.
- Recette du socle : `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'` sur le banc.
