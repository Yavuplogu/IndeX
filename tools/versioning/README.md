# Numérotation IndeX à compter du 28 octobre 2026

Version initiale : **0.5.01**. Format `état.majeur.mineur` : état 0 (bêta) ou 1
(finale), majeur 5 tant que l’utilisateur n’a pas explicitement demandé de le
changer, mineur incrémenté et affiché sur au moins deux chiffres (01…99,100…).
`version.json` fixe l’état, le majeur et le premier mineur ; aucun changement
automatique d’état ou de majeur. La forme Flutter/SemVer enlève le zéro initial
(`0.5.1+1`) ; la version publique et les archives gardent `0.5.01`.

## Constructions GitHub Actions

Chaque exécution de construction Windows (push ou lancement manuel, y compris
relance) réserve le prochain mineur **avant** les contrôles et la compilation.
Un build en échec consomme donc son numéro : il n’est pas réattribué. Le premier
nouveau build réserve 01, le suivant 02. Le numéro n’est pas basé sur le nombre
de commits ou sur le nom de l’artefact précédent.

Le workflow sérialise les constructions et `reserve.py --ci` conserve les
compteurs dans la branche technique **`index-build-versions`**, créée à la première
réservation. Cette branche contient uniquement `counters.json` ; elle ne modifie
ni `main` ni le code. Les pushes du jeton Actions ne relancent pas les workflows ;
la branche est aussi exclue explicitement du déclenchement Windows. Ne pas effacer
cette branche ou réinitialiser son compteur, pour éviter de réutiliser des versions.

L’écriture requiert `contents: write` pour le jeton Actions. Une règle du dépôt
qui refuse la création/écriture de cette branche fera échouer explicitement la
réservation, sans produire une archive avec une version de repli. Les pull requests
exécutent les contrôles et la compilation de recette, mais ne réservent pas de
numéro et ne publient pas d’archive distribuable (jeton externe potentiellement
sans droit d’écriture). Cette numérotation vise les builds de distribution ;
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
