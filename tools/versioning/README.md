# Numérotation IndeX

## Série actuelle — décision du 31 octobre 2026

La série 0.6 a commencé à **0.6.0**. À compter de la nouvelle décision du
31 octobre, le mineur s’affiche sur **au moins deux chiffres** : 0.6.03, 0.6.08,
0.6.09, 0.6.10, 0.6.11, puis 0.6.99, 0.6.100, etc.
État 0 bêta, majeur 6 autorisé explicitement ; ne pas modifier à nouveau le majeur
ou passer en finale sans ordre utilisateur. `first_minor: 0` est conservé et
`minor_width: 2` fixe la largeur d’affichage minimale. Le compteur poursuit sa
valeur actuelle, y compris les numéros consommés par les builds échoués ; aucun
compteur historique n’est réinitialisé.

Le numéro technique de build vaut mineur + 1 pour cette série afin de rester
strictement positif. Flutter/SemVer reçoit la forme sans zéro initial (`0.6.3`),
la version publique conserve le zéro (`0.6.03`).

Exemple d’archive : `IndeX_0.6.03_windows_x64_portable.zip` ; artefact
`IndeX-0.6.03-windows-x64-portable`. À propos reçoit la même version publique.

## Historique — décision du 28 octobre 2026

Version initiale : **0.5.01**. Format `état.majeur.mineur` : état 0 (bêta) ou 1
(finale), majeur alors fixé à 5 tant que l’utilisateur n’a pas explicitement demandé de le
changer, mineur incrémenté et affiché sur au moins deux chiffres (01…99,100…).
`version.json` fixe l’état, le majeur et le premier mineur ; aucun changement
automatique d’état ou de majeur. La forme Flutter/SemVer enlève le zéro initial
(`0.5.1+1`) ; la version publique et les archives gardent `0.5.01`.

## Constructions GitHub Actions

Chaque exécution manuelle de construction Windows ou Android (y compris
relance) réserve le prochain mineur **avant** les contrôles et la compilation.
Un build en échec consomme donc son numéro : il n’est pas réattribué. Le premier
nouveau build réserve 01, le suivant 02. Le numéro n’est pas basé sur le nombre
de commits ou sur le nom de l’artefact précédent.

Le workflow sérialise les constructions et `reserve.py --ci` conserve les
compteurs dans la branche technique **`index-build-versions`**, créée à la première
réservation. Cette branche contient uniquement `counters.json` ; elle ne modifie
ni `main` ni le code. Les deux workflows se déclenchent uniquement avec workflow_dispatch ;
un push, y compris sur la branche de compteurs, ne lance aucune construction. Ne pas effacer
cette branche ou réinitialiser son compteur, pour éviter de réutiliser des versions.

L’écriture requiert `contents: write` pour le jeton Actions. Une règle du dépôt
qui refuse la création/écriture de cette branche fera échouer explicitement la
réservation, sans produire une archive avec une version de repli. Les pull requests ne déclenchent plus ces workflows ; leurs contrôles doivent
être lancés explicitement sur la branche à vérifier. Cette numérotation vise les builds de distribution ;
`flutter test` et les compilations intermédiaires de tests n’incrémentent pas le mineur.

Sorties : `IndeX_0.5.01_windows_x64_portable.zip`, son SHA256 et artefact
`IndeX-0.5.01-windows-x64-portable` (puis 02,03…). Le même numéro est passé à
Flutter et enregistré dans `documentation/version.json` dans l’archive.

## Constructions locales

`tools/lot4/package_windows.ps1` réserve lui-même un numéro local si aucune
version CI ne lui a été fournie. Il est stocké dans `dist/build-version-counter.json`
(ignoré par Git). Le compteur local est indépendant de celui de distribution CI ;
les archives officielles à partager sont celles de la CI. Ne pas supprimer le
compteur local pour réutiliser un numéro. Un verrou exclusif protège la réservation.
Après arrêt brutal pendant la réservation, vérifier qu’aucun processus ne tourne
avant de retirer un éventuel `dist/version-reservation.lock` résiduel.

Contrôles : `python -m unittest discover -s tools/versioning -p 'test_*.py'`.
Les tests utilisent uniquement un dépôt Git temporaire local et ne contactent pas GitHub.


## Compatibilité Windows (correctif du 28 octobre 2026)

Les échanges de plomberie Git utilisent explicitement des octets UTF-8, sans
traduction LF → CRLF par Python. La création d’arbre utilise des entrées terminées
par NUL (`mktree -z`). Le premier compteur Windows a pu créer le nom Git
`counters.json` suivi d’un retour chariot : le script récupère ce blob uniquement,
conserve sa valeur et écrit le nom canonique à la prochaine réservation. Aucun
reset du compteur ni suppression de branche n’est nécessaire. Un compteur absent,
ambigu ou invalide bloque la réservation plutôt que de réattribuer un numéro.


Depuis le 29 octobre, le packaging Windows passe aussi
`--dart-define=INDEX_VERSION=<version publique réservée>` à Flutter : À propos
affiche le même numéro que l’archive, avec le mineur complété de zéros. Sans cette
valeur (lancement de développement), le panneau affiche « Développement ».
Cela ne réserve aucun numéro supplémentaire et n’ajoute aucune dépendance.


## Diagnostic Android — Lot 6A, 1er novembre 2026

Le workflow Android manuel réserve désormais dans le même compteur et sous le
même groupe de concurrence que Windows (`index-windows-version-counter`, nom
historique conservé). Une exécution Android consomme un mineur même en échec.
L’APK `IndeX_<version>_android_arm64_diagnostic.apk`, son artefact, À propos,
versionName et versionCode utilisent les valeurs réservées. La compilation
intermédiaire locale sans les variables INDEX_* ne produit pas une distribution
numérotée. Aucun compteur n’est remis à zéro et aucun majeur n’est changé.


Décision du 1er novembre 2026 : Windows devient exclusivement manuel, comme
Android. Le verrou commun reste nécessaire pour le compteur : si les deux sont
lancés manuellement en même temps, le second attend le premier. Une exécution
déjà démarrée avant ce changement continue ; modifier les déclencheurs ne
l’annule pas. Annuler un build ne restitue pas son numéro déjà réservé.


Lot 6B (2 novembre) : workflow Android renommé Verification Android Lot 6B,
numérotation/compteur inchangés. Cache Actions pour le keystore debug afin de
maintenir la signature des APK de diagnostic successifs ; aucune clé dans Git
ou les artefacts. Une ancienne clé non conservée ne peut pas être récupérée.
La signature définitive et son cycle de vie restent au Lot 6D.


## Lot 6D — 4 novembre 2026

Le workflow manuel Android propose diagnostic (défaut) ou release avec clé durable.
Les deux réservent le même compteur avant compilation, sans réinitialisation.
La release produit `IndeX_<version>_android_arm64_release.apk` et l’artefact
`IndeX-<version>-Android-arm64-release`, sans publication automatique.
La signature durable et le passage depuis les APK debug sont documentés dans
[le guide Android](../../docs/lot6/DISTRIBUTION_ANDROID.md).
