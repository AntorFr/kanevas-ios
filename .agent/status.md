# Status — kanevas-ios

> MàJ : 2026-11-28

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

Session livrée (feature `kanevas-ios-session`, P-1 à P-3, B-1 à B-4) : `SessionReset` (App, Debug seul) vide le magasin de la WKWebView quand `-KANEVAS_CLEAR_SESSION` est passé, avant le premier chargement (AD-session-1) ; la persistance reste celle de la web view (AD-session-2). `SessionTests` (UI) : première connexion jusqu'à la carte, relance après arrêt du processus sans reconnexion puis fiche de « Maître Aldric » (« Ouvrir la fiche »), session vidée puis reconnexion. Le bouchon sert « Mes univers » à la racine : la carte s'atteint par les liens de la page. 
Page épinglée (feature `kanevas-ios-web-epingle`) : les tests UI servent une version épinglée de la page construite de Kanevas. `KANEVAS_WEB_VERSION` (une ligne, le tag de la Release, aujourd'hui `v0.50.0`) est le seul geste pour changer la page ; `Scripts/fetch-kanevas-web.sh` télécharge l'archive et sa somme, vérifie, décompresse dans un cache hors du dépôt et affiche le chemin (code 1 : `checksum mismatch` ou `no archive for <version>` ; code 3 : banc/réseau). `KanevasWeb` (harnais) le lance, compare le `VERSION` de l'archive à l'épingle et le trace en tête de la suite ; `StubServer` lance `node lancer-bouchon.mjs`. Plus de cargo, wasm-pack, `Scripts/build-kanevas-web.sh`, `.kanevas-web/`, `fetch-kanevas.sh`, `KANEVAS_SRC` ni `installation:` : la correction `rouge-kanevas-ios-2` est sans objet.

## Reste

- Preuve de la suite entière : jouée par `attester` avant la recette ; `testAppShowsAccountChoicePage` (StubSignInPageUITests) rejoué 3 fois de suite, vert, sur le banc (feature `rouge-kanevas-ios-1`).

## Pièges

- `-KANEVAS_CLEAR_SESSION` n'existe qu'en Debug ; le premier lancement d'un test le passe, les cookies du simulateur survivant d'un test à l'autre.
- Dans le bouchon, des liens de la page se disent non touchables : les tests touchent leur centre.
- Le banc n'a besoin que de node (>= 20) et du réseau ; le premier bouchon d'une exécution lance `npm ci --omit=dev` dans l'archive (délai de démarrage plus long).
- Le double d'ouverture (`FakeOpenerOverlay`) n'existe qu'en Debug ; Release ouvre via `UIApplication.shared.open`.
- L'hôte est comparé exactement (pas de suffixe) et sans port ; un schéma sans hôte (`mailto:`, `tel:`) part au système.
- Un cookie de session reste dans la web view du simulateur d'un test à l'autre (les cookies ignorent le port) : d'où le secret neuf par bouchon.
- Pas de `xcodegen generate` dans les commandes de test : le shim `xcodebuild` du banc génère le projet, xcodegen est absent du pod.
- Les tests UI tournent dans le simulateur : pas de `Process`, `posix_spawn` à la place.
- ATS : `NSAllowsLocalNetworking` seulement en Debug (post-build de la cible app) ; Release reste par défaut.
- L'archive de Kanevas est décompressée hors du dépôt (`$KANEVAS_WEB_CACHE`, sinon `$TMPDIR/kanevas-ios-web/<version>`), jamais committée.
- `WKWebView.reload()` ne fait rien après un échec provisoire : Retry passe par `load(URLRequest)`. Annulation et `WebKitErrorDomain` 102 (lien externe, téléchargement) ne sont pas des échecs.
- Recette du socle : `xcodebuild test -scheme Kanevas -destination 'platform=iOS Simulator,name=iPad'` sur le banc.
